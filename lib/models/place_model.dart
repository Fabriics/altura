import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modello che rappresenta un segnaposto nell'app.
///
/// - [id]: identificativo univoco del segnaposto (di solito il doc.id di Firestore).
/// - [name]: titolo del segnaposto.
/// - [latitude], [longitude]: coordinate geografiche della posizione.
/// - [userId]: UID dell'utente che ha creato il segnaposto.
/// - [category]: categoria o tipologia del segnaposto (es. "panoramico", "landing", ecc.).
/// - [description]: testo descrittivo opzionale.
/// - [createdAt]: data di creazione del segnaposto (null se non impostata).
/// - [mediaUrls]: lista di URL di foto/video caricati su Firebase Storage.
/// - [mediaFiles]: lista di file locali (non salvata su Firestore).
class Place {
  /// Identificativo univoco del segnaposto.
  final String id;

  /// Titolo o nome del segnaposto.
  final String name;

  /// Latitudine della posizione.
  final double latitude;

  /// Longitudine della posizione.
  final double longitude;

  /// UID dell'utente che ha creato il segnaposto.
  final String userId;

  /// Categoria del segnaposto (es. "pista_decollo", "altro", ecc.).
  final String category;

  /// Descrizione opzionale del segnaposto.
  final String? description;

  /// Data di creazione del segnaposto.
  final DateTime? createdAt;

  /// Lista di URL (foto/video) salvati su Firestore (Firebase Storage).
  final List<String>? mediaUrls;

  /// Lista di file locali (foto/video) non salvati su Firestore.
  final List<File>? mediaFiles;

  /// Costruttore principale di [Place].
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

  // ---------------------------------------------------------------------------
  // FACTORY: fromMap
  // ---------------------------------------------------------------------------
  /// Crea un'istanza di [Place] a partire da una [Map] generica (es. un JSON).
  /// Utilizzato, ad esempio, quando si hanno già i dati in forma di mappa
  /// e si vuole costruire l'oggetto manualmente. Il campo [docId] indica l'ID
  /// del documento (spesso doc.id di Firestore).
  ///
  /// Il campo [mediaFiles] viene impostato a null, perché di solito non è
  /// persistito in Firestore.
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
      mediaUrls: data['mediaUrls'] != null
          ? List<String>.from(data['mediaUrls'])
          : null,
      mediaFiles: null,
    );
  }

  // ---------------------------------------------------------------------------
  // FACTORY: fromFirestore
  // ---------------------------------------------------------------------------
  /// Crea un'istanza di [Place] a partire da un [DocumentSnapshot] di Firestore.
  /// Legge i campi dal [doc.data()] (che è una [Map]) e imposta [id] con doc.id.
  ///
  /// Se il campo [mediaUrls] non è presente, viene impostato a null.
  /// Il campo [mediaFiles] non viene recuperato da Firestore (resta null).
  factory Place.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Place(
      id: doc.id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      userId: data['userId'] ?? '',
      category: data['category'] ?? 'other',
      description: data['description'] as String?,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      mediaUrls: data['mediaUrls'] != null
          ? List<String>.from(data['mediaUrls'])
          : null,
      mediaFiles: null,
    );
  }

  // ---------------------------------------------------------------------------
  // toMap
  // ---------------------------------------------------------------------------
  /// Converte l'istanza di [Place] in una [Map] da salvare su Firestore.
  /// Non include [mediaFiles], che è un campo locale.
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

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------
  /// Restituisce una copia di [Place] con alcuni campi modificati.
  /// Se un campo non è specificato, mantiene il valore corrente.
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

  // ---------------------------------------------------------------------------
  // totalPhotos
  // ---------------------------------------------------------------------------
  /// Restituisce il numero totale di foto (locali + remote).
  /// Utile se vuoi mostrare un contatore di media disponibili.
  int get totalPhotos {
    final localCount = 0;
    final remoteCount = mediaUrls?.length ?? 0;
    return localCount + remoteCount;
  }
}
