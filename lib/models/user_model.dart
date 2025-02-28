class AppUser {
  final String uid;
  final String? email;
  final String username;
  final String? profilePictureUrl;
  final String? bio;
  final String? location;
  final List<String> favoritePlaces;
  final List<String> uploadedPlaces;
  final List<String> purchasedItems;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isEmailVerified;
  final List<String> drones;
  final String? profileImageUrl;
  final int? flightExperience;
  final String? instagram;
  final String? youtube;
  final String? website;

  AppUser({
    required this.uid,
    this.email,
    required this.username,
    this.profilePictureUrl,
    this.bio,
    this.location,
    this.favoritePlaces = const [],
    this.uploadedPlaces = const [],
    this.purchasedItems = const [],
    required this.createdAt,
    required this.lastLogin,
    this.isEmailVerified = false,
    this.drones = const [],
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
      'savedPlaces': favoritePlaces,
      'uploadedPlaces': uploadedPlaces,
      'purchasedItems': purchasedItems,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'drones': drones,
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
      profileImageUrl: map['profileImageUrl'],
      flightExperience: map['flightExperience'],
      instagram: map['instagram'],
      youtube: map['youtube'],
      website: map['website'],
    );
  }
}
