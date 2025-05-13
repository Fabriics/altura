import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:altura/services/altura_loader.dart';
import '../../services/auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isLoading = false;
  final Auth _authService = Auth();

  int _resendCooldown = 0;
  bool _canResend = true;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startCooldown() {
    setState(() {
      _resendCooldown = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        setState(() {
          _canResend = true;
          _resendCooldown = 0;
        });
        timer.cancel();
      } else {
        setState(() {
          _resendCooldown--;
        });
      }
    });
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      textColor: Colors.white,
      backgroundColor: Theme.of(context).colorScheme.primary,
      fontSize: 16.0,
    );
  }

  Future<void> _checkEmailVerified() async {
    setState(() {
      isLoading = true;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showToast("Utente non trovato.");
        return;
      }
      // Ricarica i dati dell'utente per ottenere lo stato aggiornato della verifica
      await user.reload();
      user = FirebaseAuth.instance.currentUser;

      if (user?.emailVerified ?? false) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/complete_profile_page');
      } else {
        showToast("La email non è ancora verificata.");
      }
    } catch (e) {
      showToast("Errore durante la verifica: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await _authService.resendVerificationEmail();
      if (!mounted) return;
      showToast("Email di verifica inviata.");
      startCooldown();
    } catch (e) {
      if (!mounted) return;
      showToast("Errore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? "la tua email";
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Verifica e-mail',
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const AlturaLoader()
            : SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header: titolo e descrizione
                        Text(
                          "Verifica la tua email",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ti abbiamo inviato un link di verifica",
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // Contenuto: icona e istruzioni
                        Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mail_outline,
                            size: 32,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Verifica la tua mail tramite il link inviato alla tua casella di posta.",
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Abbiamo inviato un'email a $userEmail",
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // Footer: bottoni per "Fatto" e "Reinvia email"
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _checkEmailVerified,
                                icon: const Icon(Icons.check),
                                label: const Text("Fatto"),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16), backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _canResend
                                    ? _resendVerificationEmail
                                    : null,
                                icon: const Icon(Icons.refresh),
                                label: Text(_canResend
                                    ? "Reinvia email"
                                    : "Reinvia in $_resendCooldown s"),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16), backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      // Footer simile alla FooterSection del componente React
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          "FooterSection",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
