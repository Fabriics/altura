import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'altura_loader.dart';
import 'auth_service.dart';

/// Classe che raggruppa la logica di "Impostazioni":
/// - Gestione preferenze notifiche (SharedPreferences)
/// - Richiesta permessi notifica (FirebaseMessaging)
/// - Disabilitazione notifiche
/// - Eliminazione completa account
class SettingsService {
  final Auth _authService = Auth();

  /// Carica la preferenza di abilitazione notifiche da SharedPreferences.
  Future<bool> loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? false;
  }

  /// Salva la preferenza di abilitazione notifiche in SharedPreferences.
  Future<void> saveNotificationPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  /// Richiede i permessi di notifica (necessario su iOS, opzionale su Android).
  Future<bool> requestNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional);
  }

  /// Disabilita le notifiche (esempio: disiscrizione da un topic).
  Future<void> disableNotifications() async {
    // Esempio:
    // await FirebaseMessaging.instance.unsubscribeFromTopic('nome_topic');
  }

  /// Elimina COMPLETAMENTE l'account utente da Firebase.
  /// - Verifica che l’utente sia loggato.
  /// - Elimina documenti in 'chat' (dove userId == uid).
  /// - Elimina documenti in 'places' (dove userId == uid).
  ///   Per ogni place, elimina i file in 'placeMedia/<docId>'.
  /// - Elimina la cartella 'profile_images/<uid>'.
  /// - Elimina il documento dell’utente in 'users/<uid>'.
  /// - Elimina l’account da FirebaseAuth.
  ///
  /// Il parametro [password] (obbligatorio solo per il provider "password")
  /// viene passato dal form della DeleteAccountPage.
  Future<void> deleteAccount(
      BuildContext context, {
        required String password,
      }) async {
    // Mostra un dialog di caricamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: AlturaLoader()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Nessun utente loggato");
      }
      final userId = user.uid;
      debugPrint("deleteAccount: Inizio procedura per utente uid: $userId");

      // Reautenticazione
      await _reauthenticateUser(context, user, password: password);
      debugPrint("deleteAccount: Reautenticazione completata per uid: $userId");

      // 1) Elimina i documenti in 'chat' relativi all’utente
      final chatSnap = await FirebaseFirestore.instance
          .collection('chat')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in chatSnap.docs) {
        debugPrint("deleteAccount: Elimino doc 'chat' con id: ${doc.id}");
        await doc.reference.delete();
      }

      // 2) Trova tutti i documenti in 'places' dove userId == uid
      final placesSnap = await FirebaseFirestore.instance
          .collection('places')
          .where('userId', isEqualTo: userId)
          .get();

      // Per ognuno, eliminiamo prima i file in placeMedia/<docId>, poi il documento
      for (final doc in placesSnap.docs) {
        final docId = doc.id;
        debugPrint("deleteAccount: Elimino doc 'places' con id: $docId");

        // Elimina i file nella cartella placeMedia/<docId>
        final placeMediaRef = FirebaseStorage.instance.ref('placeMedia/$docId');
        final placeMediaList = await placeMediaRef.listAll();
        for (final fileRef in placeMediaList.items) {
          debugPrint("deleteAccount: Elimino file in 'placeMedia/$docId': ${fileRef.name}");
          await fileRef.delete();
        }

        // Ora elimino il documento su Firestore
        await doc.reference.delete();
      }

      // 3) Elimina TUTTI i file nella cartella profile_images/<uid>
      final profileImagesRef = FirebaseStorage.instance.ref('profile_images/$userId');
      final profileImagesList = await profileImagesRef.listAll();
      for (final fileRef in profileImagesList.items) {
        debugPrint("deleteAccount: Elimino file in 'profile_images/$userId': ${fileRef.name}");
        await fileRef.delete();
      }

      // 4) Elimina il documento dell’utente in 'users/<uid>'
      debugPrint("deleteAccount: Elimino il documento utente in 'users/$userId'");
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      // 5) Elimina l’account da FirebaseAuth
      debugPrint("deleteAccount: Elimino l'account FirebaseAuth per uid: $userId");
      await user.delete();

      // 6) Chiudi dialog e naviga al login
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Chiude il dialog
        Navigator.of(context).pushReplacementNamed('/login_page');
      }
    } catch (e, stacktrace) {
      debugPrint("deleteAccount: Errore durante l'eliminazione: $e");
      debugPrint("deleteAccount: StackTrace: $stacktrace");
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Chiude il dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'eliminazione dell\'account: $e')),
        );
      }
    }
  }

  /// Reautenticazione generica dell'utente.
  /// Per il provider "password" utilizza il parametro [password].
  Future<void> _reauthenticateUser(BuildContext context, User user, {String? password}) async {
    final providerData = user.providerData;
    if (providerData.isEmpty) {
      throw Exception("Nessun provider disponibile per la reautenticazione");
    }
    final providerId = providerData.first.providerId;

    if (providerId == 'password') {
      final email = user.email;
      if (email == null) {
        throw Exception("Email utente non disponibile per la reautenticazione");
      }
      if (password == null || password.isEmpty) {
        throw Exception("Reinserisci la password");
      }
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);
      debugPrint("_reauthenticateUser: Reautenticazione con email/password completata");
    } else if (providerId == 'google.com') {
      // Reautenticazione con Google
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception("Accesso con Google annullato dall'utente");
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      debugPrint("_reauthenticateUser: Reautenticazione con Google completata");
    } else {
      throw Exception("Provider non gestito: $providerId");
    }
  }
}
