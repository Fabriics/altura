

import 'package:altura/services/places_service.dart';
import 'package:altura/services/chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/place_model.dart';
import 'edit/edit_place_page.dart';
import 'chat/chat_page.dart';

class PlaceDetailsPage extends StatefulWidget {
  final Place place;
  final String? username;

  const PlaceDetailsPage({
    super.key,
    required this.place,
    this.username,
  });

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  String _username = 'Sconosciuto';
  bool _isFavorite = false;
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    if (widget.username != null) {
      _username = widget.username!;
    } else {
      _fetchUsername();
    }
    _checkFavorite();
  }

  Future<void> _fetchUsername() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.place.userId)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() => _username = doc.data()!['username'] ?? 'Senza nome');
      }
    } catch (e) {
      debugPrint('Errore nel recuperare il nome utente: $e');
    }
  }

  Future<void> _checkFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final favs = (doc.data()?['favoritePlaces'] as List<dynamic>?)?.cast<String>() ?? [];
    setState(() => _isFavorite = favs.contains(widget.place.id));
  }

  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    if (_isFavorite) {
      await ref.update({'favoritePlaces': FieldValue.arrayRemove([widget.place.id])});
    } else {
      await ref.update({'favoritePlaces': FieldValue.arrayUnion([widget.place.id])});
    }
    setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _contactUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devi essere loggato')));
      return;
    }
    final otherUid = widget.place.userId;
    final chatId = await _chatService.createOrGetChat(otherUid);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(chatId: chatId)));
    }

  Future<void> _deletePlace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Eliminare il segnaposto "${widget.place.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await PlacesController().deletePlace(widget.place.id);
      Navigator.pop(context);
    }
  }

  void _goToMap() {
    Navigator.pop(context, {'lat': widget.place.latitude, 'lng': widget.place.longitude});
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.place.userId == FirebaseAuth.instance.currentUser?.uid;
    final relativeTime = widget.place.createdAt != null ? timeago.format(widget.place.createdAt!) : '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        title: Text(
          'Segnaposto',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Contatta utente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF02398E),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _contactUser,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 250,
                        width: double.infinity,
                        child: _buildMediaCarousel(widget.place),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, size: 30, color: _isFavorite ? Colors.redAccent : Colors.white),
                        onPressed: _toggleFavorite,
                      ),
                    ),
                    if (isOwner)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Row(
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPlacePage(place: widget.place))).then((_) => setState(() {}))),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _deletePlace),
                          ],
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.place.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Pubblicato da $_username', style: Theme.of(context).textTheme.bodyMedium),
                      if (relativeTime.isNotEmpty) Text('Caricato $relativeTime', style: Theme.of(context).textTheme.bodySmall),
                      const Divider(height: 32),
                      if (widget.place.description?.isNotEmpty ?? false)
                        Text(widget.place.description!, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${widget.place.latitude.toStringAsFixed(5)}, ${widget.place.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCarousel(Place place) {
    if ((place.mediaFiles?.isNotEmpty ?? false)) {
      return PageView.builder(
        itemCount: place.mediaFiles!.length,
        itemBuilder: (_, i) => Image.file(place.mediaFiles![i], fit: BoxFit.contain),
      );
    }
    if ((place.mediaUrls?.isNotEmpty ?? false)) {
      return PageView.builder(
        itemCount: place.mediaUrls!.length,
        itemBuilder: (_, i) => Image.network(place.mediaUrls![i], fit: BoxFit.contain),
      );
    }
    return Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.image_not_supported, size: 50)));
  }
}
