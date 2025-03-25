import 'dart:async'; // Necessario per il debounce
import 'package:altura/views/auth/verify_email_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Chiave del form per gestire le validazioni
  final _formKey = GlobalKey<FormState>();

  // Controller per gestire gli input dell'utente
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final TextEditingController _username = TextEditingController();

  // Timer usati per implementare il debounce
  Timer? _usernameDebounce;
  Timer? _passwordDebounce;

  // Variabili per gestire la visibilità delle password
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Variabili per visualizzare errori nei campi email, username e password
  String _emailError = '';
  String _usernameError = '';
  String _passwordError = '';

  @override
  void initState() {
    super.initState();
    // Listener per il controllo in tempo reale dello username
    _username.addListener(_onUsernameChanged);
    // Listener per il controllo in tempo reale della password
    _password.addListener(_onPasswordChanged);
  }

  /// Listener che gestisce il debounce per il controllo in tempo reale dello username.
  void _onUsernameChanged() {
    if (_usernameDebounce?.isActive ?? false) _usernameDebounce!.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameUnique();
    });
  }

  /// Controlla se lo username inserito è già presente in Firestore.
  Future<void> _checkUsernameUnique() async {
    final usernameText = _username.text.trim();
    if (usernameText.isEmpty) {
      setState(() {
        _usernameError = '';
      });
      return;
    }
    try {
      bool isUnique = await Auth().isUsernameUnique(usernameText);
      setState(() {
        _usernameError = isUnique ? '' : "L'username è già in uso.";
      });
    } catch (error) {
      print("Errore nel controllo dello username: $error");
    }
  }

  /// Listener che gestisce il debounce per il controllo in tempo reale della password.
  void _onPasswordChanged() {
    if (_passwordDebounce?.isActive ?? false) _passwordDebounce!.cancel();
    _passwordDebounce = Timer(const Duration(milliseconds: 300), () {
      final passwordText = _password.text;
      if (passwordText.isEmpty) {
        setState(() {
          _passwordError = '';
        });
        return;
      }
      if (passwordText.length < 8) {
        setState(() {
          _passwordError = "La password deve avere almeno 8 caratteri.";
        });
      } else if (!RegExp(r'\d').hasMatch(passwordText)) {
        setState(() {
          _passwordError = "La password deve contenere almeno un numero.";
        });
      } else {
        setState(() {
          _passwordError = "";
        });
      }
    });
  }

  /// Funzione per creare un nuovo utente tramite il service centralizzato.
  Future<void> createUser(BuildContext context) async {
    try {
      UserCredential userCredential = await Auth().createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
        username: _username.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null && !user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const VerifyEmailPage()),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        setState(() {
          _emailError = "L'indirizzo email è già utilizzato da un altro account.";
        });
      } else {
        print("Error: ${error.message}");
      }
    } catch (error) {
      if (error.toString().contains("L'username è già in uso")) {
        setState(() {
          _usernameError = "L'username è già in uso.";
        });
      } else {
        print("Errore in fase di creazione dell'utente: $error");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Utilizzo di uno Stack per lo sfondo, overlay e contenuto
      body: Stack(
        children: [
          // Sfondo (puoi modificare l'asset in base al design globale)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_onboarding4.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay scuro per migliorare la leggibilità
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    Text(
                      "Crea il tuo Account",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Campo Username
                    TextFormField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Username",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                        prefixIcon: Icon(Icons.person, color: Colors.white),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Inserisci il tuo username";
                        }
                        if (_usernameError.isNotEmpty) {
                          return _usernameError;
                        }
                        return null;
                      },
                    ),
                    if (_usernameError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _usernameError,
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Campo Email
                    TextFormField(
                      controller: _email,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) {
                        setState(() {
                          _emailError = '';
                        });
                      },
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Inserisci la tua email";
                        }
                        return null;
                      },
                    ),
                    if (_emailError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _emailError,
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Campo Password
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Inserisci una password";
                        }
                        if (_passwordError.isNotEmpty) {
                          return _passwordError;
                        }
                        return null;
                      },
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
                    const SizedBox(height: 20),
                    // Campo Conferma Password
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Conferma Password",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                        prefixIcon: Icon(Icons.lock, color: Colors.white),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
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
                      validator: (value) {
                        if (value == null || value != _password.text) {
                          return "Le password non corrispondono";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    // Bottone di registrazione
                    SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            createUser(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Crea Account",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Link per passare alla schermata di login
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/login_page');
                        },
                        child: RichText(
                          text: TextSpan(
                            text: "Hai già un account? ",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                            children: [
                              TextSpan(
                                text: "Log in",
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
                    const SizedBox(height: 40),
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
    _username.removeListener(_onUsernameChanged);
    _usernameDebounce?.cancel();
    _password.removeListener(_onPasswordChanged);
    _passwordDebounce?.cancel();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _username.dispose();
    super.dispose();
  }
}
