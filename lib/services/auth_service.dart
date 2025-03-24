import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:altura/models/user.dart';

class Auth {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  auth.User? get currentUser => _firebaseAuth.currentUser;
  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Verifica l'unicità dello username.
  Future<bool> isUsernameUnique(String username) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim())
        .get();
    return snapshot.docs.isEmpty;
  }

  /// Effettua il login e salva il token FCM.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await _saveDeviceToken(user.uid);
    }
  }

  /// Crea l'utente, verifica l'unicità dello username, invia l'email di verifica,
  /// salva i dettagli su Firestore e il token FCM.
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
      await userCredential.user!.sendEmailVerification();
      final newUser = AppUser(
        uid: userCredential.user!.uid,
        email: email,
        username: username,
        bio: bio,
        location: location,
        drones: drones ?? [],
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: userCredential.user!.emailVerified,
      );
      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      await _saveDeviceToken(newUser.uid);
      return userCredential;
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  /// Effettua il logout.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Aggiorna lo stato di verifica email su Firestore per l'utente specificato.
  Future<void> updateUserVerificationStatus(String userId, bool isEmailVerified) async {
    await _firestore.collection('users').doc(userId).update({'isEmailVerified': isEmailVerified});
  }

  /// Ricarica i dati dell'utente e controlla se l'email è verificata.
  /// Se sì, aggiorna Firestore e restituisce true.
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

  /// Invia nuovamente l'email di verifica all'utente corrente.
  Future<void> resendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception("Utente non trovato");
    }
    await user.sendEmailVerification();
  }

  /// Salva (o aggiorna) il token FCM nel documento utente su Firestore.
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

  /// Carica i dati del profilo dell'utente corrente da Firestore.
  Future<Map<String, dynamic>?> loadUserProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Carica l'immagine di profilo su Firebase Storage e aggiorna Firestore.
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
  /// Se viene fornita una località, esegue il forward geocoding per ottenere latitudine e longitudine.
  Future<void> completeProfile({
    required String username,
    required String bio,
    required String website,
    required String instagram,
    required String youtube,
    required String flightExperience,
    required List<String> drones,
    required String location,
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
          print('Geocoding riuscito: $trimmedLocation -> lat=$lat, lng=$lng');
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
      'flightExperience': int.tryParse(flightExperience.trim()) ?? 0,
      'drones': drones,
      'location': trimmedLocation,
      'latitude': lat,
      'longitude': lng,
    };
    final uid = currentUser?.uid;
    if (uid == null) throw Exception("Utente non loggato");
    await _firestore.collection('users').doc(uid).update(profileData);
  }
}
