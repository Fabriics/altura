import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/place.dart';

/// Pagina che mostra in dettaglio un segnaposto.
class PlaceDetailsPage extends StatefulWidget {
  final Place place;
  final String? username;

  const PlaceDetailsPage({
    Key? key,
    required this.place,
    this.username,
  }) : super(key: key);

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  String _username = 'Sconosciuto';

  @override
  void initState() {
    super.initState();
    if (widget.username != null) {
      _username = widget.username!;
    } else {
      _fetchUsername();
    }
  }

  Future<void> _fetchUsername() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.place.userId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _username = data['username'] ?? 'Senza nome';
          });
        }
      }
    } catch (e) {
      debugPrint('Errore nel recuperare il nome utente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    String relativeTime = '';
    if (widget.place.createdAt != null) {
      relativeTime = timeago.format(widget.place.createdAt!);
    }
    bool isOwner = widget.place.userId == FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name),
        actions: isOwner
            ? [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Logica per modificare il post
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // Logica per eliminare il post
            },
          ),
        ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carousel dei media
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[300],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildMediaCarousel(widget.place),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildCategoryIcon(widget.place.category),
                const SizedBox(width: 8),
                Text(
                  widget.place.category,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.place.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/profile_page', arguments: widget.place.userId);
              },
              child: Text(
                'Pubblicato da $_username',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (relativeTime.isNotEmpty)
              Text(
                'Caricato $relativeTime',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            if (widget.place.description != null && widget.place.description!.isNotEmpty)
              Text(
                widget.place.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${widget.place.latitude.toStringAsFixed(5)}, ${widget.place.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Visualizza i media in un carousel (PageView).
  Widget _buildMediaCarousel(Place place) {
    if (place.mediaFiles != null && place.mediaFiles!.isNotEmpty) {
      return PageView.builder(
        itemCount: place.mediaFiles!.length,
        itemBuilder: (context, index) {
          return Image.file(
            place.mediaFiles![index],
            fit: BoxFit.cover,
          );
        },
      );
    } else if (place.mediaUrls != null && place.mediaUrls!.isNotEmpty) {
      return PageView.builder(
        itemCount: place.mediaUrls!.length,
        itemBuilder: (context, index) {
          return Image.network(
            place.mediaUrls![index],
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        ),
      );
    }
  }

  /// Restituisce l'icona corrispondente alla categoria.
  Widget _buildCategoryIcon(String category) {
    switch (category) {
      case 'pista_decollo':
        return const Icon(Icons.flight_takeoff, color: Colors.red);
      case 'area_volo_libera':
        return const Icon(Icons.flight, color: Colors.green);
      case 'area_restrizioni':
        return const Icon(Icons.block, color: Colors.orange);
      case 'punto_ricarica':
        return const Icon(Icons.battery_full, color: Colors.blue);
      default:
        return const Icon(Icons.place, color: Colors.grey);
    }
  }
}
