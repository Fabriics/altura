class AppUser {
  final String uid;
  final String? email;
  final String username;
  final String? profilePictureUrl; // <--- esiste già
  final String? bio;
  final String? location;
  final List<String> savedPlaces;
  final List<String> uploadedPlaces;
  final List<String> purchasedItems;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isEmailVerified;
  final List<String> drones;

  // AGGIUNGI questi nuovi campi
  final String? profileImageUrl;     // <-- per la foto caricata
  final int? flightExperience;       // <-- anni di volo
  final String? instagram;           // <-- se l'utente inserisce instagram
  final String? youtube;             // <-- canale youtube
  final String? website;             // <-- sito web

  AppUser({
    required this.uid,
    this.email,
    required this.username,
    this.profilePictureUrl,
    this.bio,
    this.location,
    this.savedPlaces = const [],
    this.uploadedPlaces = const [],
    this.purchasedItems = const [],
    required this.createdAt,
    required this.lastLogin,
    this.isEmailVerified = false,
    this.drones = const [],

    // Nuovi campi nel costruttore
    this.profileImageUrl,
    this.flightExperience,
    this.instagram,
    this.youtube,
    this.website,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'profilePictureUrl': profilePictureUrl,
      'bio': bio,
      'location': location,
      'savedPlaces': savedPlaces,
      'uploadedPlaces': uploadedPlaces,
      'purchasedItems': purchasedItems,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'drones': drones,

      // I nuovi campi
      'profileImageUrl': profileImageUrl,
      'flightExperience': flightExperience,
      'instagram': instagram,
      'youtube': youtube,
      'website': website,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'],
      email: map['email'],
      username: map['username'],
      profilePictureUrl: map['profilePictureUrl'],
      bio: map['bio'],
      location: map['location'],
      uploadedPlaces: List<String>.from(map['uploadedPlaces'] ?? []),
      purchasedItems: List<String>.from(map['purchasedItems'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
      lastLogin: DateTime.parse(map['lastLogin']),
      isEmailVerified: map['isEmailVerified'] ?? false,
      drones: List<String>.from(map['drones'] ?? []),

      // Leggiamo i nuovi campi se presenti
      profileImageUrl: map['profileImageUrl'],
      flightExperience: map['flightExperience'], // se è int
      instagram: map['instagram'],
      youtube: map['youtube'],
      website: map['website'],
    );
  }
}
