import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/place_model.dart';
import '../../../services/places_service.dart';
import '../edit/edit_place_page.dart';


/// Pagina che mostra la lista dei segnaposti caricati dall'utente corrente.
/// Permette di modificarli o eliminarli, simile a come fa "HomePage".
class UploadedPlacesPage extends StatefulWidget {
  final List<String> uploadedPlaceIds;

  /// [uploadedPlaceIds] è la lista degli ID dei segnaposti caricati dall'utente.
  const UploadedPlacesPage({super.key, required this.uploadedPlaceIds});

  @override
  State<UploadedPlacesPage> createState() => _UploadedPlacesPageState();
}

class _UploadedPlacesPageState extends State<UploadedPlacesPage> {
  /// Service per operazioni di modifica/eliminazione segnaposti
  final PlacesController _placesController = PlacesController();

  /// Future che carica i segnaposti corrispondenti agli ID in [widget.uploadedPlaceIds]
  late Future<QuerySnapshot?> _placesFuture;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  /// Carica i documenti della collezione "places" i cui ID sono in [widget.uploadedPlaceIds].
  void _loadPlaces() {
    if (widget.uploadedPlaceIds.isEmpty) {
      // Se la lista è vuota, restituiamo Future.value(null) per evitare errori "whereIn"
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
    // Se non ci sono ID, mostriamo subito un messaggio
    if (widget.uploadedPlaceIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF02398E),
          elevation: 0,
          title: Text(
            'I miei segnaposti',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('Non hai caricato alcun segnaposto')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        elevation: 0,
        title: Text(
          'I miei segnaposti',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
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

          // Se future = null o la query non ha trovato documenti
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Non hai caricato alcun segnaposto'));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final place = Place.fromFirestore(docs[i]);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Immagine con bordi arrotondati
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
                      // Colonna con titolo, descrizione e bottoni
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titolo
                            Text(
                              place.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Descrizione
                            if (place.description != null && place.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  place.description!,
                                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            // Data caricamento (timeago)
                            if (place.createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Caricato ${timeago.format(place.createdAt!)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            // Bottoni Edit / Delete
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                  onPressed: () => _editPlace(place),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
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

  /// Apre la pagina di modifica (EditPlacePage). Al ritorno, se c'è un result, aggiorna i dati
  Future<void> _editPlace(Place place) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPlacePage(place: place)),
    );

    // Se l'utente ha annullato o non è tornato nulla, interrompi
    if (result == null || result is! Map<String, dynamic>) return;

    final newCategory = result['category'] as String;
    final newTitle = result['title'] as String? ?? '';
    final newDescription = result['description'] as String? ?? '';
    final newMediaFiles = result['media'] as List<File>? ?? [];

    // Esegui l'aggiornamento con il tuo PlacesController
    await _placesController.updatePlace(
      placeId: place.id,
      userId: place.userId,
      newTitle: newTitle,
      newDescription: newDescription,
      newCategory: newCategory,
      newMediaFiles: newMediaFiles,
    );

    // Ricarica la lista
    _loadPlaces();
    setState(() {});
  }

  /// Conferma e cancella il segnaposto
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
      // Ricarichiamo la lista
      _loadPlaces();
      // 1) Rimuovi il documento da 'places'
      await FirebaseFirestore.instance
          .collection('places')
          .doc(place.id)
          .delete();

      // 2) Rimuovi l'ID dall'array "uploadedPlaces" del documento utente
      await FirebaseFirestore.instance
          .collection('users')
          .doc(place.userId)
          .update({
        'uploadedPlaces': FieldValue.arrayRemove([place.id]),
      });
      setState(() {});
    }
  }
}
