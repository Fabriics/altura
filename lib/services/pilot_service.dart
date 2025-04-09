import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../models/user_model.dart';

class PilotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _pilotStreamController = StreamController<List<AppUser>>.broadcast();

  // La posizione utente verrà impostata dopo averla recuperata
  GeoFirePoint? _userLocation;
  double _userLat = 0;
  double _userLng = 0;
  double _radius = 30;
  bool _certifiedOnly = false;
  bool _availableOnly = true;
  List<String> _droneTypes = [];
  bool _sortByDistance = false;

  Stream<List<AppUser>> get pilotStream => _pilotStreamController.stream;

  Future<void> fetchUserLocationAndPilots() async {
    final pos = await Geolocator.getCurrentPosition();
    // Creazione del GeoFirePoint in base alla posizione corrente
    _userLocation = GeoFirePoint(GeoPoint(pos.latitude, pos.longitude));
    _userLat = pos.latitude;
    _userLng = pos.longitude;
    _queryPilots();
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
    // Inizializza la reference alla collection "users" senza applicare filtri
    CollectionReference usersCollection = _firestore.collection('users');

    // Creazione della GeoCollectionReference utilizzando il CollectionReference
    GeoCollectionReference geoRef = GeoCollectionReference(usersCollection);
    geoRef.subscribeWithin(
      center: _userLocation!,
      radiusInKm: _radius,
      field: 'locationGeo',
      geopointFrom: (data) =>
      (data['locationGeo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
      strictMode: true,
      // Il parametro "limit" è stato rimosso perché non esiste in subscribeWithin
    ).listen((snapshots) {
      var filtered = snapshots
          .map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) =>
      user.uid.isNotEmpty &&
          user.latitude != null &&
          user.longitude != null)
          .map((user) {
        final double dist = Geolocator.distanceBetween(
          _userLat,
          _userLng,
          user.latitude!,
          user.longitude!,
        ) / 1000; // conversione da metri a km
        return user.copyWith(distanceKm: dist);
      }).toList();

      // Ordinamento: se l'esperienza di volo è uguale, ordina per distanza;
      // altrimenti ordina per flightExperience in ordine decrescente
      if (_sortByDistance) {
        filtered.sort((a, b) {
          if ((a.flightExperience ?? 0) == (b.flightExperience ?? 0)) {
            return (a.distanceKm ?? 9999).compareTo(b.distanceKm ?? 9999);
          }
          return (b.flightExperience ?? 0).compareTo(a.flightExperience ?? 0);
        });
      }

      // Limita il numero di elementi a 50, se necessario
      if (filtered.length > 50) {
        filtered = filtered.take(50).toList();
      }

      _pilotStreamController.add(filtered);
    });
  }

  Future<void> setCurrentUserAvailable(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isAvailable': true,
    });
  }

  void dispose() => _pilotStreamController.close();
}
