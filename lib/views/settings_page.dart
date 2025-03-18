import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<bool> _expanded = [false, false, false, false];

  // Aggiungiamo una variabile di stato per le notifiche
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    // Carichiamo la preferenza locale appena la pagina viene creata
    _loadNotificationPreference();
  }

  // Carica la preferenza di abilitazione notifiche, per esempio da SharedPreferences
  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    // Se non esiste la chiave 'notifications_enabled', assume false di default
    final bool isEnabled = prefs.getBool('notifications_enabled') ?? false;
    setState(() {
      _notificationsEnabled = isEnabled;
    });
  }

  // Salva la preferenza nel momento in cui l’utente abilita/disabilita le notifiche
  Future<void> _saveNotificationPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  // Richiede i permessi di notifica (necessario su iOS, opzionale su Android)
  Future<void> _requestNotificationPermission() async {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Utente ha concesso i permessi di notifica.');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('Autorizzazione provvisoria per le notifiche.');
    } else {
      debugPrint('Permesso negato: notifiche non autorizzate.');
    }
  }

  // Disabilita la ricezione delle notifiche
  Future<void> _disableNotifications() async {
    // Esempio: disiscrivi l’utente da un topic
    // await FirebaseMessaging.instance.unsubscribeFromTopic('tua_topic');
    debugPrint('Notifiche disabilitate (logica personalizzabile).');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        elevation: 0,
        title: Text(
          'Impostazioni',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSection(
              context,
              sectionIndex: 0,
              title: 'Account',
              icon: Icons.person,
              content: [
                _buildListTile(
                  'Cambia Password',
                  Icons.lock,
                  onTap: () {
                    Navigator.pushNamed(context, '/change_password');
                  },
                ),
                _buildListTile(
                  'Gestione Social Login',
                  Icons.link,
                  onTap: () {
                    // Da implementare
                  },
                ),
                _buildListTile(
                  'Elimina Account',
                  Icons.delete,
                  onTap: () {
                    _showDeleteAccountDialog(context);
                  },
                ),
              ],
            ),
            _buildSection(
              context,
              sectionIndex: 1,
              title: 'Notifiche',
              icon: Icons.notifications,
              content: [
                _buildSwitchTile(
                  'Abilita Notifiche',
                  Icons.notifications_active,
                  value: _notificationsEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _notificationsEnabled = value;
                    });

                    // Salviamo la preferenza
                    await _saveNotificationPreference(value);

                    // Se l'utente abilita, chiediamo i permessi
                    if (value) {
                      await _requestNotificationPermission();
                    } else {
                      await _disableNotifications();
                    }
                  },
                ),
                // "Configura Notifiche" disabilitato se _notificationsEnabled == false
                _buildListTile(
                  'Configura Notifiche',
                  Icons.settings,
                  onTap: _notificationsEnabled
                      ? () {
                    Navigator.pushNamed(context, '/notification_settings_page');
                  }
                      : null, // Se null, il tile è disabilitato
                ),
              ],
            ),
            _buildSection(
              context,
              sectionIndex: 2,
              title: 'Aspetto',
              icon: Icons.visibility,
              content: [
                _buildListTile(
                  'Tema App',
                  Icons.brightness_6,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cambio tema non implementato.')),
                    );
                  },
                ),
                _buildListTile(
                  'Lingua',
                  Icons.language,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Selezione lingua non implementata.')),
                    );
                  },
                ),
              ],
            ),
            _buildSection(
              context,
              sectionIndex: 3,
              title: 'Privacy',
              icon: Icons.lock,
              content: [
                _buildListTile(
                  'Permessi App',
                  Icons.security,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gestione permessi non implementata.')),
                    );
                  },
                ),
                _buildListTile(
                  'Autenticazione a Due Fattori',
                  Icons.shield,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Autenticazione 2FA non implementata.')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, {
        required int sectionIndex,
        required String title,
        required IconData icon,
        required List<Widget> content,
      }) {
    return Column(
      key: ValueKey(sectionIndex),
      children: [
        ListTile(
          leading: Icon(icon, color: const Color(0xFF0D47A1)),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Icon(
            _expanded[sectionIndex]
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: const Color(0xFF0D47A1),
          ),
          onTap: () {
            setState(() {
              for (int i = 0; i < _expanded.length; i++) {
                _expanded[i] = i == sectionIndex ? !_expanded[i] : false;
              }
            });
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _expanded[sectionIndex]
              ? Column(children: content)
              : const SizedBox.shrink(),
        ),
        const Divider(),
      ],
    );
  }

  /// Ora onTap può essere null, quindi cambiamo la firma:
  Widget _buildListTile(String title, IconData icon, {required VoidCallback? onTap}) {
    final bool isDisabled = (onTap == null);
    return ListTile(
      leading: Icon(
        icon,
        // Se disabilitato, l’icona è grigia
        color: isDisabled ? Colors.grey : const Color(0xFF0D47A1),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          // Se disabilitato, il testo è grigio
          color: isDisabled ? Colors.grey : Colors.black,
        ),
      ),
      onTap: onTap, // Se null, il tile non risponde ai tap
    );
  }

  Widget _buildSwitchTile(
      String title,
      IconData icon, {
        required bool value,
        required ValueChanged<bool> onChanged,
      }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0D47A1)),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF0D47A1),
        activeTrackColor: Colors.grey[300],
        inactiveThumbColor: Colors.grey[800],
        inactiveTrackColor: Colors.grey[200],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Conferma Eliminazione'),
          backgroundColor: Colors.white,
          content: const Text(
            'Sei sicuro di voler eliminare il tuo account? Questa azione è irreversibile.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Chiudi il dialog
              },
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Chiudi il dialog
                _deleteAccount(); // Elimina l'account
              },
              child: const Text(
                'Elimina',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    // Simula la logica di eliminazione (aggiorna con Firebase o altro)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await Future.delayed(const Duration(seconds: 2)); // Simulazione di un'attesa

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Chiudi il dialog di caricamento
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account eliminato con successo!')),
      );
      Navigator.of(context).pushReplacementNamed('/login_page'); // Naviga al login
    }
  }
}
