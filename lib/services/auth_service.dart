import 'dart:io';
import 'package:altura/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:geocoding/geocoding.dart' as geo;

class Auth {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  auth.User? get currentUser => _firebaseAuth.currentUser;

  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Verifica se lo username fornito è univoco su Firestore.
  Future<bool> isUsernameUnique(String username) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim())
        .get();
    return snapshot.docs.isEmpty;
  }

  /// Login con email e password.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    print('Inizio signInWithEmailAndPassword per email: $email');
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Sign in completato. userCredential: $userCredential');

      final user = _firebaseAuth.currentUser;
      if (user == null) {
        print('Errore: currentUser è null dopo il sign in.');
        throw Exception('Utente non trovato');
      }
      print('Utente trovato: UID=${user.uid}, emailVerified=${user.emailVerified}');

      if (!user.emailVerified) {
        print('Errore: Email non verificata per l’utente ${user.uid}');
        throw auth.FirebaseAuthException(
          code: 'email-not-verified',
          message: 'La tua email non è ancora verificata. Verifica la tua casella e clicca sul link di verifica.',
        );
      }

      await _saveDeviceToken(user.uid);
      print('Token FCM salvato con successo per l’utente ${user.uid}');
    } catch (e, stacktrace) {
      print('Errore durante signInWithEmailAndPassword: $e');
      print('Stack trace: $stacktrace');
      rethrow;
    }
  }

  /// Login con Google.
  Future<auth.UserCredential> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw auth.FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Accesso con Google annullato dall\'utente',
      );
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = auth.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      await _saveDeviceToken(user.uid);
    }
    return userCredential;
  }

  /// Crea un nuovo utente con email, password e username.
  Future<auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    String? bio,
    String? location,
    List<String>? drones,
  }) async {
    if (!(await isUsernameUnique(username))) {
      throw Exception("L'username è già in uso.");
    }
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Invia l'email di verifica
      await userCredential.user!.sendEmailVerification();

      // Crea un AppUser con dati di default
      final newUser = AppUser(
        uid: userCredential.user!.uid,
        email: email,
        username: username,
        bio: bio,
        location: location,
        favoritePlaces: [],
        uploadedPlaces: [],
        droneActivities: [],
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: false,
        isCertified: false,
        isAvailable: false,
        dronesList: drones ?? [],
        flightExperience: 0,
        pilotLevel: null,
        instagram: null,
        youtube: null,
        website: null,
        fcmToken: null,
        latitude: null,
        longitude: null,
        distanceKm: null,
        certificationUrl: null,
        certificationStatus: null,
        certificationType: null,
      );

      // Salva l'utente su Firestore
      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      await _saveDeviceToken(newUser.uid);

      return userCredential;
    } catch (e) {
      print('Errore durante la creazione dell\'utente: $e');
      rethrow;
    }
  }

  /// Logout.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Aggiorna su Firestore lo stato di verifica email.
  Future<void> updateUserVerificationStatus(String userId, bool isEmailVerified) async {
    await _firestore.collection('users').doc(userId).update({'isEmailVerified': isEmailVerified});
  }

  /// Ricarica i dati utente e controlla la verifica email.
  Future<bool> checkEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception("Utente non trovato");
    }
    await user.reload();
    final refreshedUser = _firebaseAuth.currentUser;
    if (refreshedUser != null && refreshedUser.emailVerified) {
      await updateUserVerificationStatus(refreshedUser.uid, true);
      return true;
    }
    return false;
  }

  /// Reinvia l'email di verifica.
  Future<void> resendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception("Utente non trovato");
    }
    await user.sendEmailVerification();
  }

  /// Reset password via email.
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Cambia password dell'utente corrente.
  Future<void> changePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception("Utente non autenticato");
    }
    await user.updatePassword(newPassword);
  }

  /// Aggiorna password dopo reautenticazione.
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception("Utente non autenticato");
    }
    final email = user.email;
    if (email == null) {
      throw Exception("Email utente non disponibile");
    }
    final credential = auth.EmailAuthProvider.credential(email: email, password: oldPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Salva/aggiorna il token FCM su Firestore.
  Future<void> _saveDeviceToken(String uid) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        print('Impossibile recuperare il token FCM');
        return;
      }
      await _firestore.collection('users').doc(uid).update({'fcmToken': fcmToken});
      print('Token FCM salvato con successo: $fcmToken');
    } catch (e) {
      print('Errore nel salvataggio del token FCM: $e');
    }
  }

  /// Carica i dati profilo dell'utente corrente da Firestore.
  Future<Map<String, dynamic>?> loadUserProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Carica l'immagine profilo su Firebase Storage e aggiorna Firestore con l'URL.
  Future<String?> uploadProfileImage(File imageFile) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception("Utente non loggato");
    final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');
    final snapshot = await storageRef.putFile(imageFile);
    final downloadUrl = await snapshot.ref.getDownloadURL();
    await _firestore.collection('users').doc(uid).update({'profileImageUrl': downloadUrl});
    return downloadUrl;
  }

  /// Completa il profilo aggiornando i campi su Firestore.
  Future<void> completeProfile({
    required String username,
    required String bio,
    required String website,
    required String instagram,
    required String youtube,
    required int flightExperience,
    required List<String> drones,
    required List<String> droneActivities,
    required String location,
    bool? isCertified,
    String? certificationStatus,
    String? certificationUrl,
    String? pilotLevel,           // Nuovo parametro
    String? certificationType,    // Nuovo parametro
  }) async {
    double? lat;
    double? lng;
    final trimmedLocation = location.trim();

    if (trimmedLocation.isNotEmpty) {
      try {
        final locations = await geo.locationFromAddress(trimmedLocation);
        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        }
      } catch (e) {
        print('Impossibile fare geocoding per $trimmedLocation: $e');
      }
    }

    final profileData = {
      'username': username.trim(),
      'bio': bio.trim(),
      'website': website.trim(),
      'instagram': instagram.trim(),
      'youtube': youtube.trim(),
      'flightExperience': flightExperience, // Ora flightExperience è un int
      'drones': drones,
      'droneActivities': droneActivities,
      'location': trimmedLocation,
      'pilotLevel': pilotLevel,              // Salvato su Firestore
      'certificationType': certificationType, // Salvato su Firestore
      'isCertified': isCertified,
      'certificationStatus': certificationStatus,
      'certificationUrl': certificationUrl,
    };

    final uid = currentUser?.uid;
    if (uid == null) throw Exception("Utente non loggato");
    await _firestore.collection('users').doc(uid).update(profileData);
  }
}
