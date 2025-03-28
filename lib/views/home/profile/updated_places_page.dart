import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/place_model.dart';
import '../../../services/altura_loader.dart';
import '../../../services/places_service.dart';
import '../edit/edit_place_page.dart';

/// Pagina che mostra la lista dei segnaposti caricati dall'utente corrente.
/// Permette di modificarli o eliminarli, in modo simile a quanto avviene in HomePage.
class UploadedPlacesPage extends StatefulWidget {
  final List<String> uploadedPlaceIds;

  /// [uploadedPlaceIds] è la lista degli ID dei segnaposti caricati dall'utente.
  const UploadedPlacesPage({super.key, required this.uploadedPlaceIds});

  @override
  State<UploadedPlacesPage> createState() => _UploadedPlacesPageState();
}

class _UploadedPlacesPageState extends State<UploadedPlacesPage> {
  /// Controller per operazioni di modifica/eliminazione segnaposti.
  final PlacesController _placesController = PlacesController();

  /// Future che carica i segnaposti corrispondenti agli ID in [widget.uploadedPlaceIds].
  late Future<QuerySnapshot?> _placesFuture;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  /// Carica i documenti della collezione "places" i cui ID sono in [widget.uploadedPlaceIds].
  /// Se la lista è vuota, evita la query whereIn (che genera errore) e restituisce Future.value(null).
  void _loadPlaces() {
    if (widget.uploadedPlaceIds.isEmpty) {
      _placesFuture = Future.value(null);
    } else {
      _placesFuture = FirebaseFirestore.instance
          .collection('places')
          .where(FieldPath.documentId, whereIn: widget.uploadedPlaceIds)
          .get();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Se non ci sono ID, mostriamo subito un messaggio centrato, usando gli stili del tema.
    if (widget.uploadedPlaceIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          elevation: 0,
          title: Text(
            'I miei segnaposti',
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
            'Non hai caricato alcun segnaposto',
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
          'I miei segnaposti',
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
          // Se la query non restituisce documenti, mostriamo un messaggio.
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Non hai caricato alcun segnaposto',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              // Costruiamo il modello Place a partire dal documento Firestore.
              final place = Place.fromFirestore(docs[i]);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Immagine del segnaposto con bordi arrotondati.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: (place.mediaUrls != null && place.mediaUrls!.isNotEmpty)
                            ? Image.network(
                          place.mediaUrls!.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.photo, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Colonna con titolo, descrizione, data e bottoni.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titolo del segnaposto.
                            Text(
                              place.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Descrizione, se presente.
                            if (place.description != null && place.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  place.description!,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            // Data di caricamento, formattata con timeago.
                            if (place.createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Caricato ${timeago.format(place.createdAt!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                ),
                              ),
                            // Bottoni per modificare ed eliminare il segnaposto.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                                  onPressed: () => _editPlace(place),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: theme.colorScheme.error),
                                  onPressed: () => _deletePlace(place),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Apre la pagina di modifica (EditPlacePage). Al ritorno, se ci sono aggiornamenti, ricarica i segnaposti.
  Future<void> _editPlace(Place place) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPlacePage(place: place)),
    );
    if (result == null || result is! Map<String, dynamic>) return;
    final newCategory = result['category'] as String;
    final newTitle = result['title'] as String? ?? '';
    final newDescription = result['description'] as String? ?? '';
    final newMediaFiles = result['media'] as List<File>? ?? [];
    await _placesController.updatePlace(
      placeId: place.id,
      userId: place.userId,
      newTitle: newTitle,
      newDescription: newDescription,
      newCategory: newCategory,
      newMediaFiles: newMediaFiles,
    );
    _loadPlaces();
    setState(() {});
  }

  /// Mostra un dialog per confermare l'eliminazione e, se confermato, elimina il segnaposto.
  Future<void> _deletePlace(Place place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Eliminare il segnaposto "${place.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _placesController.deletePlace(place.id);
      // Rimuove il documento dal database
      await FirebaseFirestore.instance.collection('places').doc(place.id).delete();
      // Aggiorna l'array "uploadedPlaces" del documento utente rimuovendo l'ID
      await FirebaseFirestore.instance.collection('users').doc(place.userId).update({
        'uploadedPlaces': FieldValue.arrayRemove([place.id]),
      });
      setState(() {});
    }
  }
}
