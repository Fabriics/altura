import 'package:flutter/material.dart';
import 'package:altura/services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Controller per il campo email
  final TextEditingController _email = TextEditingController();

  String _emailError = "Inserisci la tua email";
  String _loginError = '';
  String _userEmail = ''; // Per salvare l'email inserita

  // Step tracker: 1 = Email, 2 = Code (visualizzazione messaggio di reset)
  int _step = 1;

  final Auth _authService = Auth();

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

  void _backToLogin() {
    Navigator.pushNamed(context, '/login_page');
  }

  void _sendEmail() async {
    try {
      await _authService.sendPasswordResetEmail(email: _email.text);
      setState(() {
        _userEmail = _email.text; // Salva l'email inserita
        _step = 2;
      });
    } catch (error) {
      // Puoi gestire errori aggiuntivi se necessario
      setState(() {
        _loginError = "Errore durante l'invio della mail di reset";
      });
    }
  }

  Widget _buildContent() {
    if (_step == 1) {
      return _buildEmailStep();
    } else if (_step == 2) {
      return _buildRestPasswordPage();
    }
    return const SizedBox.shrink();
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Per modificare la tua password, inserisci la tua mail.",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 10),
        Text(
          "Se la tua mail è presente nel database ti verrà inviato una mail con le istruzioni per cambiare la tua password.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              setState(() {
                _loginError = ''; // Resetta l'errore
              });
              if (_emailError.isEmpty) {
                _sendEmail();
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Procedi",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _backToLogin,
            child: Text(
              "Torna alla pagina di Login",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestPasswordPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Email inviata a $_userEmail.",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 10),
        Text(
          "Segui le istruzioni ricevute nella tua email per resettare la password.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _backToLogin,
            child: Text(
              "Torna alla pagina di Login",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        title: Text(
          'Reimposta la password',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildContent(),
      ),
    );
  }
}

