import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Genera un chatId deterministico per una 1-to-1 chat (ordinando i due UID).
  String _generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  /// Crea o recupera la chat 1-to-1 tra l'utente corrente e [otherUid].
  /// Ritorna l'ID della chat (es: "uid1_uid2").
  Future<String> createOrGetChat(String otherUid) async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final chatId = _generateChatId(currentUid, otherUid);
    final docRef = _firestore.collection('chats').doc(chatId);

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      // Se la chat non esiste, la creiamo con i partecipanti
      await docRef.set({
        'participants': [currentUid, otherUid],
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  /// Invia un [text] come messaggio nella chat [chatId].
  /// Aggiorna anche lastMessage e updatedAt nel documento della chat.
  Future<void> sendMessage(String chatId, String text) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || text.trim().isEmpty) return;

    // Aggiunge il messaggio nella subcollection "messages"
    final messagesRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    await messagesRef.add({
      'senderId': currentUid,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Aggiorna lastMessage e updatedAt
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Restituisce uno stream di messaggi ordinati cronologicamente per la chat [chatId].
  Stream<QuerySnapshot> messagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Restituisce uno stream di tutte le chat (documenti in "chats")
  /// dove l'utente corrente partecipa (arrayContains: uid).
  /// Ordinate per updatedAt (descending).
  Stream<QuerySnapshot> userChatsStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Elimina l'intera chat con ID [chatId].
  /// Se vuoi rimuovere anche la subcollection "messages", lo fai in modo esplicito
  /// perché Firestore non fa "cascading delete" automatico.
  Future<void> deleteChat(String chatId) async {
    // Se vuoi rimuovere anche tutti i messaggi, puoi farlo prima di eliminare il doc.
    final messagesQuery = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    // Cancelliamo ogni messaggio nella subcollection "messages"
    for (final doc in messagesQuery.docs) {
      await doc.reference.delete();
    }

    // Infine, cancelliamo il documento principale della chat
    await _firestore.collection('chats').doc(chatId).delete();
  }
}
