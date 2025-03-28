import 'dart:async';
import 'dart:io';

import 'package:altura/views/home/place_details_page.dart';
import 'package:altura/views/home/search_page.dart'; // Nuova pagina di ricerca
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_open_app_settings/flutter_open_app_settings.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/place_model.dart';
import '../../services/altura_loader.dart';
import '../../services/auth_service.dart';
import '../../services/places_service.dart';
import 'edit/edit_place_page.dart';

/// Dropdown per la selezione della categoria
const List<DropdownMenuItem<String>> kCategoryItems = [
  DropdownMenuItem(value: 'pista_decollo', child: Text('Pista di decollo')),
  DropdownMenuItem(value: 'area_volo_libera', child: Text('Area volo libera')),
  DropdownMenuItem(value: 'area_restrizioni', child: Text('Area soggetta a restrizioni')),
  DropdownMenuItem(value: 'punto_ricarica', child: Text('Punto di ricarica')),
  DropdownMenuItem(value: 'altro', child: Text('Altro')),
];

/// HomePage: mappa principale con segnaposti.
/// NON usa StreamBuilder (approccio manuale):
/// se un segnaposto viene rimosso in un'altra pagina, per aggiornare
/// la mappa serve una ricarica esplicita (ad es. al ritorno da Navigator).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Controller per GoogleMap
  GoogleMapController? _mapController;

  // Gestione localizzazione
  final Location _location = Location();
  LocationData? _currentLocation;

  // Posizione di default se i permessi sono negati
  final LatLng _defaultPosition = const LatLng(48.488, 13.678);

  // Flag permessi e caricamento
  bool _hasLocationPermission = false;
  bool _isLoading = true;

  // Stream subscription alla posizione
  StreamSubscription<LocationData>? _locationSubscription;

  // Controller personalizzato dei segnaposti
  late PlacesController _placesController;

  // Posizione attuale del centro della mappa
  LatLng? _centerPosition;

  // Modalità "selezione segnaposto"
  bool _selectingPosition = false;

  // Variabili per la card di anteprima
  Place? _selectedPlace;
  String _selectedUsername = 'Sconosciuto';
  int _selectedPhotoCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Inizializziamo il PlacesController
    _placesController = PlacesController();

    // Chiediamo i permessi di localizzazione
    _initLocation();

    // Carichiamo alcuni dati utente, se serve
    _initUser();
  }

  /// Carica dati utente (opzionale).
  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Nessun utente loggato');
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      setState(() {
        // Esempio: _appUser = AppUser.fromMap(doc.data()!)
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Se l'app ritorna in foreground, ricontrolliamo i permessi
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLocation();
    }
  }

  /// Se i permessi sono negati, disattiviamo caricamento e usiamo posizione default
  void _handleLocationPermissionDenied() {
    if (!mounted) return;
    setState(() {
      _hasLocationPermission = false;
      _isLoading = false;
    });
    _setDefaultLocation();
  }

  /// Inizializza la localizzazione (richiede permessi, ecc.)
  Future<void> _initLocation() async {
    try {
      // Verifica servizio attivo
      if (!await _location.serviceEnabled()) {
        final serviceRequested = await _location.requestService();
        if (!serviceRequested) {
          _handleLocationPermissionDenied();
          return;
        }
      }

      // Permessi
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.deniedForever) {
        _handleLocationPermissionDenied();
        return;
      } else if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) {
          _handleLocationPermissionDenied();
          return;
        }
      }

      // Sottoscrizione posizione
      _locationSubscription?.cancel();
      _locationSubscription = _location.onLocationChanged.listen((locData) {
        if (!mounted) return;
        setState(() => _currentLocation = locData);
      });

      // Posizione corrente
      final locData = await _location.getLocation();
      if (!mounted) return;
      setState(() {
        _currentLocation = locData;
        _hasLocationPermission = true;
        _isLoading = false;
      });
      _moveCameraToCurrentLocation();
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED_NEVER_ASK') {
        _handleLocationPermissionDenied();
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

  }

  /// Muove la camera su _defaultPosition
  void _setDefaultLocation() {
    _mapController?.animateCamera(CameraUpdate.newLatLng(_defaultPosition));
  }

  /// Se i permessi ci sono, muove la camera su _currentLocation
  void _moveCameraToCurrentLocation() {
    if (_hasLocationPermission && _currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        ),
      );
    }
  }

  /// Dialog per invitare l'utente ad aprire impostazioni
  void showLocationSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(
              child: Text("Localizzazione Necessaria", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          "Per continuare a utilizzare tutte le funzionalità dell'app, abilita la localizzazione dalle impostazioni.",
          textAlign: TextAlign.justify,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              FlutterOpenAppSettings.openAppsSettings(settingsCode: SettingsCode.LOCATION);
            },
            child: const Text("Impostazioni", style: TextStyle(color: Colors.blueAccent, fontSize: 15)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annulla", style: TextStyle(color: Colors.blueAccent, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  /// Esempio di logout
  Future<void> signOut() async {
    await Auth().signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  // ---------------------------------------------------------------------------
  // Wizard 2-step per creare un segnaposto
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _showAddPlaceWizard(BuildContext localContext) async {
    int currentStep = 0;
    String? selectedCategory;
    List<File> chosenMedia = [];
    String? title;
    String? description;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: localContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            // Funzione per passare al passo successivo (step 1 -> step 2)
            void goNextStep() {
              if (currentStep == 0 && selectedCategory == null) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('Seleziona una categoria')));
                return;
              }
              setStateSB(() => currentStep = 1);
            }

            // Torna indietro (step 2 -> step 1)
            void goPreviousStep() {
              setStateSB(() => currentStep = 0);
            }

            // Conclude il wizard e restituisce i dati inseriti
            void finishWizard() {
              if (title == null || title!.isEmpty) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('Inserisci un titolo')));
                return;
              }
              Navigator.of(ctx).pop({
                'category': selectedCategory,
                'media': chosenMedia,
                'title': title,
                'description': description,
              });
            }

            final stepLabel = (currentStep == 0) ? 'Step 1 di 2' : 'Step 2 di 2';

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header con indicazione dello step corrente
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (currentStep == 1)
                            IconButton(
                              onPressed: goPreviousStep,
                              icon: const Icon(Icons.arrow_back),
                              color: Colors.black,
                            )
                          else
                            const SizedBox(width: 48),
                          Text(stepLabel,
                              style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (currentStep == 0) ...[
                        // Step 1: Selezione della categoria
                        Text(
                          'Seleziona la Categoria',
                          style: Theme.of(localContext).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(localContext).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              RadioListTile(
                                title: const Text('Pista di decollo', style: TextStyle(color: Colors.black)),
                                activeColor: Colors.blue[900],
                                value: 'pista_decollo',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text('Area volo libera', style: TextStyle(color: Colors.black)),
                                activeColor: Colors.blue[900],
                                value: 'area_volo_libera',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text('Area soggetta a restrizioni', style: TextStyle(color: Colors.black)),
                                activeColor: Colors.blue[900],
                                value: 'area_restrizioni',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text('Punto di ricarica', style: TextStyle(color: Colors.black)),
                                activeColor: Colors.blue[900],
                                value: 'punto_ricarica',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text('Altro', style: TextStyle(color: Colors.black)),
                                activeColor: Colors.blue[900],
                                value: 'altro',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: goNextStep,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Theme.of(localContext).colorScheme.primary,
                              ),
                              child: const Text(
                                'Prossimo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Step 2: Caricamento dettagli e media
                        Text(
                          'Inserisci i dettagli',
                          style: Theme.of(localContext).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(localContext).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final media = await _placesController.pickMedia();
                              if (media != null && media.isNotEmpty) {
                                setStateSB(() {
                                  chosenMedia.addAll(media);
                                });
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.camera_alt, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    (chosenMedia.isEmpty)
                                        ? 'Inserisci Foto/Video'
                                        : 'Aggiungi altri media',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (chosenMedia.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: chosenMedia.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          chosenMedia[index],
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.black),
                                            onPressed: () {
                                              setStateSB(() {
                                                chosenMedia.removeAt(index);
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Campo per il Titolo
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: TextField(
                            onChanged: (val) => title = val,
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[200],
                              labelText: "Titolo",
                              hintText: "Inserisci titolo",
                              labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Campo per la Descrizione
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            onChanged: (val) => description = val,
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                            keyboardType: TextInputType.multiline,
                            minLines: 3, // Mostra almeno 3 righe
                            maxLines: 10,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[200],
                              labelText: "Descrizione",
                              hintText: "Inserisci descrizione",
                              labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: finishWizard,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Theme.of(localContext).colorScheme.primary,
                              ),
                              child: const Text(
                                'Carica',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Aggiunge un marker
  Future<void> _addMarkerAtPosition(LatLng latLng) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("Utente non loggato");
      return;
    }

    if (!_hasLocationPermission || _currentLocation == null) {
      showLocationSettingsDialog(context);
      return;
    }

    final info = await _showAddPlaceWizard(context);
    if (info == null) return;

    final category = info['category'] as String? ?? 'altro';
    final mediaFiles = info['media'] as List<File>? ?? [];
    final title = info['title'] as String? ?? 'Segnaposto';
    final description = info['description'] as String? ?? '';

    final newPlace = await _placesController.addPlace(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      userId: user.uid,
      category: category,
      title: title,
      description: description,
      mediaFiles: mediaFiles,
    );

    // Aggiorna i segnaposti dell'utente
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'uploadedPlaces': FieldValue.arrayUnion([newPlace.id]),
    });

    // Ricarica dati utente (opzionale)
    await _initUser();

    // Muove la camera sul nuovo segnaposto
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(newPlace.latitude, newPlace.longitude)),
    );
  }

  // ---------------------------------------------------------------------------
  // Card di anteprima
  // ---------------------------------------------------------------------------
  void _showPlaceDetails(Place place) async {
    String username = 'Sconosciuto';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(place.userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        username = userDoc.data()!['username'] ?? 'Senza nome';
      }
    } catch (e) {
      debugPrint('Errore username: $e');
    }

    final photoCount = (place.mediaFiles != null) ? place.mediaFiles!.length : 1;
    setState(() {
      _selectedPlace = place;
      _selectedUsername = username;
      _selectedPhotoCount = photoCount;
    });
  }

  Widget _buildFixedPlaceCard(Place place, String username, int photoCount) {
    final bool isOwner = place.userId == FirebaseAuth.instance.currentUser?.uid;
    final int totalPhotos = place.totalPhotos;

    return Card(
      color: const Color(0xFF02398E),
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceDetailsPage(place: place)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Immagine
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: _buildPlaceImage(place),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                place.name,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
              if (place.description != null && place.description!.isNotEmpty)
                Text(
                  place.description!,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (isOwner)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      color: Colors.white70,
                      onPressed: () => _editPlace(place, context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.redAccent,
                      onPressed: () => _deletePlace(place, context),
                    ),
                  ],
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (place.createdAt != null) ...[
                    const Icon(Icons.timer, size: 18, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      timeago.format(place.createdAt!),
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(width: 16),
                  ],
                  const Icon(Icons.camera_alt, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('$totalPhotos', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Modifica / Elimina
  // ---------------------------------------------------------------------------
  Future<void> _editPlace(Place place, BuildContext ctx) async {
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
  }

  Future<void> _deletePlace(Place place, BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Eliminare il segnaposto "${place.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _placesController.deletePlace(place.id);
      debugPrint('Eliminato segnaposto con ID: ${place.id}');
      setState(() {
        if (_selectedPlace?.id == place.id) {
          _selectedPlace = null;
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Ricerca
  // ---------------------------------------------------------------------------
  void _openSearchPage() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
    if (result == null) return;

    final lat = result['lat'] as double;
    final lng = result['lng'] as double;
    _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));

    setState(() {
      // Se vuoi, aggiungi un marker temporaneo sul punto cercato
      _placesController.markers.clear();
      _placesController.markers.add(
        Marker(
          markerId: const MarkerId('searchedLocation'),
          position: LatLng(lat, lng),
          infoWindow: const InfoWindow(title: 'Risultato ricerca'),
          flat: true,
        ),
      );
    });
  }

  /// Crea la GoogleMap
  Widget _buildGoogleMap() {
    return GoogleMap(
      onMapCreated: (ctrl) => _mapController = ctrl,
      onCameraMove: (pos) => _centerPosition = pos.target,
      myLocationEnabled: _hasLocationPermission,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: _hasLocationPermission && _currentLocation != null
            ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
            : _defaultPosition,
        zoom: 14.0,
      ),
      onTap: (_) => setState(() => _selectedPlace = null),
      onLongPress: _addMarkerAtPosition,
      markers: _placesController.markers.map((marker) {
        return marker.copyWith(
          onTapParam: () {
            final place = _placesController.places.firstWhere((p) => p.id == marker.markerId.value);
            _showPlaceDetails(place);
          },
        );
      }).toSet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Non aggiungiamo la bottomNavigationBar qui, la gestisci altrove
    return Scaffold(
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: AlturaLoader())
          else
            _buildGoogleMap(),

          // Pulsante ricerca
          Positioned(
            top: 80,
            right: 16,
            child: GestureDetector(
              onTap: _openSearchPage,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                ),
                child: const Icon(Icons.search, color: Colors.black),
              ),
            ),
          ),

          // Pulsanti in basso a destra
          Positioned(
            bottom: 130,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsante "my location"
                FloatingActionButton(
                  heroTag: 'btnLocation',
                  onPressed: () {
                    if (_hasLocationPermission) {
                      _moveCameraToCurrentLocation();
                    } else {
                      showLocationSettingsDialog(context);
                    }
                  },
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 8),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _selectingPosition ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: FloatingActionButton(
                    heroTag: 'btnAdd',
                    onPressed: () => setState(() => _selectingPosition = true),
                    child: const Icon(Icons.add),
                  ),
                  secondChild: Column(
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'btnConfirm',
                        onPressed: () async {
                          if (_centerPosition != null) {
                            await _addMarkerAtPosition(_centerPosition!);
                          }
                          setState(() => _selectingPosition = false);
                        },
                        label: const Text("Qui"),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'btnCancel',
                        onPressed: () => setState(() => _selectingPosition = false),
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mirino
          if (!_isLoading && _selectingPosition)
            Positioned(
              top: (MediaQuery.of(context).size.height / 2) - 24,
              left: (MediaQuery.of(context).size.width / 2) - 24,
              child: const Icon(Icons.location_on, size: 48, color: Colors.redAccent),
            ),

          // Card anteprima se c'è un segnaposto selezionato
          if (_selectedPlace != null)
            Positioned(
              bottom: kBottomNavigationBarHeight + 50,
              left: 16,
              right: 16,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                child: SizedBox(
                  height: 300,
                  child: _buildFixedPlaceCard(_selectedPlace!, _selectedUsername, _selectedPhotoCount),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
