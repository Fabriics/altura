import 'package:altura/services/chat_service.dart';
import 'package:altura/services/map_service.dart';
import 'package:altura/services/place_controller.dart';
import 'package:altura/views/home/chat/chat_page.dart';
import 'package:altura/views/home/profile/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';      // Import per CupertinoDialog
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // Import share_plus
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'package:timeago/timeago.dart' as timeago;
import '../../models/custom_category_marker.dart';
import '../../models/place_model.dart';
import '../../models/user_model.dart';

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
  String? _profileImageUrl;
  AppUser? _appUser;
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
      _fetchUser();
    }
    _checkFavorite();
  }

  Future<void> _fetchUser() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.place.userId)
          .get();
      if (doc.exists && doc.data() != null) {
        final userData = doc.data() as Map<String, dynamic>;
        setState(() {
          _appUser = AppUser.fromMap(userData);
          _username = _appUser?.username ?? 'Senza nome';
          _profileImageUrl = _appUser?.profileImageUrl ?? '';
        });
      }
    } catch (e) {
      debugPrint('Errore nel recuperare i dati utente: $e');
    }
  }

  Future<void> _checkFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final favs =
        (doc.data()?['favoritePlaces'] as List<dynamic>?)?.cast<String>() ?? [];
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
      MaterialPageRoute(builder: (context) => FullScreenMediaPage(mediaWidget: mediaWidget)),
    );
  }

  /// Dialog di conferma per aprire l'app di navigazione.
  Future<void> _showOpenMapsDialog(Place place) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Aprire Maps?"),
        content: const Text("Vuoi aprire l'app di navigazione?"),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Sì"),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            isDestructiveAction: true,
            child: const Text("No"),
          ),
        ],
      ),
    );
    if (result == true) {
      // Se l'utente accetta, apriamo il navigatore.
      _openDirections(place);
    }
  }

  /// Apre il navigatore esterno con indicazioni verso il segnaposto (Google Maps o l'app di default).
  Future<void> _openDirections(Place place) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}&travelmode=driving';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      debugPrint('Impossibile lanciare la URL delle indicazioni: $url');
    }
  }

  /// Condivide le informazioni del segnaposto (titolo + coordinate).
  /// Se ci sono file locali in mediaFiles, li includiamo nella condivisione.
  void _sharePlace(Place place) {
    final shareText = 'Guarda questo posto: ${place.name}\n'
        'Coordinate: ${place.latitude}, ${place.longitude}';

    // Se abbiamo file locali, li includiamo come XFile per condividerli.
    final List<XFile> xfiles = [];
    if (place.mediaFiles != null && place.mediaFiles!.isNotEmpty) {
      for (final file in place.mediaFiles!) {
        xfiles.add(XFile(file.path));
      }
    }

    if (xfiles.isNotEmpty) {
      Share.shareXFiles(xfiles, text: shareText, subject: place.name);
    } else {
      Share.share(shareText, subject: place.name);
    }
  }

  /// Costruisce il media carousel con overlay.
  Widget _buildMediaCarousel(Place place) {
    Widget mediaWidget;
    if (place.mediaFiles?.isNotEmpty ?? false) {
      mediaWidget = PageView.builder(
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
    } else if (place.mediaUrls?.isNotEmpty ?? false) {
      mediaWidget = PageView.builder(
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
    } else {
      mediaWidget = Container(
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.image_not_supported, size: 50)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SizedBox(
            height: 280,
            width: double.infinity,
            child: mediaWidget,
          ),
          // Overlay in basso a sinistra: icona categoria e, se richiesto, lock.
          Positioned(
            bottom: 8,
            left: 8,
            child: Row(
              children: [
                CustomCategoryMarker(category: widget.place.category),
                if (widget.place.requiresPermission)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.lock, color: Colors.white, size: 20),
                  ),
              ],
            ),
          ),
          // Overlay in basso a destra: icona dei like e conteggio.
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.place.likeCount ?? 0}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('places').doc(widget.place.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data?.data() == null) {
          // Se il documento è stato eliminato, chiudi la pagina dopo pochi istanti.
          Navigator.of(context).pop();
          return const Scaffold(
            body: Center(child: Text("Il segnaposto non è più disponibile.")),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final updatedPlace = Place.fromMap(snapshot.data!.id, data);
        final relativeTime = updatedPlace.createdAt != null
            ? timeago.format(updatedPlace.createdAt!)
            : '';

        return Scaffold(
          appBar: AppBar(
            title: const Text("Segnaposto"),
            actions: [
              if (updatedPlace.userId == FirebaseAuth.instance.currentUser?.uid)
                IconButton(
                  icon: Icon(Icons.edit, color: theme.colorScheme.onPrimary),
                  onPressed: () async {
                    await _mapService.editPlace(place: updatedPlace, context: context);
                  },
                ),
            ],
          ),
          backgroundColor: Colors.white,

          /// Definiamo un container *fisso* in fondo alla pagina con i due pulsanti.
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Primo pulsante: Indicazioni (mostra un cupertino dialog di conferma)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showOpenMapsDialog(updatedPlace),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Indicazioni'),
                ),
                // Secondo pulsante: Condividi
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _sharePlace(updatedPlace),
                  icon: const Icon(Icons.share),
                  label: const Text('Condividi'),
                ),
              ],
            ),
          ),

          /// Corpo della pagina
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMediaCarousel(updatedPlace),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                            ? NetworkImage(_profileImageUrl!)
                            : null,
                        child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                            ? Text(
                          _username.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          if (_appUser != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProfilePage(user: _appUser!)),
                            );
                          }
                        },
                        child: Column(
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
                    updatedPlace.name,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (updatedPlace.description?.isNotEmpty ?? false)
                    Text(
                      updatedPlace.description!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  const SizedBox(height: 16),
                  // Indirizzo: latitudine e longitudine
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${updatedPlace.latitude.toStringAsFixed(5)}, '
                              '${updatedPlace.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Se il segnaposto ha autorizzazione, mostra icona e dettagli
                  if (updatedPlace.requiresPermission)
                    Row(
                      children: [
                        const Icon(Icons.lock, size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            updatedPlace.permissionDetails ?? "Autorizzazione richiesta",
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(child: mediaWidget),
    );
  }
}
