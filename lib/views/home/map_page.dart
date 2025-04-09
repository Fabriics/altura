import 'dart:io';
import 'package:altura/views/home/place_details_page.dart';
import 'package:altura/services/add_place_service.dart'; // Importa la nuova pagina
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/place_category.dart';
import '../../models/place_model.dart';
import '../../services/altura_loader.dart';
import '../../services/map_service.dart';
import '../../services/place_controller.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  late final MapService _mapService;
  late final PlacesController _placesController;

  bool _selectingPosition = false;
  Place? _selectedPlace;
  String _selectedUsername = 'Sconosciuto';
  int _selectedLikeCount = 0;
  String? _selectedProfileImageUrl;
  LatLng? _tempSelectedPosition;

  // Lista di filtri (categorie) attive
  List<PlaceCategory> _selectedFilterCategories = [];
  String? selectedCategory; // (non più utilizzato per lo step)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placesController = PlacesController();
    _mapService = MapService(placesController: _placesController);
    _mapService.initLocation(context: context);
    _initUser();
  }

  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Nessun utente loggato');
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          // Aggiorna il modello utente se necessario
        });
      }
    } catch (e) {
      debugPrint('Errore nell\'inizializzazione utente: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _mapService.initLocation(context: context);
    }
  }

  /// Gestisce l'aggiunta del marker in modalità "selezione".
  /// Invece di aprire un bottom sheet, naviga verso la pagina AddPlaceService.
  Future<void> _handleAddPlace(LatLng position) async {
    // Imposta una posizione temporanea (se vuoi visualizzare un marker in attesa)
    setState(() {
      _tempSelectedPosition = position;
    });

    // Avvia la pagina per aggiungere il segnaposto e attendi il risultato
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPlaceService(latLng: position)),
    );

    // Se viene restituito un risultato, procedi con la creazione del segnaposto
    if (result != null) {
      debugPrint('Risultato dal nuovo segnaposto: $result');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Crea un nuovo oggetto Place utilizzando i dati restituiti dalla pagina
        final newPlace = await _placesController.addPlace(
          latitude: position.latitude,
          longitude: position.longitude,
          userId: user.uid,
          category: result['category'] ?? 'altro',
          title: result['title'] ?? '',
          description: result['description'] ?? '',
          mediaFiles: result['media'] ?? [],
        );

        // Aggiungi il nuovo marker al set dei marker (gestito dal PlacesController)
        setState(() {
          _placesController.markers.add(
            Marker(
              markerId: MarkerId(newPlace.id),
              position: LatLng(newPlace.latitude, newPlace.longitude),
              onTap: () => _showPlaceDetails(newPlace),
            ),
          );
        });

        // Aggiorna i dati dell'utente su Firestore (per esempio, associando il nuovo segnaposto)
        await _mapService.updateUserPlaces(user.uid, newPlace.id);
      }
    }
    // Resetta la modalità di selezione e la posizione temporanea
    setState(() {
      _selectingPosition = false;
      _tempSelectedPosition = null;
    });
  }

  /// Recupera ed espone i dettagli del segnaposto.
  void _showPlaceDetails(Place place) async {
    String username = 'Sconosciuto';
    String? profileImageUrl;
    int likeCount = 0;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(place.userId)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        username = userDoc.data()!['username'] ?? 'Senza nome';
        profileImageUrl = userDoc.data()!['profileImageUrl'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('Errore nel recuperare il nome utente: $e');
    }
    try {
      final placeDoc = await FirebaseFirestore.instance
          .collection('places')
          .doc(place.id)
          .get();
      if (placeDoc.exists && placeDoc.data() != null) {
        likeCount = placeDoc.data()!['likeCount'] ?? 0;
      }
    } catch (e) {
      debugPrint('Errore nel recuperare il like count: $e');
    }
    setState(() {
      _selectedPlace = place;
      _selectedUsername = username;
      _selectedProfileImageUrl = profileImageUrl;
      _selectedLikeCount = likeCount;
    });
  }

  /// Costruisce la card che mostra i dettagli del segnaposto, inclusi i nuovi campi.
  Widget _buildFixedPlaceCard(Place place, String username, int likeCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlaceDetailsPage(place: place)),
          );
        },
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Immagine
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: _buildPlaceImage(place),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome del segnaposto
                    Text(
                      place.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Descrizione
                    if (place.description != null && place.description!.isNotEmpty)
                      Text(
                        place.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    // Visualizzazione della Categoria
                    Text(
                      "Categoria: ${place.category}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    // Visualizzazione del flag e eventuali dettagli di autorizzazione
                    Row(
                      children: [
                        Text(
                          "Autorizzazione: ${place.requiresPermission == true ? 'Richiesta' : 'Non richiesta'}",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (place.requiresPermission == true &&
                            place.permissionDetails != null &&
                            place.permissionDetails!.isNotEmpty)
                          Expanded(
                            child: Text(
                              " (${place.permissionDetails})",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Informazioni sull'utente e tempo trascorso dalla creazione
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: (_selectedProfileImageUrl != null &&
                              _selectedProfileImageUrl!.isNotEmpty)
                              ? NetworkImage(_selectedProfileImageUrl!)
                              : null,
                          child: (_selectedProfileImageUrl == null ||
                              _selectedProfileImageUrl!.isEmpty)
                              ? Text(
                            username.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            username,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (place.createdAt != null)
                          Text(
                            timeago.format(place.createdAt!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Like count
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$likeCount',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Costruisce l'immagine del segnaposto.
  Widget _buildPlaceImage(Place place) {
    if (place.mediaFiles != null && place.mediaFiles!.isNotEmpty) {
      return PageView.builder(
        itemCount: place.mediaFiles!.length,
        itemBuilder: (_, i) => Image.file(place.mediaFiles![i], fit: BoxFit.cover),
      );
    } else if (place.mediaUrls != null && place.mediaUrls!.isNotEmpty) {
      return PageView.builder(
        itemCount: place.mediaUrls!.length,
        itemBuilder: (_, i) => Image.network(place.mediaUrls![i], fit: BoxFit.cover),
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          (_mapService.isLoading)
              ? const Center(child: AlturaLoader())
              : GoogleMap(
            onMapCreated: (controller) {
              _mapService.mapController = controller;
            },
            onTap: (LatLng pos) {
              if (_selectingPosition) {
                _handleAddPlace(pos);
              } else {
                setState(() => _selectedPlace = null);
              }
            },
            onLongPress: (LatLng pos) {
              if (_selectingPosition) {
                _handleAddPlace(pos);
              }
            },
            myLocationEnabled: _mapService.hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: CameraPosition(
              target: _mapService.hasLocationPermission &&
                  _mapService.currentLocation != null
                  ? LatLng(
                _mapService.currentLocation!.latitude!,
                _mapService.currentLocation!.longitude!,
              )
                  : _mapService.defaultPosition,
              zoom: 14.0,
            ),
            markers: () {
              final filteredMarkers =
              _placesController.markers.where((marker) {
                final place = _placesController.places.firstWhere(
                      (p) => p.id == marker.markerId.value,
                  orElse: () => Place(
                    id: '',
                    name: '',
                    latitude: 0,
                    longitude: 0,
                    userId: '',
                    category: '',
                  ),
                );
                if (_selectedFilterCategories.isEmpty ||
                    _selectedFilterCategories
                        .any((cat) => cat.name == 'Tutte')) {
                  return true;
                }
                bool match = false;
                if (_selectedFilterCategories.any((cat) =>
                cat.name == 'Super Place') &&
                    (place.likeCount != null && place.likeCount! >= 20)) {
                  match = true;
                }
                if (_selectedFilterCategories
                    .any((cat) => cat.name == place.category)) {
                  match = true;
                }
                return match;
              });

              final Set<Marker> markersSet =
              filteredMarkers.map((marker) {
                return marker.copyWith(
                  onTapParam: () {
                    final place = _placesController.places.firstWhere(
                          (p) => p.id == marker.markerId.value,
                      orElse: () => Place(
                        id: '',
                        name: '',
                        latitude: 0,
                        longitude: 0,
                        userId: '',
                        category: '',
                      ),
                    );
                    _showPlaceDetails(place);
                  },
                );
              }).toSet();

              if (_tempSelectedPosition != null) {
                markersSet.add(
                  Marker(
                    markerId: const MarkerId('tempSelectedMarker'),
                    position: _tempSelectedPosition!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue),
                  ),
                );
              }
              return markersSet;
            }(),
          ),
          Positioned(
            top: topPadding + 16,
            left: 16,
            right: 16,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
              ),
              child: MultiSelectCategoryGrid(
                selected: _selectedFilterCategories,
                onToggle: (cat) {
                  setState(() {
                    if (_selectedFilterCategories
                        .any((c) => c.name == cat.name)) {
                      _selectedFilterCategories.removeWhere(
                              (c) => c.name == cat.name);
                    } else {
                      _selectedFilterCategories.add(cat);
                    }
                  });
                },
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: 16,
            child: GestureDetector(
              onTap: () => _mapService.openSearchPage(
                context: context,
                onSearchResult: (latLng) {
                  setState(() {});
                },
              ),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 5)
                  ],
                ),
                child: const Icon(Icons.search, color: Colors.black),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'btnLocation',
                  onPressed: () {
                    if (_mapService.hasLocationPermission) {
                      _mapService.moveCameraToCurrentLocation();
                    } else {
                      _mapService.showLocationSettingsDialog(context);
                    }
                  },
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: Icon(Icons.my_location, color: primaryColor),
                ),
                const SizedBox(height: 8),
                if (!_selectingPosition)
                  FloatingActionButton(
                    heroTag: 'btnAdd',
                    onPressed: () =>
                        setState(() => _selectingPosition = true),
                    child: const Icon(Icons.add),
                  )
                else
                  FloatingActionButton(
                    heroTag: 'btnCancel',
                    onPressed: () => setState(() {
                      _selectingPosition = false;
                      _tempSelectedPosition = null;
                    }),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          if (_selectingPosition)
            Positioned(
              bottom: 100,
              right: 16,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4)
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Per aggiungere un segnaposto,\nclicca o tieni premuto\nnella posizione desiderata',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: primaryColor),
                    ),
                  ),
                ),
              ),
            ),
          if (_selectedPlace != null)
            Positioned(
              bottom: 5,
              left: 16,
              right: 16,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: SizedBox(
                  height: 300,
                  child: _buildFixedPlaceCard(
                      _selectedPlace!, _selectedUsername, _selectedLikeCount),
                ),
              ),
            ),
        ],
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
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(child: mediaWidget),
    );
  }
}
