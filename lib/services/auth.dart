import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:altura/models/user_model.dart';

class Auth {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  auth.User? get currentUser => _firebaseAuth.currentUser;

  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Aggiornata per restituire un UserCredential
  Future<auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    String? bio,
    String? location,
    List<String>? drones,
  }) async {
    try {
      // Crea l'utente in Firebase Authentication
      auth.UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Crea l'oggetto User personalizzato con dettagli aggiuntivi
      AppUser user = AppUser(
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

      // Salva i dettagli dell'utente in Firestore
      await _firestore.collection('users').doc(user.uid).set(user.toMap());

      // Restituisce l'utente appena creato
      return userCredential;
    } catch (e) {
      print('Error creating user: $e');
      rethrow; // Rilancia l'errore per gestirlo nel chiamante
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> updateUserVerificationStatus(String userId, bool isEmailVerified) async {
    await _firestore.collection('users').doc(userId).update({
      'isEmailVerified': isEmailVerified,
    });
  }
}
