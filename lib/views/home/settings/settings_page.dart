import 'package:flutter/material.dart';
import '../../../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<bool> _expanded = [false, false, false, false];
  bool _notificationsEnabled = false;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  /// Carica la preferenza di abilitazione notifiche tramite il service
  Future<void> _loadNotificationPreference() async {
    final isEnabled = await _settingsService.loadNotificationPreference();
    setState(() {
      _notificationsEnabled = isEnabled;
    });
  }

  /// Salva la preferenza e gestisce l’abilitazione/disabilitazione delle notifiche
  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await _settingsService.saveNotificationPreference(value);
    if (value) {
      final granted = await _settingsService.requestNotificationPermission();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permessi di notifica negati.')),
        );
      }
    } else {
      await _settingsService.disableNotifications();
    }
  }

  /// Costruisce una sezione "collassabile" (Account, Notifiche, Aspetto, Privacy)
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
          leading: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          trailing: Icon(
            _expanded[sectionIndex]
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: Theme.of(context).colorScheme.primary,
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

  /// Costruisce una ListTile generica, eventualmente disabilitata
  Widget _buildListTile(String title, IconData icon,
      {required VoidCallback? onTap}) {
    final bool isDisabled = (onTap == null);
    return ListTile(
      leading: Icon(
        icon,
        color: isDisabled
            ? Colors.grey
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: isDisabled ? Colors.grey : Colors.black,
        ),
      ),
      onTap: onTap,
    );
  }

  /// Costruisce una ListTile dotata di uno switch
  Widget _buildSwitchTile(String title, IconData icon,
      {required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
        activeTrackColor: Colors.grey[300],
        inactiveThumbColor: Colors.grey[800],
        inactiveTrackColor: Colors.grey[200],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        centerTitle: true,
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
                  onTap: () => Navigator.pushNamed(context, '/change_password'),
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
                  onTap: () => Navigator.pushNamed(context, '/delete_account_page'),
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
                  onChanged: (value) => _toggleNotifications(value),
                ),
                _buildListTile(
                  'Configura Notifiche',
                  Icons.settings,
                  onTap: _notificationsEnabled
                      ? () => Navigator.pushNamed(
                      context, '/notification_settings_page')
                      : null,
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
                      const SnackBar(
                          content: Text('Cambio tema non implementato.')),
                    );
                  },
                ),
                _buildListTile(
                  'Lingua',
                  Icons.language,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Selezione lingua non implementata.')),
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
                      const SnackBar(
                          content: Text('Gestione permessi non implementata.')),
                    );
                  },
                ),
                _buildListTile(
                  'Autenticazione a Due Fattori',
                  Icons.shield,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Autenticazione 2FA non implementata.')),
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
}
