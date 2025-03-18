import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/place.dart';

/// Pagina che mostra in dettaglio un segnaposto a schermo intero,
/// con card che riempie l'area fino al pulsante "Contact user" in fondo,
/// descrizione scrollabile e media non tagliati.
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

  @override
  void initState() {
    super.initState();
    // Se lo username non è passato esplicitamente, lo recuperiamo da Firestore
    if (widget.username != null) {
      _username = widget.username!;
    } else {
      _fetchUsername();
    }
  }

  /// Recupera lo username dal DB, se non fornito direttamente.
  Future<void> _fetchUsername() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.place.userId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && mounted) {
          setState(() {
            _username = data['username'] ?? 'Senza nome';
          });
        }
      }
    } catch (e) {
      debugPrint('Errore nel recuperare il nome utente: $e');
    }
  }

  /// Torna alla mappa
  void _goToMap() {
    Navigator.pop(context, {
      'lat': widget.place.latitude,
      'lng': widget.place.longitude,
    });
  }

  /// Placeholder per contattare l'utente
  void _contactUser() {
    debugPrint('Contatta utente con ID: ${widget.place.userId}');
  }

  @override
  Widget build(BuildContext context) {
    // Data/ora relativa del post (opzionale)
    final relativeTime = widget.place.createdAt != null
        ? timeago.format(widget.place.createdAt!)
        : '';

    // Se l'utente è proprietario del post
    final bool isOwner =
        widget.place.userId == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      // Pulsante in fondo allo schermo
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _contactUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Contact user',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ),

      // Contenuto principale
      body: SafeArea(
        child: Column(
          children: [
            // 1) La card occupa tutto lo spazio verticale fino al pulsante
            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // 2) Media con bordi arrotondati (sia sopra che sotto)
                      //    e BoxFit.contain per non tagliare.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 350,
                              width: double.infinity,
                              child: _buildMediaCarousel(widget.place),
                            ),
                            // Opzioni se l'utente è proprietario
                            if (isOwner)
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.white),
                                      onPressed: () {
                                        debugPrint('Modifica post');
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.white),
                                      onPressed: () {
                                        debugPrint('Elimina post');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            // Icona preferiti + "Show map"
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.favorite_border,
                                        color: Colors.red),
                                    onPressed: () {
                                      debugPrint('Aggiunto ai preferiti');
                                    },
                                  ),
                                  GestureDetector(
                                    onTap: _goToMap,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                            Colors.black,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Show map',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3) Contenuto testuale: scrollabile
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titolo
                              Text(
                                widget.place.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Placeholder recensioni
                              Row(
                                children: const [
                                  Icon(Icons.star, color: Colors.orangeAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    '4.5 (355 Reviews)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Data di creazione (se presente)
                              if (relativeTime.isNotEmpty)
                                Text(
                                  'Caricato $relativeTime',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              const SizedBox(height: 16),

                              // Descrizione completa, senza "read more"
                              if (widget.place.description != null &&
                                  widget.place.description!.isNotEmpty)
                                Text(
                                  widget.place.description!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carousel dei media con BoxFit.contain per NON tagliare l’immagine/video
  /// e bordi arrotondati definiti dal ClipRRect esterno.
  Widget _buildMediaCarousel(Place place) {
    if (place.mediaFiles != null && place.mediaFiles!.isNotEmpty) {
      return PageView.builder(
        itemCount: place.mediaFiles!.length,
        itemBuilder: (context, index) {
          return Image.file(
            place.mediaFiles![index],
            fit: BoxFit.contain, // Non taglia il contenuto
          );
        },
      );
    } else if (place.mediaUrls != null && place.mediaUrls!.isNotEmpty) {
      return PageView.builder(
        itemCount: place.mediaUrls!.length,
        itemBuilder: (context, index) {
          return Image.network(
            place.mediaUrls![index],
            fit: BoxFit.contain, // Non taglia il contenuto
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
}
