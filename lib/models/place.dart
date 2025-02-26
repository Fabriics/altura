// lib/models/place.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  final String id;
  final String name;       // Titolo (in precedenza "Segnaposto #x")
  final double latitude;
  final double longitude;
  final String userId;
  final String category;   // Es. "panoramico", "landing", "restrizione", etc.
  final File? imageFile;
  final String? imageUrl;
  final String? description;
  final DateTime? createdAt;

  Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.userId,
    required this.category,
    this.imageFile,
    this.imageUrl,
    this.description,
    this.createdAt,
  });

  factory Place.fromMap(String docId, Map<String, dynamic> data) {
    return Place(
      id: docId,
      name: data['name'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      userId: data['userId'] ?? '',
      category: data['category'] ?? 'other',
      imageUrl: data['imageUrl'],
      description: data['description'] as String?,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'userId': userId,
      'category': category,
      'imageUrl': imageUrl,
      'description': description,
      'createdAt': createdAt,
    };
  }

  /// Permette la modifica del post
  Place copyWith({
    String? name,
    String? description,
    String? category,
    File? imageFile,
    String? imageUrl,
  }) {
    return Place(
      id: id,
      name: name ?? this.name,
      latitude: latitude,
      longitude: longitude,
      userId: userId,
      category: category ?? this.category,
      imageFile: imageFile ?? this.imageFile,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }

}
