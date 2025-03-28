import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/altura_loader.dart';
import '../../../services/settings_service.dart';

/// Pagina per l'eliminazione dell'account.
/// Se l'utente utilizza il provider "password", vengono richiesti anche i campi per la password e la sua conferma.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  // Chiave per il form, utile per la validazione.
  final _formKey = GlobalKey<FormState>();

  // Controller per i campi "Password" e "Conferma Password".
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Istanza del service per le operazioni sulle impostazioni.
  final SettingsService _settingsService = SettingsService();

  // Stato di caricamento e messaggio d'errore.
  bool _isLoading = false;
  String? _errorMessage;

  // Flag per determinare se l'utente usa il provider "password".
  bool _isPasswordProvider = false;

  @override
  void initState() {
    super.initState();
    // Verifica se il provider dell'utente è "password" per decidere se mostrare i campi password.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.providerData.isNotEmpty) {
      _isPasswordProvider = (user.providerData.first.providerId == 'password');
    }
  }

  /// Esegue la cancellazione dell'account.
  /// Se l'account utilizza il provider "password", controlla che i campi password siano corretti.
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Nessun utente loggato');
      return;
    }

    // Se l'account usa il provider "password", controlla che i campi siano compilati correttamente.
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

    // Mostra un dialog di caricamento (utilizza AlturaLoader).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: AlturaLoader()),
    );

    try {
      // Chiama il metodo deleteAccount del SettingsService, passando la password se necessaria.
      await _settingsService.deleteAccount(
        context,
        password: _isPasswordProvider ? _passwordController.text : '',
      );

      // Chiude il dialog di caricamento.
      Navigator.of(context, rootNavigator: true).pop();

      // Mostra un dialog di conferma dell'eliminazione e naviga alla pagina di login.
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
                Navigator.of(ctx).pop(); // Chiude l'alert.
                Navigator.of(context).pushReplacementNamed('/login_page');
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      // Chiude il dialog di caricamento in caso di errore.
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _errorMessage = 'Errore durante l\'eliminazione dell\'account: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    // Libera le risorse dei controller.
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // L'AppBar utilizza il tema globale (appBarTheme) per il background e le icone.
      appBar: AppBar(
        title: const Text('Elimina account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Testo di avviso: spiega le conseguenze della cancellazione dell'account.
              Text(
                "Se elimini il tuo account non potrai più recuperarlo e non potrai accedere ai tuoi dati.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              // Sezione con avatar e informazioni utente.
              Row(
                children: [
                  // Avatar: se non c'è photoURL, mostra un'icona.
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
                  // Visualizza displayName (se presente) ed email.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user?.displayName != null && user!.displayName!.isNotEmpty)
                        Text(
                          user.displayName!,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Se l'account usa il provider "password", mostra un messaggio e i campi per la password.
              if (_isPasswordProvider)
                Text(
                  "Inserisci la password per procedere con l'eliminazione dell'account:",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (_isPasswordProvider) const SizedBox(height: 16),
              // Campo per la Password.
              if (_isPasswordProvider)
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    // Utilizza il fillColor definito nell'inputDecorationTheme per coerenza.
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              if (_isPasswordProvider) const SizedBox(height: 16),
              // Campo per la Conferma Password.
              if (_isPasswordProvider)
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Conferma Password',
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
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
              // Visualizza eventuali messaggi di errore.
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16),
              // Bottone per eliminare l'account.
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
                    // Usa il colore di errore dal tema per il pulsante (tipicamente rossoAccent).
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
              // Link "Supporto" posizionato in basso a destra.
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Azione per il supporto da implementare.
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
