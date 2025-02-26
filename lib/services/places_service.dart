// lib/controllers/places_controller.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/place.dart';

class PlacesController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final String _collectionPath = 'places';

  final List<Place> _places = [];
  final Set<Marker> _markers = {};

  // Per caricare immagini dal device
  final ImagePicker _imagePicker = ImagePicker();

  // Icone personalizzate (se vuoi)
  late BitmapDescriptor _iconPanoramico;
  late BitmapDescriptor _iconLanding;
  late BitmapDescriptor _iconRestrizione;
  late BitmapDescriptor _iconOther;

  bool _iconsLoaded = false;

  PlacesController() {
    _loadCustomIcons();
    loadPlacesFromFirestore();
  }

  List<Place> get places => _places;
  Set<Marker> get markers => _markers;

  /// Carica i marker personalizzati dagli asset
  Future<void> _loadCustomIcons() async {
    try {
      _iconPanoramico = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/markers/panoramico.png',
      );
      _iconLanding = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/markers/landing.png',
      );
      _iconRestrizione = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/markers/restriction.png',
      );
      _iconOther = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/markers/other.png',
      );
    } catch (e) {
      debugPrint('Errore nel caricare icone: $e');
      // In fallback puoi usare defaultMarker
    } finally {
      _iconsLoaded = true;
      notifyListeners();
    }
  }

  /// Carica i place da Firestore
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

  /// Aggiunge un nuovo segnaposto
  Future<Place> addPlace({
    required double latitude,
    required double longitude,
    required String userId,
    required String category,
    String? title,
    String? description,
    File? imageFile,
  }) async {
    final placeId = DateTime.now().millisecondsSinceEpoch.toString();
    final finalTitle = (title != null && title.isNotEmpty)
        ? title
        : 'Segnaposto #${_places.length + 1}';

    final newPlace = Place(
      id: placeId,
      name: finalTitle,
      latitude: latitude,
      longitude: longitude,
      userId: userId,
      category: category,
      imageFile: imageFile,
      description: description,
      // createdAt => vediamo come impostarlo
    );

    String? downloadUrl;
    if (imageFile != null) {
      downloadUrl = await _uploadImageFile(placeId, imageFile);
    }

    final dataToSave = {
      'name': newPlace.name,
      'latitude': newPlace.latitude,
      'longitude': newPlace.longitude,
      'userId': userId,
      'category': category,
      'imageUrl': downloadUrl,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // Salviamo su Firestore
      await _firestore
          .collection(_collectionPath)
          .doc(placeId)
          .set(dataToSave);

      // Se vuoi aggiornare l'utente in users/{userId} => uploadedPlaces
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'uploadedPlaces': FieldValue.arrayUnion([placeId]),
      })
          .catchError((err) {
        debugPrint('Non riesco ad aggiornare l utente: $err');
      });

      final savedPlace = Place(
        id: placeId,
        name: finalTitle,
        latitude: latitude,
        longitude: longitude,
        userId: userId,
        category: category,
        imageUrl: downloadUrl,
        description: description,
      );
      _places.add(savedPlace);
      _createMarkersFromPlaces();
      return savedPlace;
    } catch (e) {
      debugPrint('Errore in addPlace: $e');
      return newPlace;
    }
  }

  /// Funzione per caricare immagine su Firebase Storage
  Future<String?> _uploadImageFile(String placeId, File imageFile) async {
    try {
      final ref = _storage.ref().child('placeImages/$placeId.jpg');
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Errore upload file: $e');
      return null;
    }
  }

  /// Ricostruisce i marker con eventuali icone custom
  void _createMarkersFromPlaces() {
    final Set<Marker> newMarkers = {};
    for (final place in _places) {
      /* BitmapDescriptor iconToUse = BitmapDescriptor.defaultMarker;
      if (_iconsLoaded) {
        switch (place.category) {
          case 'panoramico':
            iconToUse = _iconPanoramico;
            break;
          case 'landing':
            iconToUse = _iconLanding;
            break;
          case 'restrizione':
            iconToUse = _iconRestrizione;
            break;
          default:
            BitmapDescriptor.defaultMarker;
        }
      }*/

      final marker = Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.latitude, place.longitude),
        icon: BitmapDescriptor.defaultMarker,
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

  /// Aggiorna i campi di un segnaposto esistente, compresa l'eventuale nuova foto.
  Future<void> updatePlace({
    required String placeId,
    required String userId,
    required String newTitle,
    required String newDescription,
    required String newCategory,
    File? newImageFile,
  }) async {
    try {
      // 1. Recuperiamo il place in locale (opzionale, se vuoi)
      final oldIndex = _places.indexWhere((p) => p.id == placeId);
      if (oldIndex < 0) {
        debugPrint('updatePlace: Place non trovato in locale');
        return;
      }

      final oldPlace = _places[oldIndex];
      String? downloadUrl = oldPlace.imageUrl;

      // 2. Se l’utente ha selezionato una NUOVA foto, carichiamola su Storage
      if (newImageFile != null) {
        final uploadedUrl = await _uploadImageFile(placeId, newImageFile);
        if (uploadedUrl != null) {
          downloadUrl = uploadedUrl;
        }
      }

      // 3. Creiamo la mappa di aggiornamento per Firestore
      final dataToUpdate = {
        'name': newTitle,
        'description': newDescription,
        'category': newCategory,
        'imageUrl': downloadUrl,
        // Non modifichiamo userId, lat, lng, ecc. se non necessario
      };

      // 4. Aggiorna su Firestore
      await _firestore
          .collection(_collectionPath)
          .doc(placeId)
          .update(dataToUpdate);

      // 5. Aggiorna localmente
      final updatedPlace = oldPlace.copyWith(
        name: newTitle,
        description: newDescription,
        category: newCategory,
        imageFile: newImageFile,   // O decidi tu se vuoi tenere solo imageUrl
        imageUrl: downloadUrl,
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
      // 1. Rimuovi dalla collezione places
      await FirebaseFirestore.instance
          .collection(_collectionPath)
          .doc(placeId)
          .delete();

      // 2. Rimuovi localmente dalla lista _places
      _places.removeWhere((p) => p.id == placeId);

      // 3. Ricostruisci i marker
      _createMarkersFromPlaces();
      notifyListeners();
    } catch (e) {
      debugPrint('Errore eliminazione place $placeId: $e');
    }
  }


  /// Per selezionare immagine
  Future<File?> pickImage() async {
    try {
      final xfile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return xfile == null ? null : File(xfile.path);
    } catch (e) {
      debugPrint('Errore pickImage: $e');
      return null;
    }
  }
}
