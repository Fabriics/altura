// auth_service.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:altura/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Classe che centralizza tutta la logica di autenticazione e gestione del profilo utente.
/// Include metodi per:
/// - Login e registrazione via email/password.
/// - Login tramite Google.
/// - Invio e verifica email.
/// - Gestione del token FCM per notifiche push.
/// - Caricamento e aggiornamento dei dati utente su Firestore e Firebase Storage.
class Auth {
  // Istanza di FirebaseAuth per gestire l'autenticazione.
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;

  // Istanza di Firestore per salvare e recuperare i dati dell'utente.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Restituisce l'utente attualmente loggato, se presente.
  auth.User? get currentUser => _firebaseAuth.currentUser;

  /// Stream che notifica ogni cambiamento dello stato di autenticazione.
  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Verifica se lo username fornito è univoco, controllando su Firestore.
  Future<bool> isUsernameUnique(String username) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim())
        .get();
    return snapshot.docs.isEmpty;
  }

  /// Esegue il login tramite email e password.
  /// Dopo il login, salva il token FCM per le notifiche push.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Effettua l'accesso con email e password tramite FirebaseAuth.
    await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      // Se il login è andato a buon fine, salva il token FCM per le notifiche.
      await _saveDeviceToken(user.uid);
    }
  }

  /// Esegue il login tramite Google.
  ///
  /// Questo metodo:
  /// 1. Avvia il flusso di selezione dell'account Google.
  /// 2. Ottiene l'autenticazione (accessToken e idToken) dall'account selezionato.
  /// 3. Crea una credenziale Firebase da tali token.
  /// 4. Esegue l'accesso su Firebase con la credenziale ottenuta.
  /// 5. Salva il token FCM per le notifiche push.
  ///
  /// Se l'utente annulla il login, viene lanciata un'eccezione.
  Future<auth.UserCredential> signInWithGoogle() async {
    // Istanza per gestire il login tramite Google.
    final GoogleSignIn googleSignIn = GoogleSignIn();

    // Avvia il processo di selezione dell'account Google.
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      // Se l'utente annulla il login, lancia un'eccezione specifica.
      throw auth.FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Accesso con Google annullato dall\'utente',
      );
    }

    // Ottiene le credenziali di autenticazione per l'account Google selezionato.
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Crea una credenziale Firebase usando l'accessToken e l'idToken forniti da Google.
    final auth.AuthCredential credential = auth.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Effettua l'accesso su Firebase con la credenziale ottenuta.
    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    // Se l'accesso è andato a buon fine, salva il token FCM per le notifiche push.
    final user = userCredential.user;
    if (user != null) {
      await _saveDeviceToken(user.uid);
    }
    return userCredential;
  }

  /// Crea un nuovo utente utilizzando email, password e username.
  /// Invia l'email di verifica e salva i dati utente su Firestore.
  Future<auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    String? bio,
    String? location,
    List<String>? drones,
  }) async {
    // Verifica l'unicità dello username.
    if (!(await isUsernameUnique(username))) {
      throw Exception("L'username è già in uso.");
    }
    try {
      // Crea l'utente su Firebase Authentication.
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Invia l'email di verifica all'utente appena registrato.
      await userCredential.user!.sendEmailVerification();

      // Crea l'oggetto AppUser con i dettagli forniti.
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

      // Salva i dettagli dell'utente su Firestore.
      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());

      // Salva il token FCM per l'utente.
      await _saveDeviceToken(newUser.uid);

      return userCredential;
    } catch (e) {
      print('Errore durante la creazione dell\'utente: $e');
      rethrow;
    }
  }

  /// Effettua il logout dell'utente corrente.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Aggiorna lo stato di verifica dell'email per l'utente specificato su Firestore.
  Future<void> updateUserVerificationStatus(String userId, bool isEmailVerified) async {
    await _firestore.collection('users').doc(userId).update({'isEmailVerified': isEmailVerified});
  }

  /// Ricarica i dati dell'utente e controlla se l'email è stata verificata.
  /// Se la verifica è positiva, aggiorna Firestore e ritorna true.
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

  /// Invia una email per il reset della password all'indirizzo specificato.
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Cambia la password dell'utente corrente.
  Future<void> changePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception("Utente non autenticato");
    }
    await user.updatePassword(newPassword);
  }

  /// Aggiorna la password dopo aver eseguito la reautenticazione dell'utente.
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
    // Crea le credenziali per reautenticare l'utente.
    final credential = auth.EmailAuthProvider.credential(email: email, password: oldPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Metodo privato per salvare o aggiornare il token FCM dell'utente su Firestore.
  Future<void> _saveDeviceToken(String uid) async {
    try {
      // Recupera il token FCM per le notifiche push.
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        print('Impossibile recuperare il token FCM');
        return;
      }
      // Aggiorna il documento dell'utente con il token FCM.
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

  /// Carica l'immagine di profilo su Firebase Storage e aggiorna Firestore con l'URL dell'immagine.
  Future<String?> uploadProfileImage(File imageFile) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception("Utente non loggato");
    // Crea un riferimento nella cartella 'profile_images' e usa l'uid come nome del file.
    final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');
    final snapshot = await storageRef.putFile(imageFile);
    final downloadUrl = await snapshot.ref.getDownloadURL();
    // Aggiorna il documento dell'utente su Firestore con l'URL dell'immagine.
    await _firestore.collection('users').doc(uid).update({'profileImageUrl': downloadUrl});
    return downloadUrl;
  }

  /// Completa il profilo dell'utente aggiornando i campi su Firestore.
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
        // Esegue il forward geocoding per convertire l'indirizzo in coordinate geografiche.
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
