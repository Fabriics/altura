import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isLoading = false;
  final Auth _authService = Auth(); // Istanza del servizio centralizzato

  /// Controlla se l'email è stata verificata.
  /// Se la verifica ha esito positivo, naviga alla pagina di completamento del profilo.
  Future<void> _checkEmailVerified() async {
    setState(() {
      isLoading = true;
    });

    try {
      bool verified = await _authService.checkEmailVerified();
      if (verified) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/complete_profile_page');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("La email non è ancora verificata.")),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante la verifica: $e")),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Invia nuovamente l'email di verifica tramite il servizio centralizzato.
  Future<void> _resendVerificationEmail() async {
    try {
      await _authService.resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email di verifica inviata di nuovo.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea per evitare problemi su dispositivi con notch o altri elementi di sistema
      body: SafeArea(
        child: Center(
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
                child: const Text("Rinvia Email di Verifica",
                  style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
