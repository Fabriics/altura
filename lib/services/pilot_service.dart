import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../models/user_model.dart';

class PilotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<List<AppUser>> _pilotStreamController =
  StreamController<List<AppUser>>.broadcast();

  Stream<List<AppUser>> get pilotStream => _pilotStreamController.stream;

  GeoFirePoint? _userLocation;
  double _userLat = 0;
  double _userLng = 0;

  // Parametri filtri
  double _radius = 30;
  bool _certifiedOnly = false;
  bool _availableOnly = true;
  List<String> _droneTypes = [];
  bool _sortByDistance = false;

  StreamSubscription<List<DocumentSnapshot>>? _geoSubscription;

  Future<void> fetchUserLocationAndPilots() async {
    try {
      final Position pos = await Geolocator.getCurrentPosition();
      _userLocation = GeoFirePoint(GeoPoint(pos.latitude, pos.longitude));
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _queryPilots();
    } catch (error) {
      _pilotStreamController.addError(
          "Errore nel recupero della posizione: $error");
    }
  }

  void applyFilters({
    required double radius,
    required bool certifiedOnly,
    required bool availableOnly,
    required List<String> droneTypes,
    bool sortByDistance = false,
  }) {
    _radius = radius;
    _certifiedOnly = certifiedOnly;
    _availableOnly = availableOnly;
    _droneTypes = droneTypes;
    _sortByDistance = sortByDistance;
    _queryPilots();
  }

  void _queryPilots() {
    if (_userLocation == null) return;

    // Annulla eventuale subscription precedente
    _geoSubscription?.cancel();

    CollectionReference usersRef = _firestore.collection('users');
    final geoRef = GeoCollectionReference(usersRef);

    _geoSubscription = geoRef.subscribeWithin(
      center: _userLocation!,
      radiusInKm: _radius,
      field: 'locationGeo',
      geopointFrom: (data) {
        final map = data as Map<String, dynamic>;
        if (map.containsKey('geopoint') && map['geopoint'] is GeoPoint) {
          return map['geopoint'] as GeoPoint;
        }
        return _userLocation!.geopoint;
      },
      strictMode: false,
    ).listen((snapshots) {
      List<AppUser> pilots = snapshots
          .map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) =>
      user.uid.isNotEmpty &&
          user.latitude != null &&
          user.longitude != null)
          .map((user) {
        final double dist = Geolocator.distanceBetween(
            _userLat, _userLng, user.latitude!, user.longitude!) /
            1000;
        return user.copyWith(distanceKm: dist);
      }).toList();

      if (_certifiedOnly) {
        pilots = pilots.where((user) => user.isCertified == true).toList();
      }
      if (_availableOnly) {
        pilots = pilots.where((user) => user.isAvailable == true).toList();
      }
      if (_droneTypes.isNotEmpty) {
        pilots = pilots
            .where((user) =>
            user.dronesList.any((drone) => _droneTypes.contains(drone)))
            .toList();
      }

      if (_sortByDistance) {
        pilots.sort((a, b) =>
            (a.distanceKm ?? double.infinity)
                .compareTo(b.distanceKm ?? double.infinity));
      } else {
        pilots.sort((a, b) {
          int expComp =
          (b.flightExperience ?? 0).compareTo(a.flightExperience ?? 0);
          if (expComp == 0) {
            return (a.distanceKm ?? double.infinity)
                .compareTo(b.distanceKm ?? double.infinity);
          }
          return expComp;
        });
      }

      if (pilots.length > 50) {
        pilots = pilots.take(50).toList();
      }
      _pilotStreamController.add(pilots);
    }, onError: (error) {
      _pilotStreamController.addError(error);
    });
  }

  Future<void> setCurrentUserAvailable(String uid) async {
    await _firestore.collection('users').doc(uid).update({'isAvailable': true});
  }

  void dispose() {
    _geoSubscription?.cancel();
    _pilotStreamController.close();
  }
}
