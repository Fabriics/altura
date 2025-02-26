import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

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
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: true,
              onChanged: (value) {
                // Logica per notifiche email
              },
              title: Text('Notifiche via Email'),
              secondary: Icon(Icons.email, color: Color(0xFF0D47A1)),
            ),
            SwitchListTile(
              value: false,
              onChanged: (value) {
                // Logica per notifiche push
              },
              title: Text('Notifiche Push'),
              secondary: Icon(Icons.notifications, color: Color(0xFF0D47A1)),
            ),
            SwitchListTile(
              value: true,
              onChanged: (value) {
                // Logica per notifiche SMS
              },
              title: Text('Notifiche via SMS'),
              secondary: Icon(Icons.sms, color: Color(0xFF0D47A1)),
            ),
          ],
        ),
      ),
    );
  }
}
