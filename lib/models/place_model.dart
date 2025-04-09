import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modello che rappresenta un segnaposto nell'app.
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

  /// Conteggio dei "like" del segnaposto.
  final int? likeCount;

  /// Indica se è richiesta un’autorizzazione per volare in questo luogo.
  final bool requiresPermission;

  /// Dettagli dell’autorizzazione (se richiesta).
  final String? permissionDetails;

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
    this.likeCount,
    this.requiresPermission = false,
    this.permissionDetails,
  });

  /// Crea un'istanza di [Place] a partire da una [Map] (es. un JSON).
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
      likeCount: data['likeCount'] != null ? (data['likeCount'] as num).toInt() : 0,
      requiresPermission: data['requiresPermission'] ?? false,
      permissionDetails: data['permissionDetails'] as String?,
    );
  }

  /// Crea un'istanza di [Place] a partire da un [DocumentSnapshot] di Firestore.
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
      likeCount: data['likeCount'] != null ? (data['likeCount'] as num).toInt() : 0,
      requiresPermission: data['requiresPermission'] ?? false,
      permissionDetails: data['permissionDetails'] as String?,
    );
  }

  /// Converte l'istanza di [Place] in una [Map] da salvare su Firestore.
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
      'likeCount': likeCount, // Includi il campo nel mapping
      'requiresPermission': requiresPermission,
      'permissionDetails': permissionDetails,
    };
  }

  /// Restituisce una copia di [Place] con alcuni campi modificati.
  Place copyWith({
    String? name,
    String? description,
    String? category,
    List<String>? mediaUrls,
    List<File>? mediaFiles,
    int? likeCount,
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
      likeCount: likeCount ?? this.likeCount,
      requiresPermission: requiresPermission,
      permissionDetails: permissionDetails,

    );
  }
}
