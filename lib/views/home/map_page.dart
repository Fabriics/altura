import 'package:altura/views/home/place_details_page.dart';
import 'package:altura/services/add_place_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lt;
import 'package:timeago/timeago.dart' as timeago;
import '../../models/custom_category_marker.dart';
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
  lt.LatLng? _tempSelectedPosition;

  // Lista di filtri attivi (categorie)
  List<PlaceCategory> _selectedFilterCategories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placesController = PlacesController();
    // Aggiungo un listener sul PlacesController per aggiornare la UI quando i segnaposti cambiano.
    _placesController.addListener(() {
      setState(() {});
    });
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
    _mapService.removeListener(() { setState(() {}); });
    _placesController.removeListener(() { setState(() {}); });
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
  Future<void> _handleAddPlace(lt.LatLng position) async {
    setState(() {
      _tempSelectedPosition = position;
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPlaceService(latLng: position)),
    );

    if (result != null) {
      debugPrint('Risultato dal nuovo segnaposto: $result');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _placesController.addPlace(
          latitude: position.latitude,
          longitude: position.longitude,
          userId: user.uid,
          category: result['category'] ?? 'altro',
          title: result['title'] ?? '',
          description: result['description'] ?? '',
          mediaFiles: result['media'] ?? [],
        );
        await _mapService.updateUserPlaces(user.uid, result['id'] ?? '');
      }
    }
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(place.userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        username = userDoc.data()!['username'] ?? 'Senza nome';
        profileImageUrl = userDoc.data()!['profileImageUrl'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('Errore nel recuperare il nome utente: $e');
    }
    try {
      final placeDoc = await FirebaseFirestore.instance.collection('places').doc(place.id).get();
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

  /// Costruisce i marker personalizzati per i segnaposti.
  List<Marker> _buildMarkers() {
    final markers = _placesController.places.where((place) {
      if (_selectedFilterCategories.isEmpty ||
          _selectedFilterCategories.any((cat) => cat.name == 'Tutte')) {
        return true;
      }
      bool match = false;
      if (_selectedFilterCategories.any((cat) => cat.name == 'Super Place') &&
          (place.likeCount != null && place.likeCount! >= 20)) {
        match = true;
      }
      if (_selectedFilterCategories.any((cat) => cat.name == place.category)) {
        match = true;
      }
      return match;
    }).map((place) {
      return Marker(
        width: 40,
        height: 40,
        point: lt.LatLng(place.latitude, place.longitude),
        child: GestureDetector(
          onTap: () => _showPlaceDetails(place),
          child: CustomCategoryMarker(category: place.category),
        ),
      );
    }).toList();

    if (_tempSelectedPosition != null) {
      markers.add(
        Marker(
          width: 40,
          height: 40,
          point: _tempSelectedPosition!,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
        ),
      );
    }
    return markers;
  }

  Widget _buildFixedPlaceCard(Place place, String username, int likeCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlaceDetailsPage(place: place)),
          ).then((_) {
            setState(() {
              _selectedPlace = null;
            });
          });
        },
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Immagine con overlay
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: _buildPlaceImage(place),
                    ),
                    // Overlay in basso a sinistra: icona categoria e permesso (se presente)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Row(
                        children: [
                          CustomCategoryMarker(category: place.category),
                          if (place.requiresPermission)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.lock, color: Colors.white, size: 20),
                            ),
                        ],
                      ),
                    ),
                    // Overlay in basso a destra: icona dei like e conteggio
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
                              '$likeCount',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sezione informazioni testuali sotto l'immagine
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
                    // Informazioni utente e tempo trascorso
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: (_selectedProfileImageUrl != null && _selectedProfileImageUrl!.isNotEmpty)
                              ? NetworkImage(_selectedProfileImageUrl!)
                              : null,
                          child: (_selectedProfileImageUrl == null || _selectedProfileImageUrl!.isEmpty)
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
        child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
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
              : FlutterMap(
            mapController: _mapService.mapController,
            options: MapOptions(
              initialCenter: _mapService.hasLocationPermission &&
                  _mapService.currentLocation != null
                  ? lt.LatLng(_mapService.currentLocation!.latitude!, _mapService.currentLocation!.longitude!)
                  : _mapService.defaultPosition,
              initialZoom: 14.0,
              onTap: (tapPosition, latlng) {
                if (_selectingPosition) {
                  _handleAddPlace(latlng);
                } else {
                  setState(() => _selectedPlace = null);
                }
              },
              onLongPress: (tapPosition, latlng) {
                if (_selectingPosition) _handleAddPlace(latlng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              MarkerLayer(markers: _buildMarkers()),
              if (_mapService.hasLocationPermission && _mapService.currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 20,
                      height: 20,
                      point: lt.LatLng(
                        _mapService.currentLocation!.latitude!,
                        _mapService.currentLocation!.longitude!,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Text(
              "© OpenStreetMap contributors, © CARTO",
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ),
          Positioned(
            top: topPadding + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
              ),
              child: MultiSelectCategoryGrid(
                selected: _selectedFilterCategories,
                onToggle: (cat) {
                  setState(() {
                    if (_selectedFilterCategories.any((c) => c.name == cat.name)) {
                      _selectedFilterCategories.removeWhere((c) => c.name == cat.name);
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
                onSearchResult: (latlng) {
                  setState(() {});
                },
              ),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
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
                    onPressed: () => setState(() => _selectingPosition = true),
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
              bottom: 550,
              right: 90,
              left: 90,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
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
                  child: _buildFixedPlaceCard(_selectedPlace!, _selectedUsername, _selectedLikeCount),
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
