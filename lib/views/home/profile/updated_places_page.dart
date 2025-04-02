
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/place_model.dart';
import '../../../services/altura_loader.dart';
import '../../../services/map_service.dart';
import '../../../services/place_controller.dart';

/// Pagina che mostra la lista dei segnaposti caricati dall'utente corrente.
/// Permette di modificarli o eliminarli, delegando la logica al MapService.
class UploadedPlacesPage extends StatefulWidget {
  final List<String> uploadedPlaceIds;

  /// [uploadedPlaceIds] è la lista degli ID dei segnaposti caricati dall'utente.
  const UploadedPlacesPage({super.key, required this.uploadedPlaceIds});

  @override
  State<UploadedPlacesPage> createState() => _UploadedPlacesPageState();
}

class _UploadedPlacesPageState extends State<UploadedPlacesPage> {
  /// Future che carica i segnaposti corrispondenti agli ID in [widget.uploadedPlaceIds].
  late Future<QuerySnapshot?> _placesFuture;

  /// Istanza del MapService, che include la logica di modifica ed eliminazione.
  late final MapService _mapService;

  /// Istanza del PlacesController, utilizzata dal MapService.
  late final PlacesController _placesController;

  @override
  void initState() {
    super.initState();
    // Inizializza il PlacesController e il MapService.
    _placesController = PlacesController();
    _mapService = MapService(placesController: _placesController);
    _loadPlaces();
  }

  /// Carica i documenti della collezione "places" i cui ID sono in [widget.uploadedPlaceIds].
  /// Se la lista è vuota, evita la query whereIn e restituisce Future.value(null).
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

    // Se non ci sono ID, mostriamo subito un messaggio.
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
        title: const Text('I miei segnaposti'),
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
              // Costruisce l’oggetto Place dal documento Firestore.
              final place = Place.fromFirestore(docs[i]);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Immagine del segnaposto o placeholder.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: (place.mediaUrls != null && place.mediaUrls!.isNotEmpty)
                            ? Image.network(
                          place.mediaUrls!.first,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Informazioni principali: nome, descrizione e data.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (place.description != null && place.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  place.description!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (place.createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Caricato ${timeago.format(place.createdAt!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Icone per modifica ed eliminazione.
                      Column(
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

  /// Delega la modifica del segnaposto al MapService.
  Future<void> _editPlace(Place place) async {
    await _mapService.editPlace(place: place, context: context);
    _loadPlaces();
    setState(() {});
  }

  /// Delega l'eliminazione del segnaposto al MapService e ricarica i dati.
  Future<void> _deletePlace(Place place) async {
    await _mapService.deletePlace(place: place, context: context);
    _loadPlaces();
    setState(() {});
  }
}
