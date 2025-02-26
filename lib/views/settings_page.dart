import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<bool> _expanded = [false, false, false, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Impostazioni',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gestione Social Login non implementata.')),
                    );
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
                  value: true,
                  onChanged: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(value ? 'Notifiche abilitate' : 'Notifiche disabilitate')),
                    );
                  },
                ),
                _buildListTile(
                  'Configura Notifiche',
                  Icons.settings,
                  onTap: () {
                    Navigator.pushNamed(context, '/notification_settings');
                  },
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
      key: ValueKey(sectionIndex), // Chiave unica per ogni sezione
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

  Widget _buildListTile(String title, IconData icon, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0D47A1)),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, IconData icon,
      {required bool value, required ValueChanged<bool> onChanged}) {
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
