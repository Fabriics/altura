import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modello che rappresenta un segnaposto nell'app.
///
/// Utilizza:
/// - [mediaUrls]: lista di URL dei media (foto e video) caricati su Firebase Storage.
/// - [mediaFiles]: lista di file locali (foto/video) selezionati dall'utente.
///   Questo campo non è persistito su Firestore e serve solo durante la fase di caricamento.
class Place {
  /// Identificativo univoco del segnaposto.
  final String id;

  /// Titolo del segnaposto.
  final String name;

  /// Latitudine della posizione.
  final double latitude;

  /// Longitudine della posizione.
  final double longitude;

  /// ID dell'utente che ha creato il segnaposto.
  final String userId;

  /// Categoria del segnaposto (es. "panoramico", "landing", ecc.).
  final String category;

  /// Descrizione opzionale del segnaposto.
  final String? description;

  /// Data di creazione del segnaposto.
  final DateTime? createdAt;

  /// Lista di URL dei media (foto/video) caricati su Firebase Storage.
  final List<String>? mediaUrls;

  /// Lista di file locali (foto/video) selezionati dall'utente.
  /// Questo campo non viene salvato su Firestore.
  final List<File>? mediaFiles;

  Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.userId,
    required this.category,
    this.description,
    this.createdAt,
    this.mediaUrls,
    this.mediaFiles,
  });

  /// Crea un'istanza di [Place] a partire da una mappa, ad esempio dai dati di Firestore.
  /// Il campo [mediaFiles] non viene persistito e viene impostato a null.
  factory Place.fromMap(String docId, Map<String, dynamic> data) {
    return Place(
      id: docId,
      name: data['name'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      userId: data['userId'] ?? '',
      category: data['category'] ?? 'other',
      description: data['description'] as String?,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      mediaUrls: data['mediaUrls'] != null ? List<String>.from(data['mediaUrls']) : null,
      mediaFiles: null,
    );
  }

  /// Converte l'istanza in una mappa per il salvataggio su Firestore.
  /// Non include [mediaFiles] in quanto non persistito.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'userId': userId,
      'category': category,
      'description': description,
      'createdAt': createdAt,
      'mediaUrls': mediaUrls,
    };
  }

  /// Metodo per creare una copia modificata dell'istanza.
  Place copyWith({
    String? name,
    String? description,
    String? category,
    List<String>? mediaUrls,
    List<File>? mediaFiles,
  }) {
    return Place(
      id: id,
      name: name ?? this.name,
      latitude: latitude,
      longitude: longitude,
      userId: userId,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaFiles: mediaFiles ?? this.mediaFiles,
    );
  }

  int get totalPhotos {
    final int localCount = mediaFiles?.length ?? 0;
    final int remoteCount = mediaUrls?.length ?? 0;
    return localCount + remoteCount;
  }
}
