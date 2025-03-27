// user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

/// Modello utente (AppUser) per la tua app Altura.
class AppUser {
  final String uid;
  final String? email;
  final String username;
  final String? profileImageUrl;
  final String? bio;
  final String? location;
  final List<String> favoritePlaces;
  final List<String> uploadedPlaces;
  final List<String> droneActivities;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isEmailVerified;
  final List<String> drones;
  final int? flightExperience;
  final String? instagram;
  final String? youtube;
  final String? website;
  final String? fcmToken;

  final double? latitude;
  final double? longitude;

  AppUser({
    required this.uid,
    this.email,
    required this.username,
    this.profileImageUrl,
    this.bio,
    this.location,
    this.favoritePlaces = const [],
    this.uploadedPlaces = const [],
    this.droneActivities = const [],
    required this.createdAt,
    required this.lastLogin,
    this.isEmailVerified = false,
    this.drones = const [],
    this.flightExperience,
    this.instagram,
    this.youtube,
    this.website,
    this.fcmToken,
    this.latitude,
    this.longitude,
  });

  /// Converte l’istanza in una mappa (per salvare su Firestore).
  Map<String, dynamic> toMap() {
    Map<String, dynamic>? locationMap;
    if (latitude != null && longitude != null) {
      final geoPoint = GeoFirePoint(GeoPoint(latitude!, longitude!));
      locationMap = {
        'geopoint': geoPoint.geopoint,
        'geohash': geoPoint.geohash,
      };
    }

    return {
      'uid': uid,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'location': location,
      'favoritePlaces': favoritePlaces,
      'uploadedPlaces': uploadedPlaces,
      // Drone activities
      'droneActivities': droneActivities,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'drones': drones,
      'flightExperience': flightExperience,
      'instagram': instagram,
      'youtube': youtube,
      'website': website,
      'fcmToken': fcmToken,
      'locationGeo': locationMap,
    };
  }

  /// Crea un AppUser a partire da una mappa (ad es. i dati Firestore).
  factory AppUser.fromMap(Map<String, dynamic> map) {
    double? lat;
    double? lng;

    if (map['locationGeo'] != null) {
      final locMap = map['locationGeo'] as Map<String, dynamic>;
      final geoPoint = locMap['geopoint'] as GeoPoint?;
      if (geoPoint != null) {
        lat = geoPoint.latitude;
        lng = geoPoint.longitude;
      }
    }

    return AppUser(
      uid: map['uid'],
      email: map['email'],
      username: map['username'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      bio: map['bio'],
      location: map['location'],
      favoritePlaces: List<String>.from(map['favoritePlaces'] ?? []),
      uploadedPlaces: List<String>.from(map['uploadedPlaces'] ?? []),
      droneActivities: List<String>.from(map['droneActivities'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
      lastLogin: DateTime.parse(map['lastLogin']),
      isEmailVerified: map['isEmailVerified'] ?? false,
      drones: List<String>.from(map['drones'] ?? []),
      flightExperience: map['flightExperience'],
      instagram: map['instagram'],
      youtube: map['youtube'],
      website: map['website'],
      fcmToken: map['fcmToken'],
      latitude: lat,
      longitude: lng,
    );
  }
}
