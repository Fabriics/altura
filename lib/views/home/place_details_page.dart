import 'package:altura/services/chat_service.dart';
import 'package:altura/services/map_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/place_model.dart';
import '../../services/place_controller.dart';
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
  String? _profileImageUrl; // Variabile per l'immagine del profilo
  bool _isFavorite = false;
  late final MapService _mapService;
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _mapService = MapService(placesController: PlacesController());
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
        setState(() {
          _username = doc.data()!['username'] ?? 'Senza nome';
          _profileImageUrl = doc.data()!['profileImageUrl'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Errore nel recuperare il nome utente: $e');
    }
  }

  Future<void> _checkFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Devi essere loggato')));
      return;
    }
    final otherUid = widget.place.userId;
    final chatId = await _chatService.createOrGetChat(otherUid);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(chatId: chatId)),
    );
  }

  void _openFullScreenMedia({required Widget mediaWidget}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMediaPage(mediaWidget: mediaWidget),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isOwner =
        widget.place.userId == FirebaseAuth.instance.currentUser?.uid;
    final relativeTime = widget.place.createdAt != null
        ? timeago.format(widget.place.createdAt!)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Segnaposto"),
        actions: [
          // Se l'utente è proprietario, mostra il pulsante per modificare il segnaposto.
          if (isOwner)
            IconButton(
              icon: Icon(
                Icons.edit,
                color: theme.colorScheme.onPrimary,
              ),
              onPressed: () async {
                await _mapService.editPlace(place: widget.place, context: context);
                setState(() {});
              },
            ),
        ],
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: !isOwner
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Contatta utente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF02398E),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _contactUser,
          ),
        ),
      )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media carousel
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: _buildMediaCarousel(widget.place),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Visualizza l'immagine del profilo se esiste, altrimenti un placeholder.
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: (_profileImageUrl != null &&
                        _profileImageUrl!.isNotEmpty)
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: (_profileImageUrl == null ||
                        _profileImageUrl!.isEmpty)
                        ? Icon(Icons.person,
                        size: 60, color: theme.colorScheme.onSurface)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _username,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (relativeTime.isNotEmpty)
                        Text(
                          'Pubblicato $relativeTime',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.redAccent : Colors.grey,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.place.name,
                style:
                theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (widget.place.description?.isNotEmpty ?? false)
                Text(
                  widget.place.description!,
                  style: theme.textTheme.bodyLarge,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.place.latitude.toStringAsFixed(5)}, ${widget.place.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCarousel(Place place) {
    if (place.mediaFiles?.isNotEmpty ?? false) {
      return PageView.builder(
        itemCount: place.mediaFiles!.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _openFullScreenMedia(
            mediaWidget: Image.file(
              place.mediaFiles![i],
              fit: BoxFit.cover,
            ),
          ),
          child: Image.file(
            place.mediaFiles![i],
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (place.mediaUrls?.isNotEmpty ?? false) {
      return PageView.builder(
        itemCount: place.mediaUrls!.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _openFullScreenMedia(
            mediaWidget: Image.network(
              place.mediaUrls![i],
              fit: BoxFit.cover,
            ),
          ),
          child: Image.network(
            place.mediaUrls![i],
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 50),
      ),
    );
  }
}

class FullScreenMediaPage extends StatelessWidget {
  final Widget mediaWidget;

  const FullScreenMediaPage({super.key, required this.mediaWidget});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Center(child: mediaWidget),
    );
  }
}
