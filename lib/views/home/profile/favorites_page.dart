import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/place_model.dart';
import '../place_details_page.dart';

class FavoritesPage extends StatefulWidget {
  final List<String> placeIds;

  const FavoritesPage({Key? key, required this.placeIds}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<QuerySnapshot?> _placesFuture;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  /// Carica i documenti corrispondenti ai placeIds. Se la lista è vuota,
  /// evitiamo la query whereIn (che genera errore) e restituiamo Future.value(null).
  void _loadPlaces() {
    if (widget.placeIds.isEmpty) {
      _placesFuture = Future.value(null);
    } else {
      _placesFuture = FirebaseFirestore.instance
          .collection('places')
          .where(FieldPath.documentId, whereIn: widget.placeIds)
          .get();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se placeIds è vuota, mostriamo subito un messaggio
    if (widget.placeIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF02398E),
          elevation: 0,
          title: Text(
            'Preferiti',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('Nessun segnaposto preferito')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        elevation: 0,
        title: const Text(
          'Preferiti',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<QuerySnapshot?>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Errore di caricamento'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Se _placesFuture == null oppure la query non ha trovato documenti
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nessun segnaposto preferito'));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final place = Place.fromFirestore(docs[i]);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  // Immagine con bordi arrotondati
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (place.mediaUrls?.isNotEmpty == true)
                        ? Image.network(
                      place.mediaUrls!.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[300],
                      child: const Icon(Icons.photo, color: Colors.white70),
                    ),
                  ),
                  // Titolo in nero
                  title: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black),
                  ),
                  // Descrizione in nero
                  subtitle: Text(
                    place.description ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    // Apriamo PlaceDetailsPage
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlaceDetailsPage(place: place)),
                    ).then((_) {
                      // Al ritorno, se l’utente ha tolto il cuore,
                      // ricarichiamo la lista e ricostruiamo
                      _loadPlaces();
                      setState(() {});
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
