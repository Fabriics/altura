import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _chatNotificationsEnabled = true;
  bool _systemNotificationsEnabled = true;
  bool _notificationSoundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  /// Carica i valori salvati in SharedPreferences
  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _chatNotificationsEnabled = prefs.getBool('chatNotifications') ?? true;
      _systemNotificationsEnabled = prefs.getBool('systemNotifications') ?? true;
      _notificationSoundEnabled = prefs.getBool('notificationSound') ?? true;
    });
  }

  /// Salva i valori correnti in SharedPreferences
  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chatNotifications', _chatNotificationsEnabled);
    await prefs.setBool('systemNotifications', _systemNotificationsEnabled);
    await prefs.setBool('notificationSound', _notificationSoundEnabled);
  }

  /// Funzioni placeholder per logiche personalizzate (abilitare/disabilitare)
  Future<void> _requestChatNotificationsPermission() async {
    debugPrint('Richiesta permessi/abilitazione Chat Notifications...');
  }

  Future<void> _disableChatNotifications() async {
    debugPrint('Disabilitate Chat Notifications...');
  }

  Future<void> _requestSystemNotificationsPermission() async {
    debugPrint('Richiesta permessi/abilitazione System Notifications...');
  }

  Future<void> _disableSystemNotifications() async {
    debugPrint('Disabilitate System Notifications...');
  }

  Future<void> _enableNotificationSound() async {
    debugPrint('Suono notifiche abilitato...');
  }

  Future<void> _disableNotificationSound() async {
    debugPrint('Suono notifiche disabilitato...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Configura Notifiche',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        children: [
          // NOTIFICHE CHAT
          SwitchListTile(
            // Icona a sinistra in blu
            secondary: const Icon(Icons.mail, color: Color(0xFF0D47A1)),
            // Testo con stile bodyMedium
            title: Text(
              'Notifiche Chat',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            // Stato del toggle
            value: _chatNotificationsEnabled,
            // Colore del toggle quando attivo
            activeColor: const Color(0xFF0D47A1),
            activeTrackColor: Colors.grey[300],
            inactiveThumbColor: Colors.grey[800],
            inactiveTrackColor: Colors.grey[200],
            onChanged: (value) async {
              setState(() => _chatNotificationsEnabled = value);
              await _saveNotificationSettings();

              if (value) {
                await _requestChatNotificationsPermission();
              } else {
                await _disableChatNotifications();
              }
            },
          ),

          // NOTIFICHE DI SISTEMA
          SwitchListTile(
            secondary: const Icon(Icons.notifications, color: Color(0xFF0D47A1)),
            title: Text(
              'Notifiche di Sistema',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: _systemNotificationsEnabled,
            activeColor: const Color(0xFF0D47A1),
            activeTrackColor: Colors.grey[300],
            inactiveThumbColor: Colors.grey[800],
            inactiveTrackColor: Colors.grey[200],
            onChanged: (value) async {
              setState(() => _systemNotificationsEnabled = value);
              await _saveNotificationSettings();

              if (value) {
                await _requestSystemNotificationsPermission();
              } else {
                await _disableSystemNotifications();
              }
            },
          ),

          // SUONO NOTIFICHE
          SwitchListTile(
            secondary: const Icon(Icons.chat, color: Color(0xFF0D47A1)),
            title: Text(
              'Suono Notifiche',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: _notificationSoundEnabled,
            activeColor: const Color(0xFF0D47A1),
            activeTrackColor: Colors.grey[300],
            inactiveThumbColor: Colors.grey[800],
            inactiveTrackColor: Colors.grey[200],
            onChanged: (value) async {
              setState(() => _notificationSoundEnabled = value);
              await _saveNotificationSettings();

              if (value) {
                await _enableNotificationSound();
              } else {
                await _disableNotificationSound();
              }
            },
          ),

          // Aggiungi altri toggle o controlli se desideri
        ],
      ),
    );
  }
}
