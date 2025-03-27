import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/settings_service.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();

  // Controller per i campi Password
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final SettingsService _settingsService = SettingsService();

  bool _isLoading = false;
  String? _errorMessage;

  // Flag per determinare se l'account usa il provider "password"
  bool _isPasswordProvider = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.providerData.isNotEmpty) {
      _isPasswordProvider = (user.providerData.first.providerId == 'password');
    }
  }

  /// Esegue la cancellazione dell'account.
  /// Se l'account è con provider "password", controlla i campi password.
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Nessun utente loggato');
      return;
    }

    if (_isPasswordProvider) {
      if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
        setState(() => _errorMessage = 'Inserisci la password e la conferma');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _errorMessage = 'Le password non corrispondono');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Mostra un dialog di caricamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Passa la password (se l’account è "password") al service.
      await _settingsService.deleteAccount(
        context,
        password: _isPasswordProvider ? _passwordController.text : '',
      );

      // Chiude il dialog di caricamento
      Navigator.of(context, rootNavigator: true).pop();

      // Mostra un messaggio in stile iOS che l’account è stato eliminato.
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Account eliminato"),
          content: const Text(
            "Il tuo account è stato eliminato con successo. "
                "Non potrai più recuperare i tuoi dati.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Chiude l’alert
                // Poi naviga alla pagina di login
                Navigator.of(context).pushReplacementNamed('/login_page');
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _errorMessage = 'Errore durante l\'eliminazione dell\'account: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Elimina account',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF02398E),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Layout simile a screenshot #2
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Testo di avviso
              Text(
                "Se elimini il tuo account non potrai più recuperarlo e non potrai accedere ai tuoi dati.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Sezione con avatar e email
              Row(
                children: [
                  // Avatar (se non c'è photoURL, mostra icona)
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: (user?.photoURL != null)
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: (user?.photoURL == null)
                        ? const Icon(Icons.person, size: 32, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Email e/o displayName
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Se vuoi mostrare un displayName
                      if (user?.displayName != null && user!.displayName!.isNotEmpty)
                        Text(
                          user.displayName!,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Email
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Solo se provider = password, mostra il testo "Inserisci la password..."
              if (_isPasswordProvider)
                Text(
                  "Inserisci la password per procedere con l'eliminazione dell'account:",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

              if (_isPasswordProvider) const SizedBox(height: 16),

              // Campo Password
              if (_isPasswordProvider)
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

              if (_isPasswordProvider) const SizedBox(height: 16),

              // Campo Conferma Password
              if (_isPasswordProvider)
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Conferma Password',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Le password non corrispondono';
                    }
                    return null;
                  },
                ),

              if (_isPasswordProvider) const SizedBox(height: 24),

              // Eventuale messaggio di errore
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),

              // Bottone di eliminazione (stile simile screenshot, in rosso)
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      _deleteAccount();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text(
                    'Elimina account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              // Esempio di link "Supporto" in basso a destra, come da screenshot
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Azione per il supporto
                  },
                  child: Text(
                    'Supporto',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
