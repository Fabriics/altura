import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Variabili per tenere traccia dello stato dei toggle
  bool _chatNotificationsEnabled = true;
  bool _systemNotificationsEnabled = true;
  bool _notificationSoundEnabled = true;

  @override
  void initState() {
    super.initState();
    // Carica le impostazioni salvate in SharedPreferences all'avvio della pagina
    _loadNotificationSettings();
  }

  /// Carica i valori salvati in SharedPreferences.
  /// Se non esistono, si usano i valori di default (true).
  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _chatNotificationsEnabled = prefs.getBool('chatNotifications') ?? true;
      _systemNotificationsEnabled = prefs.getBool('systemNotifications') ?? true;
      _notificationSoundEnabled = prefs.getBool('notificationSound') ?? true;
    });
  }

  /// Salva i valori correnti in SharedPreferences.
  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chatNotifications', _chatNotificationsEnabled);
    await prefs.setBool('systemNotifications', _systemNotificationsEnabled);
    await prefs.setBool('notificationSound', _notificationSoundEnabled);
  }

  // Funzioni placeholder per logiche personalizzate sulle notifiche

  /// Richiede i permessi/abilita le notifiche per la chat.
  Future<void> _requestChatNotificationsPermission() async {
    debugPrint('Richiesta permessi/abilitazione Chat Notifications...');
  }

  /// Disabilita le notifiche per la chat.
  Future<void> _disableChatNotifications() async {
    debugPrint('Chat Notifications disabilitate.');
  }

  /// Richiede i permessi/abilita le notifiche di sistema.
  Future<void> _requestSystemNotificationsPermission() async {
    debugPrint('Richiesta permessi/abilitazione System Notifications...');
  }

  /// Disabilita le notifiche di sistema.
  Future<void> _disableSystemNotifications() async {
    debugPrint('System Notifications disabilitate.');
  }

  /// Abilita il suono delle notifiche.
  Future<void> _enableNotificationSound() async {
    debugPrint('Suono notifiche abilitato.');
  }

  /// Disabilita il suono delle notifiche.
  Future<void> _disableNotificationSound() async {
    debugPrint('Suono notifiche disabilitato.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // L'AppBar utilizza il tema globale (appBarTheme) definito nel tuo app_theme.
      appBar: AppBar(
        title: const Text('Configura Notifiche'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // SWITCH PER LE NOTIFICHE CHAT
          SwitchListTile(
            // Icona secondaria: usa il colore primario dal tema (Blu profondo)
            secondary: Icon(
              Icons.mail,
              color: Theme.of(context).colorScheme.primary,
            ),
            // Titolo del toggle: utilizza lo stile bodyMedium del tema
            title: Text(
              'Notifiche Chat',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            // Stato attuale del toggle
            value: _chatNotificationsEnabled,
            // Colore del toggle attivo: usa il colore primario dal tema
            activeColor: Theme.of(context).colorScheme.primary,
            // Colori della track attiva e inattiva (qui si mantengono i valori standard)
            activeTrackColor: Colors.grey[300],
            inactiveThumbColor: Colors.grey[800],
            inactiveTrackColor: Colors.grey[200],
            onChanged: (value) async {
              setState(() => _chatNotificationsEnabled = value);
              await _saveNotificationSettings();
              // Esegui le azioni necessarie in base al nuovo valore
              if (value) {
                await _requestChatNotificationsPermission();
              } else {
                await _disableChatNotifications();
              }
            },
          ),

          // SWITCH PER LE NOTIFICHE DI SISTEMA
          SwitchListTile(
            // Icona secondaria: usa l'icona di notifiche con il colore primario
            secondary: Icon(
              Icons.notifications,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              'Notifiche di Sistema',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: _systemNotificationsEnabled,
            activeColor: Theme.of(context).colorScheme.primary,
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

          // SWITCH PER IL SUONO DELLE NOTIFICHE
          SwitchListTile(
            // Icona secondaria: usa l'icona (qui viene usata Icons.chat, ma puoi scegliere un'altra) con colore primario
            secondary: Icon(
              Icons.chat,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              'Suono Notifiche',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: _notificationSoundEnabled,
            activeColor: Theme.of(context).colorScheme.primary,
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

          // Aggiungi eventuali altri controlli o toggle se necessario
        ],
      ),
    );
  }
}
