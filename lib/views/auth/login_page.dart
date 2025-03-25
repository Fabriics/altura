import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:altura/services/auth_service.dart';

/// Pagina di login che gestisce l'autenticazione tramite email/password e Google.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Chiave per il form.
  final _formKey = GlobalKey<FormState>();

  // Controller per email e password.
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  // Variabile per la visibilità della password.
  bool _obscurePassword = true;

  // Variabili per i messaggi di errore.
  String _emailError = '';
  String _passwordError = '';
  String _loginError = '';

  // Istanza del servizio di autenticazione.
  final Auth _authService = Auth();

  Future<void> _handleSignIn() async {
    setState(() {
      _loginError = '';
    });
    try {
      await _authService.signInWithEmailAndPassword(
        email: _email.text,
        password: _password.text,
      );
      Navigator.pushReplacementNamed(context, '/main_screen');
    } on FirebaseAuthException catch (error) {
      String errorMessage = "";
      if (error.code == 'invalid-credential') {
        errorMessage = "Email e password non sono corrette. Assicurati di aver inserito correttamente le tue credenziali.";
      } else {
        errorMessage = "Inserisci le credenziali. Riprova.";
      }
      setState(() {
        _loginError = errorMessage;
      });
      print('Errore di autenticazione: ${error.code}');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loginError = '';
    });
    try {
      await _authService.signInWithGoogle();
      Navigator.pushReplacementNamed(context, '/main_screen');
    } on FirebaseAuthException catch (error) {
      setState(() {
        _loginError = "Errore durante il login con Google: ${error.message}";
      });
      print('Errore di Google Sign In: ${error.code}');
    } catch (e) {
      setState(() {
        _loginError = "Si è verificato un errore durante il login con Google.";
      });
      print('Errore generico di Google Sign In: $e');
    }
  }

  void validateEmail(String value) {
    if (value.isEmpty) {
      setState(() {
        _emailError = "Inserisci la tua email";
      });
    } else {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(value)) {
        setState(() {
          _emailError = "Il formato della mail non è corretto";
        });
      } else {
        setState(() {
          _emailError = '';
        });
      }
    }
  }

  void validatePassword(String value) {
    if (value.isEmpty || value.length < 8) {
      setState(() {
        _passwordError = "Inserisci una password di almeno 8 caratteri";
      });
    } else {
      setState(() {
        _passwordError = '';
      });
    }
  }

  void navigateToForgotPassword() {
    Navigator.pushNamed(context, '/forgot_password');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Utilizzo di uno Stack per lo sfondo, l'overlay e il contenuto.
      body: Stack(
        children: [
          // Sfondo: usa lo stesso asset dell'onboarding per uniformità.
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_onboarding4.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay scuro per migliorare la leggibilità.
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          // Contenuto scrollabile.
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // Logo dell'app centrato.
                    Center(
                      child: Image.asset(
                        'assets/logo.png',
                        height: 100,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Messaggio di benvenuto.
                    Text(
                      "Welcome to Altura",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Campo di input per l'email.
                    TextFormField(
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      controller: _email,
                      onChanged: validateEmail,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Email",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                        prefixIcon: Icon(Icons.email, color: Colors.white),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),
                    if (_emailError.isNotEmpty || _loginError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _loginError.isNotEmpty ? _loginError : _emailError,
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    // Campo di input per la password.
                    TextFormField(
                      controller: _password,
                      textInputAction: TextInputAction.done,
                      obscureText: _obscurePassword,
                      onChanged: validatePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Password",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                        prefixIcon: Icon(Icons.lock, color: Colors.white),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),
                    if (_passwordError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _passwordError,
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Link per il recupero della password.
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: navigateToForgotPassword,
                        child: Text(
                          "Password dimenticata?",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Pulsante per il login.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_emailError.isEmpty && _passwordError.isEmpty) {
                            await _handleSignIn();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Login",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Link per la registrazione.
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/signup_page');
                        },
                        child: RichText(
                          text: TextSpan(
                            text: "Non hai un account? ",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                            children: [
                              TextSpan(
                                text: "Registrati",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Divisore.
                    const Divider(color: Colors.white38),
                    const SizedBox(height: 16),
                    // Pulsante per il login tramite Google.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _handleGoogleSignIn,
                        icon: Image.asset(
                          'assets/google-icon.png',
                          height: 24,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Accedi con Google",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.white.withOpacity(0.8)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}
