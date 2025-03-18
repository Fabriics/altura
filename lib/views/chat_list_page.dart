import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart'; // La ChatPage definita in precedenza

/// Pagina che elenca le chat disponibili per l'utente corrente.
/// Mostra un elenco di conversazioni (chat) con l'ultimo messaggio, ecc.
class ChatListPage extends StatelessWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Se non c'è alcun utente loggato, mostriamo un messaggio o rimandiamo al login
      return const Scaffold(
        body: Center(
          child: Text('Nessun utente loggato.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Le mie Chat'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Mostriamo solo le chat dove participants contiene l'uid dell'utente
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Errore di connessione.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Non ci sono chat attive.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chatDoc = docs[index];
              final data = chatDoc.data() as Map<String, dynamic>;

              final chatId = chatDoc.id;
              final lastMessage = data['lastMessage'] as String? ?? '';
              final updatedAt = data['updatedAt'] as Timestamp?;
              // final date = updatedAt?.toDate() ?? DateTime.now();

              // Se hai un "chatName" o vuoi ricavare il nome dell'altro partecipante,
              // puoi farlo qui. Altrimenti mostriamo un generico "Chat".
              final chatTitle = data['chatName'] as String? ?? 'Chat';

              return ListTile(
                title: Text(chatTitle),
                subtitle: Text(
                  lastMessage.isNotEmpty ? lastMessage : 'Nessun messaggio...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  // Naviga alla ChatPage con chatId
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ChatPage(chatId: chatId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
