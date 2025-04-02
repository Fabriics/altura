
import 'dart:async';


import 'package:altura/services/place_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_open_app_settings/flutter_open_app_settings.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../models/place_model.dart';
import 'auth_service.dart';
import '../views/home/edit/edit_place_page.dart';
import '../views/home/search_page.dart';

class MapService extends ChangeNotifier {
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  LocationData? currentLocation;
  bool hasLocationPermission = false;
  bool isLoading = true;
  final LatLng defaultPosition = const LatLng(48.488, 13.678);
  GoogleMapController? mapController;

  final PlacesController placesController;

  MapService({required this.placesController});

  Future<void> initLocation({BuildContext? context}) async {
    try {
      if (!await _location.serviceEnabled() && !await _location.requestService()) {
        return handleLocationPermissionDenied(context: context);
      }
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.deniedForever ||
          (permission == PermissionStatus.denied &&
              await _location.requestPermission() != PermissionStatus.granted)) {
        return handleLocationPermissionDenied(context: context);
      }
      _locationSubscription?.cancel();
      _locationSubscription = _location.onLocationChanged.listen((locData) {
        currentLocation = locData;
        notifyListeners();
      });
      currentLocation = await _location.getLocation();
      hasLocationPermission = true;
    } catch (e) {
      debugPrint('Errore localizzazione: $e');
    } finally {
      isLoading = false;
      notifyListeners();
      moveCameraToCurrentLocation();
    }
  }

  void handleLocationPermissionDenied({BuildContext? context}) {
    hasLocationPermission = false;
    isLoading = false;
    notifyListeners();
    setDefaultLocation();
    if (context != null) showLocationSettingsDialog(context);
  }

  void setDefaultLocation() {
    mapController?.animateCamera(CameraUpdate.newLatLng(defaultPosition));
  }

  void moveCameraToCurrentLocation() {
    if (hasLocationPermission && currentLocation != null) {
      mapController?.animateCamera(CameraUpdate.newLatLng(
        LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
      ));
    }
  }

  void showLocationSettingsDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Localizzazione Necessaria"),
        content: const Text(
          "Per continuare a usare tutte le funzionalità, abilita la localizzazione dalle impostazioni.",
          textAlign: TextAlign.center,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              FlutterOpenAppSettings.openAppsSettings(settingsCode: SettingsCode.LOCATION);
            },
            child: const Text("Impostazioni"),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annulla"),
          ),
        ],
      ),
    );
  }

  Future<Place?> addMarkerAtPosition({
    required LatLng latLng,
    required BuildContext context,
    required Future<Map<String, dynamic>?> Function() showAddPlaceWizard,
    required Future<void> Function() initUser,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !hasLocationPermission || currentLocation == null) {
      showLocationSettingsDialog(context);
      return null;
    }

    final info = await showAddPlaceWizard();
    if (info == null) return null;

    final newPlace = await placesController.addPlace(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      userId: user.uid,
      category: info['category'] ?? 'altro',
      title: info['title'],
      description: info['description'],
      mediaFiles: info['media'],
    );

    await _updateUserPlaces(user.uid, newPlace.id);
    await initUser();
    mapController?.animateCamera(CameraUpdate.newLatLng(
      LatLng(newPlace.latitude, newPlace.longitude),
    ));

    return newPlace;
  }

  Future<void> _updateUserPlaces(String uid, String placeId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'uploadedPlaces': FieldValue.arrayUnion([placeId]),
      });
    } catch (e) {
      debugPrint('Errore aggiornamento utente: $e');
    }
  }

  Future<void> editPlace({required Place place, required BuildContext context}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPlacePage(place: place)),
    );
    if (result is Map<String, dynamic>) {
      await placesController.updatePlace(
        placeId: place.id,
        userId: place.userId,
        newTitle: result['title'] ?? '',
        newDescription: result['description'] ?? '',
        newCategory: result['category'] ?? '',
        newMediaFiles: result['media'] ?? [],
      );
    }
  }

  Future<void> deletePlace({required Place place, required BuildContext context}) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Eliminare il segnaposto "${place.name}"?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            isDestructiveAction: true,
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true) await placesController.deletePlace(place.id);
  }

  Future<void> openSearchPage({
    required BuildContext context,
    required void Function(LatLng latLng) onSearchResult,
  }) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
    if (result == null) return;
    final latLng = LatLng(result['lat'], result['lng']);
    mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
    placesController.markers.clear();
    placesController.markers.add(
      Marker(
        markerId: const MarkerId('searchedLocation'),
        position: latLng,
        infoWindow: const InfoWindow(title: 'Risultato ricerca'),
        flat: true,
      ),
    );
    onSearchResult(latLng);
  }

  Future<void> signOut({required BuildContext context}) async {
    await Auth().signOut();
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
