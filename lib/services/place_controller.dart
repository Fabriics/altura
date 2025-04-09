import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/place_model.dart';

/// Controller per gestire i segnaposti.
/// Questo controller interagisce con Firestore e Firebase Storage e gestisce la
/// selezione dei media (foto e video) tramite ImagePicker.
class PlacesController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collectionPath = 'places';
  final List<Place> _places = [];
  final Set<Marker> _markers = {};

  // Per caricare media dal device
  final ImagePicker _imagePicker = ImagePicker();
  
  PlacesController() {
    //_loadCustomIcons();
    loadPlacesFromFirestore();
  }

  List<Place> get places => _places;
  Set<Marker> get markers => _markers;
  
  /// Carica i segnaposti da Firestore.
  Future<void> loadPlacesFromFirestore() async {
    try {
      final snapshot = await _firestore.collection(_collectionPath).get();
      final List<Place> loadedPlaces = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final place = Place.fromMap(doc.id, data);
        loadedPlaces.add(place);
      }
      _places
        ..clear()
        ..addAll(loadedPlaces);
      _createMarkersFromPlaces();
    } catch (e) {
      debugPrint('Errore nel loadPlaces: $e');
    }
  }

  /// Aggiunge un nuovo segnaposto con supporto a più media (foto/video).
  Future<Place> addPlace({
    required double latitude,
    required double longitude,
    required String userId,
    required String category,
    String? title,
    String? description,
    List<File>? mediaFiles,
  }) async {
    final placeId = DateTime.now().millisecondsSinceEpoch.toString();
    final finalTitle = (title != null && title.isNotEmpty)
        ? title
        : 'Segnaposto #${_places.length + 1}';

    // Carica ogni file e raccoglie gli URL di download.
    List<String> downloadUrls = [];
    if (mediaFiles != null && mediaFiles.isNotEmpty) {
      for (final file in mediaFiles) {
        final url = await _uploadMediaFile(placeId, file);
        if (url != null) {
          downloadUrls.add(url);
        }
      }
    }

    final newPlace = Place(
      id: placeId,
      name: finalTitle,
      latitude: latitude,
      longitude: longitude,
      userId: userId,
      category: category,
      description: description,
      mediaUrls: downloadUrls.isNotEmpty ? downloadUrls : null,
      // createdAt viene impostato in Firestore
      mediaFiles: mediaFiles, // Puoi mantenerli in memoria se necessario
    );

    final dataToSave = {
      'name': newPlace.name,
      'latitude': newPlace.latitude,
      'longitude': newPlace.longitude,
      'userId': userId,
      'category': category,
      'description': description,
      'mediaUrls': downloadUrls,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // Salva su Firestore.
      await _firestore.collection(_collectionPath).doc(placeId).set(dataToSave);

      // Aggiorna la lista dei segnaposti dell'utente (opzionale).
      await _firestore.collection('users').doc(userId).update({
        'uploadedPlaces': FieldValue.arrayUnion([placeId]),
      }).catchError((err) {
        debugPrint('Non riesco ad aggiornare l\'utente: $err');
      });

      _places.add(newPlace);
      _createMarkersFromPlaces();
      return newPlace;
    } catch (e) {
      debugPrint('Errore in addPlace: $e');
      return newPlace;
    }
  }

  /// Carica un file (foto o video) su Firebase Storage e restituisce l'URL.
  Future<String?> _uploadMediaFile(String placeId, File file) async {
    try {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
      final ref = _storage.ref().child('placeMedia/$placeId/$fileName');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Errore upload file: $e');
      return null;
    }
  }

  /// Aggiorna un segnaposto esistente, supportando l'aggiunta di nuovi media.
  Future<void> updatePlace({
    required String placeId,
    required String userId,
    required String newTitle,
    required String newDescription,
    required String newCategory,
    List<File>? newMediaFiles,
  }) async {
    try {
      final oldIndex = _places.indexWhere((p) => p.id == placeId);
      if (oldIndex < 0) {
        debugPrint('updatePlace: Place non trovato in locale');
        return;
      }
      final oldPlace = _places[oldIndex];
      // Unisce gli URL esistenti a quelli nuovi.
      List<String> downloadUrls = oldPlace.mediaUrls ?? [];
      if (newMediaFiles != null && newMediaFiles.isNotEmpty) {
        for (final file in newMediaFiles) {
          final url = await _uploadMediaFile(placeId, file);
          if (url != null) {
            downloadUrls.add(url);
          }
        }
      }
      final dataToUpdate = {
        'name': newTitle,
        'description': newDescription,
        'category': newCategory,
        'mediaUrls': downloadUrls,
      };
      await _firestore.collection(_collectionPath).doc(placeId).update(dataToUpdate);
      final updatedPlace = oldPlace.copyWith(
        name: newTitle,
        description: newDescription,
        category: newCategory,
        mediaUrls: downloadUrls,
        // Puoi decidere se aggiornare anche mediaFiles.
      );
      _places[oldIndex] = updatedPlace;
      _createMarkersFromPlaces();
      notifyListeners();
      debugPrint('updatePlace: Place $placeId aggiornato con successo.');
    } catch (e) {
      debugPrint('Errore in updatePlace: $e');
    }
  }

  Future<void> deletePlace(String placeId) async {
    try {
      await _firestore.collection(_collectionPath).doc(placeId).delete();
      _places.removeWhere((p) => p.id == placeId);
      _createMarkersFromPlaces();
      notifyListeners();
    } catch (e) {
      debugPrint('Errore eliminazione place $placeId: $e');
    }
  }

  /// Seleziona più media (foto e video) dal device.
  Future<List<File>?> pickMedia() async {
    try {
      final List<XFile> xfiles = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (xfiles.isNotEmpty) {
        return xfiles.map((xfile) => File(xfile.path)).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Errore pickMedia: $e');
      return null;
    }
  }

  /// Ricostruisce i marker a partire dai segnaposti.
  void _createMarkersFromPlaces() {
    final Set<Marker> newMarkers = {};
    for (final place in _places) {
      final marker = Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.latitude, place.longitude),
        icon: BitmapDescriptor.defaultMarker,
        anchor: Offset(0.5, 1.05),
        infoWindow: InfoWindow(
          title: place.name,
          snippet: place.description ?? 'Nessuna descrizione',
        ),
      );
      newMarkers.add(marker);
    }
    _markers
      ..clear()
      ..addAll(newMarkers);
    notifyListeners();
  }
}