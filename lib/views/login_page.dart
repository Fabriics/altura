import 'package:altura/services/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscurePassword = true;
  String _emailError = '';
  String _passwordError = '';
  String _loginError = ''; // Messaggio di errore per credenziali errate

  Future<bool> signIn(BuildContext context) async {
    try {
      await Auth().signInWithEmailAndPassword(
        email: _email.text,
        password: _password.text,
      );
      return true; // Login riuscito
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-credential') {
        setState(() {
          _loginError = "Email e password non sono corrette. Assicurati di aver inserito correttamente le tue credenziali di accesso.";
        });
      } else {
        setState(() {
          _loginError = "Si è verificato un errore sconosciuto. Riprova.";
        });
      }
      print(error.code);
      return false; // Login fallito
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
    Navigator.pushNamed(context, '/forgot_password'); // Modifica con la tua route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo al centro
                  Center(
                    child: Image.asset(
                      'assets/logo.png', // Sostituisci con il percorso del tuo logo
                      height: 100,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Testo di benvenuto
                  Text(
                    "Welcome to Altura",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Campo Email
                  TextFormField(
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    controller: _email,
                    onChanged: validateEmail,
                    decoration: InputDecoration(
                      hintText: "Email",
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                      prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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

                  // Campo Password
                  TextFormField(
                    controller: _password,
                    textInputAction: TextInputAction.done,
                    obscureText: _obscurePassword,
                    onChanged: validatePassword,
                    decoration: InputDecoration(
                      hintText: "Password",
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                      prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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

                  // Password dimenticata
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: navigateToForgotPassword,
                      child: Text(
                        "Password dimenticata?",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pulsante di Login
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _loginError = ''; // Resetta l'errore
                        });
                        if (_emailError.isEmpty && _passwordError.isEmpty) {
                          final success = await signIn(context);
                          if (success) {
                            Navigator.pushNamed(context, '/home_page');
                          }
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/signup_page');
                      },
                      child: RichText(
                        text: TextSpan(
                          text: "Non hai un account? ",
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            TextSpan(
                              text: "Registrati",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Pulsante Google
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Logica di login con Google
                      },
                      icon: Image.asset(
                        'assets/google-icon.png', // Sostituisci con il percorso dell'icona di Google
                        height: 24,
                      ),
                      label: const Text(
                        "Accedi con Google",
                        style: TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[400]!),
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
