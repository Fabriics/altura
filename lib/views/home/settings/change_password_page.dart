import 'package:flutter/material.dart';
import 'package:altura/services/auth_service.dart';
import '../../../services/altura_loader.dart';

/// Pagina per il cambio della password.
/// L'utente deve inserire la vecchia password, la nuova password e la conferma
/// della nuova password. La logica per reautenticarsi e aggiornare la password
/// è centralizzata nel metodo updatePassword del service Auth.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // Chiave per il form, utile per validare i campi
  final _formKey = GlobalKey<FormState>();

  // Controller per i campi di testo: vecchia password, nuova password e conferma nuova password
  final TextEditingController _oldPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  // Variabili per la gestione della visibilità dei campi password
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Variabile per gestire lo stato di caricamento (per evitare richieste multiple)
  bool _isLoading = false;

  // Istanza del service di autenticazione per gestire il cambio password
  final Auth _authService = Auth();

  /// Gestisce il cambio password:
  /// 1. Valida i campi del form
  /// 2. Chiama il metodo updatePassword del service, che gestisce la reautenticazione e l'aggiornamento
  /// 3. Mostra un messaggio di successo o errore e, in caso di successo, torna alla schermata precedente
  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await _authService.updatePassword(
        oldPassword: _oldPassword.text,
        newPassword: _newPassword.text,
      );
      // Mostra un messaggio di conferma in caso di successo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password aggiornata con successo!')),
      );
      Navigator.pop(context);
    } catch (e) {
      // In caso di errore, mostra il messaggio di errore tramite SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // L'AppBar utilizza il tema globale (appBarTheme) definito in app_theme
      appBar: AppBar(
        title: const Text('Cambia Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo per l'inserimento della vecchia password
              TextFormField(
                controller: _oldPassword,
                obscureText: _obscureOldPassword,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Inserisci la vecchia password";
                  }
                  if (value.length < 8) {
                    return "La password deve contenere almeno 8 caratteri";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: "Vecchia Password",
                  // Usa lo stile hint definito nell'inputDecorationTheme del tema
                  hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                  prefixIcon: Icon(
                    Icons.lock,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureOldPassword ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureOldPassword = !_obscureOldPassword;
                      });
                    },
                  ),
                  // Usa il fillColor e il border definiti nel tema
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16.0),
              // Campo per l'inserimento della nuova password
              TextFormField(
                controller: _newPassword,
                obscureText: _obscureNewPassword,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 8) {
                    return "Inserisci una nuova password valida (almeno 8 caratteri)";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: "Nuova Password",
                  hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                  prefixIcon: Icon(
                    Icons.lock,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16.0),
              // Campo per la conferma della nuova password
              TextFormField(
                controller: _confirmPassword,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Conferma la nuova password";
                  }
                  if (value != _newPassword.text) {
                    return "Le password non corrispondono";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: "Conferma Nuova Password",
                  hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                  prefixIcon: Icon(
                    Icons.lock,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24.0),
              // Pulsante per inviare il form di aggiornamento password
              Center(
                child: ElevatedButton(
                  // Disabilita il pulsante se è in caricamento
                  onPressed: _isLoading ? null : _handleChangePassword,
                  style: ElevatedButton.styleFrom(
                    // Usa il backgroundColor primario (Blu profondo) dal tema
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    // Imposta il padding coerente con il tema (verticale 12, orizzontale 24)
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    // Bordo arrotondato a 20, come definito nel tema elevatedButtonTheme
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  // Mostra il loader se in caricamento, altrimenti il testo del pulsante
                  child: _isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: AlturaLoader(),
                  )
                      : Text(
                    "Aggiorna Password",
                    // Usa lo stile titleLarge del tema per il testo, impostando il colore a bianco
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
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

  @override
  void dispose() {
    // Libera le risorse dei controller per i campi di testo
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }
}
