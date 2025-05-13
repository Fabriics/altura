import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

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
  final bool? isCertified;
  final bool? isAvailable;
  final List<String> dronesList;
  final int? flightExperience;
  final String? pilotLevel;           // Nuovo campo
  final String? instagram;
  final String? youtube;
  final String? website;
  final String? fcmToken;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? certificationUrl;
  final String? certificationStatus;  // pending, approved, rejected
  final String? certificationType;    // Nuovo campo

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
    this.isCertified = false,
    this.isAvailable = false,
    this.dronesList = const [],
    this.flightExperience,
    this.pilotLevel,
    this.instagram,
    this.youtube,
    this.website,
    this.fcmToken,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.certificationUrl,
    this.certificationStatus,
    this.certificationType,
  });

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
      'droneActivities': droneActivities,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'isCertified': isCertified,
      'isAvailable': isAvailable,
      'dronesList': dronesList,
      'flightExperience': flightExperience,
      'pilotLevel': pilotLevel,              // Incluso nella mappa
      'instagram': instagram,
      'youtube': youtube,
      'website': website,
      'fcmToken': fcmToken,
      'locationGeo': locationMap,
      'certificationStatus': certificationStatus,
      'certificationUrl': certificationUrl,
      'certificationType': certificationType, // Incluso nella mappa
    };
  }

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
      isCertified: map['isCertified'] ?? false,
      isAvailable: map['isAvailable'] ?? false,
      dronesList: List<String>.from(map['dronesList'] ?? []),
      flightExperience: map['flightExperience'],
      pilotLevel: map['pilotLevel'],
      instagram: map['instagram'],
      youtube: map['youtube'],
      website: map['website'],
      fcmToken: map['fcmToken'],
      latitude: lat,
      longitude: lng,
      certificationUrl: map['certificationUrl'],
      certificationStatus: map['certificationStatus'],
      certificationType: map['certificationType'],
    );
  }

  AppUser copyWith({
    double? distanceKm,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      username: username,
      profileImageUrl: profileImageUrl,
      bio: bio,
      location: location,
      favoritePlaces: favoritePlaces,
      uploadedPlaces: uploadedPlaces,
      droneActivities: droneActivities,
      createdAt: createdAt,
      lastLogin: lastLogin,
      isEmailVerified: isEmailVerified,
      isCertified: isCertified ?? isCertified,
      isAvailable: isAvailable ?? isAvailable,
      dronesList: dronesList,
      flightExperience: flightExperience,
      instagram: instagram,
      youtube: youtube,
      website: website,
      fcmToken: fcmToken,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}
