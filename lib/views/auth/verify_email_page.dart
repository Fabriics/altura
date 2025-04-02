import 'dart:async';
import 'package:altura/services/altura_loader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  // Stato di caricamento per mostrare il loader durante le operazioni.
  bool isLoading = false;
  final Auth _authService = Auth();

  // Variabili per il cooldown del pulsante "Rinvia Email"
  int _resendCooldown = 0;
  bool _canResend = true;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Avvia un countdown di 60 secondi per il pulsante "Rinvia Email".
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

  /// Mostra un toast con il messaggio passato.
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

  /// Controlla se l'email è stata verificata.
  /// Prima controlla che l'utente esista, per evitare errori "utente non trovato".
  Future<void> _checkEmailVerified() async {
    setState(() {
      isLoading = true;
    });

    // Verifica che l'utente loggato esista
    if (FirebaseAuth.instance.currentUser == null) {
      showToast("Utente non trovato.");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      bool verified = await _authService.checkEmailVerified();
      if (verified) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/complete_profile_page');
      } else {
        if (!mounted) return;
        showToast("La email non è ancora verificata.");
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      showToast("Errore durante la verifica: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Invia nuovamente l'email di verifica e avvia il cooldown.
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
    return Scaffold(
      // AppBar: utilizza il colore primario del tema e titolo in bianco
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: Text(
          'Verifica e-mail',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: isLoading
              ? const AlturaLoader()
              : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icona per indicare l'azione di verifica
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      // Titolo del dialogo
                      Text(
                        "Verifica la tua email",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Istruzioni per l'utente
                      Text(
                        "Controlla la tua casella di posta e clicca sul link per verificare la tua email.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      // Pulsante "Fatto": verifica se l'email è stata confermata
                      ElevatedButton.icon(
                        onPressed: _checkEmailVerified,
                        icon: const Icon(Icons.check),
                        label: const Text("Fatto"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Pulsante per rinviare l'email di verifica
                      ElevatedButton.icon(
                        onPressed: _canResend ? _resendVerificationEmail : null,
                        icon: const Icon(Icons.refresh),
                        label: Text(_canResend
                            ? "Rinvia Email di Verifica"
                            : "Rinvia in $_resendCooldown s"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
