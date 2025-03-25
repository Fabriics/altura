import 'package:cloud_firestore/cloud_firestore.dart';
// geoflutterfire_plus ti serve per calcolare geohash + geopoint in scrittura
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
  final List<String> drones;
  final int? flightExperience;
  final String? instagram;
  final String? youtube;
  final String? website;
  final String? fcmToken;

  /// Invece di salvare `latitude` e `longitude` come double separati,
  /// gestiremo la posizione come un "GeoFirePoint" su Firestore.
  /// Tuttavia, per comodità, possiamo ancora memorizzare lat/long in locale,
  /// se vogliamo, oppure ometterli del tutto.
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
  /// Ora gestiamo "location" come un oggetto con "geopoint" e "geohash".
  Map<String, dynamic> toMap() {
    // Se non abbiamo lat/long, potremmo non salvare affatto "location".
    // Altrimenti, costruiamo un GeoFirePoint e includiamo geohash e geopoint.
    Map<String, dynamic>? locationMap;
    if (latitude != null && longitude != null) {
      // Creiamo un GeoFirePoint con geoflutterfire_plus
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
      'location': location, // (campo testuale se vuoi, es. "Roma, Italia")
      'favoritePlaces': favoritePlaces,
      'uploadedPlaces': uploadedPlaces,
      'purchasedItems': droneActivities,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'drones': drones,
      'flightExperience': flightExperience,
      'instagram': instagram,
      'youtube': youtube,
      'website': website,
      'fcmToken': fcmToken,

      // "locationGeo" potrebbe essere un campo dedicato al salvataggio geofire
      // Se preferisci chiamarlo "location", rinominalo pure, ma occhio ai conflitti
      'locationGeo': locationMap,
    };
  }

  /// Crea un AppUser a partire da una mappa (ad es. i dati Firestore).
  /// Leggiamo "locationGeo" e, se presente, estraiamo lat/long da "geopoint".
  factory AppUser.fromMap(Map<String, dynamic> map) {
    double? lat;
    double? lng;

    // Se esiste "locationGeo" con "geopoint"
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
      droneActivities: List<String>.from(map['purchasedItems'] ?? []),
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
