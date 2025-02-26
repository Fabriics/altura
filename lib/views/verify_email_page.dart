import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isLoading = false;

  Future<void> _checkEmailVerified() async {
    setState(() {
      isLoading = true;
    });

    User? user = FirebaseAuth.instance.currentUser;

    await user?.reload();
    user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      // Aggiorna Firestore con lo stato verificato
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'isEmailVerified': true});

      // Naviga alla home page
      Navigator.pushReplacementNamed(context, '/complete_profile_page');
    } else {
      setState(() {
        isLoading = false;
      });

    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email di verifica inviata di nuovo.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Verifica la tua email",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Controlla la tua casella di posta e clicca sul link per verificare la tua email.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _checkEmailVerified,
              child: const Text("Ho verificato"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resendVerificationEmail,
              child: const Text("Rinvia Email di Verifica"),
            ),
          ],
        ),
      ),
    );
  }
}
