import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as lt;
import '../models/custom_category_marker.dart';
import '../models/place_model.dart';

/// Controller per gestire i segnaposti.
/// Interagisce con Firestore e Firebase Storage e gestisce la selezione dei media (foto/video)
/// tramite ImagePicker.
class PlacesController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collectionPath = 'places';
  final List<Place> _places = [];
  final Set<Marker> _markers = {};
  final ImagePicker _imagePicker = ImagePicker();

  PlacesController() {
    loadPlacesFromFirestore();
  }

  List<Place> get places => _places;
  Set<Marker> get markers => _markers;

  /// Carica i segnaposti da Firestore utilizzando snapshots per l'aggiornamento in tempo reale.
  Future<void> loadPlacesFromFirestore() async {
    _firestore.collection(_collectionPath).snapshots().listen((snapshot) {
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
    });
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
    final finalTitle =
    (title != null && title.isNotEmpty) ? title : 'Segnaposto #${_places.length + 1}';

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
      mediaFiles: mediaFiles,
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
      await _firestore.collection(_collectionPath).doc(placeId).set(dataToSave);
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
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
      final ref = _storage.ref().child('placeMedia/$placeId/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
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
      List<String> downloadUrls = oldPlace.mediaUrls ?? [];
      if (newMediaFiles != null && newMediaFiles.isNotEmpty) {
        for (final file in newMediaFiles) {
          final url = await _uploadMediaFile(placeId, file);
          if (url != null) downloadUrls.add(url);
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
      );
      _places[oldIndex] = updatedPlace;
      _createMarkersFromPlaces();
      notifyListeners();
      debugPrint('updatePlace: Place $placeId aggiornato con successo.');
    } catch (e) {
      debugPrint('Errore in updatePlace: $e');
    }
  }

  /// Cancella un segnaposto e tutti i relativi file da Firebase Storage.
  Future<void> deletePlace(String placeId) async {
    try {
      // Recupera il segnaposto per ottenere le URL dei file.
      final placeDoc = await _firestore.collection(_collectionPath).doc(placeId).get();
      if (placeDoc.exists && placeDoc.data() != null) {
        final data = placeDoc.data()!;
        final List<dynamic> urls = data['mediaUrls'] ?? [];
        for (final url in urls) {
          try {
            final ref = _storage.refFromURL(url.toString());
            await ref.delete();
          } catch (e) {
            debugPrint('Errore nella cancellazione del file da Storage: $e');
          }
        }
      }
      await _firestore.collection(_collectionPath).doc(placeId).delete();
      _places.removeWhere((p) => p.id == placeId);
      _createMarkersFromPlaces();
      notifyListeners();
    } catch (e) {
      debugPrint('Errore eliminazione place $placeId: $e');
    }
  }

  /// Rimuove un media esistente (URL) dal segnaposto su Firebase.
  Future<void> removeMediaFromPlace(String placeId, {required bool isUrl, required int index}) async {
    try {
      final docSnapshot = await _firestore.collection(_collectionPath).doc(placeId).get();
      if (!docSnapshot.exists) return;
      final data = docSnapshot.data();
      List<dynamic> mediaList = data?['mediaUrls'] ?? [];
      if (index < 0 || index >= mediaList.length) return;
      if (isUrl) {
        final String url = mediaList[index].toString();
        try {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (e) {
          debugPrint("Errore nella cancellazione del file da Storage: $e");
        }
        mediaList.removeAt(index);
      }
      // Aggiorna il documento Firestore con la lista modificata.
      await _firestore.collection(_collectionPath).doc(placeId).update({
        'mediaUrls': mediaList,
      });
    } catch (e) {
      debugPrint('Errore in removeMediaFromPlace: $e');
    }
  }

  /// Seleziona più media (foto e video) dal device.
  Future<List<File>?> pickMedia() async {
    try {
      final List<XFile> xfiles = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return xfiles.isNotEmpty ? xfiles.map((xfile) => File(xfile.path)).toList() : [];
    } catch (e) {
      debugPrint('Errore pickMedia: $e');
      return null;
    }
  }

  /// Ricostruisce i marker a partire dai segnaposti.
  void _createMarkersFromPlaces() {
    final Set<Marker> newMarkers = {};
    for (final place in _places) {
      newMarkers.add(
        Marker(
          point: lt.LatLng(place.latitude, place.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              // Azione al tocco sul marker (se desiderata)
            },
            child: CustomCategoryMarker(category: place.category),
          ),
        ),
      );
    }
    _markers
      ..clear()
      ..addAll(newMarkers);
    notifyListeners();
  }
}
