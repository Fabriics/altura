// lib/views/chat_page.dart

import 'package:flutter/material.dart';

/// Pagina di esempio per la chat, con storico dei messaggi e contatti.
class ChatPage extends StatelessWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: const Center(
        child: Text(
          'Qui potrai visualizzare e gestire le tue chat con altri piloti.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
