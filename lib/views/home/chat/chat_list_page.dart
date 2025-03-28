import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:altura/services/chat_service.dart';
import '../../../services/altura_loader.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final chatService = ChatService();

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Devi essere loggato per vedere le chat')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Le mie chat',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatService.userChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Stream error: ${snapshot.error}');
            return const Center(child: Text('Errore caricamento chat'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AlturaLoader());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Non hai conversazioni attive'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final chatDoc = docs[i];
              final data = chatDoc.data() as Map<String, dynamic>;
              final participants = List<String>.from(data['participants'] ?? []);
              final otherUid = participants.firstWhere((uid) => uid != currentUser.uid, orElse: () => '');
              final lastMessage = data['lastMessage'] as String? ?? '';
              final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
                builder: (ctx, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(title: Text('Caricamento...'));
                  }
                  if (!userSnap.data!.exists) {
                    return const ListTile(title: Text('Utente non trovato'));
                  }

                  final userData = userSnap.data!.data() as Map<String, dynamic>;
                  final username = userData['username'] as String? ?? 'Utente';
                  final photoUrl = userData['profileImageUrl'] as String? ?? '';

                  // Creiamo la parte finale (trailing) con l’orario e l’icona delete
                  Widget? trailingWidget;
                  if (updatedAt != null) {
                    trailingWidget = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mostriamo l’orario (HH:MM)
                        Text(
                          '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        // Icona per eliminare la chat
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Elimina Chat'),
                                content: Text('Eliminare la chat con $username?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Annulla'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Elimina', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              // Elimina la chat
                              await chatService.deleteChat(chatDoc.id);
                            }
                          },
                        ),
                      ],
                    );
                  } else {
                    // Se non c'è updatedAt, mostriamo solo l'icona di delete
                    trailingWidget = IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Elimina Chat'),
                            content: Text('Eliminare la chat con $username?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annulla'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Elimina', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await chatService.deleteChat(chatDoc.id);
                        }
                      },
                    );
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/placeholder.png') as ImageProvider,
                      backgroundColor: Colors.grey[300],
                    ),
                    title: Text(
                      username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      lastMessage.isNotEmpty ? lastMessage : 'Nessun messaggio...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: trailingWidget,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatPage(chatId: chatDoc.id)),
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
