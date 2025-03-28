import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/place_model.dart';
import '../../../services/altura_loader.dart';
import '../place_details_page.dart';

class FavoritesPage extends StatefulWidget {
  final List<String> placeIds;

  const FavoritesPage({super.key, required this.placeIds});

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

  /// Carica i documenti corrispondenti ai placeIds.
  /// Se la lista è vuota, evita la query whereIn (che genera errore)
  /// e restituisce Future.value(null).
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
    final theme = Theme.of(context);

    // Se la lista di placeIds è vuota, mostriamo subito un messaggio usando gli stili del tema.
    if (widget.placeIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          elevation: 0,
          title: Text(
            'Preferiti',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Text(
            'Nessun segnaposto preferito',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        title: Text(
          'Preferiti',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<QuerySnapshot?>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Errore di caricamento',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AlturaLoader());
          }
          // Se non sono stati trovati documenti
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Nessun segnaposto preferito',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final place = Place.fromFirestore(docs[i]);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  // Immagine con bordi arrotondati.
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
                  // Titolo: utilizza lo stile bodyLarge del tema (o simile) per il testo.
                  title: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  // Sottotitolo: descrizione del luogo.
                  subtitle: Text(
                    place.description ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  onTap: () {
                    // Naviga alla PlaceDetailsPage.
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlaceDetailsPage(place: place)),
                    ).then((_) {
                      // Al ritorno, ricarica la lista (utile se l'utente ha rimosso il preferito).
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
