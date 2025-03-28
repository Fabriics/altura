import 'package:altura/services/altura_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String chatId;

  const ChatPage({super.key, required this.chatId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Invia il messaggio, se non vuoto, e scrolla verso il basso
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _chatService.sendMessage(widget.chatId, text);
    _messageController.clear();
    _scrollToBottom();
  }

  /// Esegue uno scroll verso il fondo della lista dei messaggi
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar che utilizza il colore primario definito nel tema (blu profondo)
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'Chat',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Sezione messaggi: usa StreamBuilder per aggiornamenti in tempo reale
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.messagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Errore di connessione'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AlturaLoader());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Nessun messaggio ancora'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    // Ottiene i dati del messaggio
                    final data = docs[i].data()! as Map<String, dynamic>;
                    // Determina se il messaggio è stato inviato dall'utente corrente
                    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    return _MessageBubble(
                      text: data['text'] ?? '',
                      isMe: isMe,
                      time: timestamp,
                    );
                  },
                );
              },
            ),
          ),
          // Sezione di invio messaggi
          Container(
            // Usa il fillColor definito nell'inputDecorationTheme del tema
            color: Theme.of(context).inputDecorationTheme.fillColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Scrivi un messaggio...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                // Icona per l'invio del messaggio con il colore primario del tema
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget per visualizzare ogni messaggio in un "bubble"
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime? time;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    // Usa il colore primario per i messaggi inviati dall'utente, altrimenti un grigio chiaro
    final bgColor = isMe ? Theme.of(context).colorScheme.primary : Colors.grey[300];
    // Imposta il colore del testo in base al background: bianco se è un messaggio dell'utente, altrimenti nero
    final textColor = isMe ? Theme.of(context).colorScheme.onPrimary : Colors.black87;
    // Allineamento differente per i messaggi inviati e ricevuti
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: TextStyle(color: textColor),
            ),
          ),
          // Visualizza l'orario se disponibile
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }
}
