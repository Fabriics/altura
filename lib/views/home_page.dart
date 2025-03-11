// lib/views/home_page.dart

import 'dart:async';
import 'dart:io';


import 'package:altura/views/place_details_page.dart';
import 'package:altura/views/search_page.dart'; // <-- Nuova pagina di ricerca
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_open_app_settings/flutter_open_app_settings.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/user_model.dart';
import '../models/place.dart';
import '../services/auth.dart';
import '../services/places_service.dart';

const List<DropdownMenuItem<String>> kCategoryItems = [
  DropdownMenuItem(value: 'pista_decollo', child: Text('Pista di decollo')),
  DropdownMenuItem(value: 'area_volo_libera', child: Text('Area volo libera')),
  DropdownMenuItem(value: 'area_restrizioni', child: Text('Area soggetta a restrizioni')),
  DropdownMenuItem(value: 'punto_ricarica', child: Text('Punto di ricarica')),
  DropdownMenuItem(value: 'altro', child: Text('Altro')),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// HomePage: Mappa principale con la gestione dei segnaposti (senza barra di ricerca)
class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final Location _location = Location();
  LocationData? _currentLocation;
  //AppUser? _appUser;

  final LatLng _defaultPosition = const LatLng(48.488, 13.678);

  bool _hasLocationPermission = false;
  bool _isLoading = true;

  StreamSubscription<LocationData>? _locationSubscription;
  late PlacesController _placesController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _placesController = PlacesController();
    _initLocation();
    _initUser();
  }

  Future<void> _initUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      debugPrint('Nessun utente loggato (firebaseUser == null)');
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      setState(() {
        //_appUser = AppUser.fromMap(doc.data()!);
      });
    } else {
      debugPrint('Il documento utente non esiste o è vuoto');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLocation();
    }
  }

  Future<void> _initLocation() async {
    final localContext = context;
    try {
      if (!await _location.serviceEnabled()) {
        final bool serviceRequested = await _location.requestService();
        if (!serviceRequested) {
          if (!mounted) return;
          setState(() {
            _hasLocationPermission = false;
            _isLoading = false;
          });
          _setDefaultLocation();
          return;
        }
      }

      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.deniedForever) {
        if (!mounted) return;
        setState(() {
          _hasLocationPermission = false;
          _isLoading = false;
        });
        _setDefaultLocation();
        return;
      } else if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) {
          if (!mounted) return;
          setState(() {
            _hasLocationPermission = false;
            _isLoading = false;
          });
          _setDefaultLocation();
          return;
        }
      }

      _locationSubscription?.cancel();
      _locationSubscription = _location.onLocationChanged.listen((locData) {
        if (!mounted) return;
        setState(() => _currentLocation = locData);
      });

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
        if (!mounted) return;
        setState(() {
          _hasLocationPermission = false;
          _isLoading = false;
        });
        _setDefaultLocation();
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showErrorDialog(localContext, "Errore posizione: ${e.message}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(localContext, "Errore posizione: $e");
    }
  }

  void _setDefaultLocation() {
    _mapController?.animateCamera(CameraUpdate.newLatLng(_defaultPosition));
  }

  void _moveCameraToCurrentLocation() {
    if (_hasLocationPermission && _currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        ),
      );
    }
  }

  void showLocationSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Row(
            children: [
              const Icon(Icons.location_off, color: Colors.red),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Localizzazione Necessaria",
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
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
                Navigator.of(dialogContext).pop();
                FlutterOpenAppSettings.openAppsSettings(
                  settingsCode: SettingsCode.LOCATION,
                );
              },
              child: const Text(
                "Impostazioni",
                style: TextStyle(color: Colors.blueAccent, fontSize: 15),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                "Annulla",
                style: TextStyle(color: Colors.blueAccent, fontSize: 15),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext localContext, String message) {
    showDialog(
      context: localContext,
      builder: (ctx) => AlertDialog(
        title: const Text("Errore"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> signOut() async {
    await Auth().signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  // Creazione nuovo segnaposto (Wizard 2 step)
  // --------------------------------------------------
  /// In questa wizard l'utente può selezionare più media (foto e video)
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            void goNextStep() {
              if (currentStep == 0 && selectedCategory == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Seleziona una categoria')));
                return;
              }
              setStateSB(() => currentStep = 1);
            }

            void goPreviousStep() {
              setStateSB(() => currentStep = 0);
            }

            void finishWizard() {
              if (title == null || title!.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Inserisci un titolo')));
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
                          Text(stepLabel, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (currentStep == 0) ...[
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
                                color: Colors.black.withOpacity(0.1),
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
                        Text(
                          'Carica i dettagli',
                          style: Theme.of(localContext).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(localContext).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Sezione per aggiungere media multipli
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              // Si assume che pickMedia() restituisca una List<File>
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
                                        ? 'Carica Foto/Video'
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      chosenMedia[index],
                                      height: 100,
                                      width: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              TextField(
                                onChanged: (val) => title = val,
                                style: const TextStyle(color: Colors.white),
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 30),
                              TextField(
                                onChanged: (val) => description = val,
                                style: const TextStyle(color: Colors.white),
                                textInputAction: TextInputAction.next,
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
                            ],
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

  // --------------------------------------------------
  // Funzioni di aggiunta Marker
  // --------------------------------------------------
  Future<void> _addMarkerAtPosition(LatLng latLng) async {
    final localContext = context;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog(localContext, 'Devi essere loggato per creare un segnaposto.');
      return;
    }

    if (!_hasLocationPermission || _currentLocation == null) {
      showLocationSettingsDialog(context);
      return;
    }
    final info = await _showAddPlaceWizard(localContext);
    if (info == null) return;

    final category = info['category'] as String? ?? 'altro';
    final mediaFiles = info['media'] as List<File>? ?? [];
    final title = info['title'] as String? ?? 'Segnaposto';
    final description = info['description'] as String? ?? '';

    // Si assume che addPlace sia stato aggiornato per gestire una lista di media
    final newPlace = await _placesController.addPlace(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      userId: user.uid,
      category: category,
      title: title,
      description: description,
      mediaFiles: mediaFiles, // Passiamo la lista di media
    );

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'uploadedPlaces': FieldValue.arrayUnion([newPlace.id]),
    });

    await _initUser();
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(newPlace.latitude, newPlace.longitude)),
    );
  }

  Future<void> _addMarkerOnMyPosition() async {
    final localContext = context;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog(localContext, 'Devi essere loggato per creare un segnaposto.');
      return;
    }
    if (!_hasLocationPermission || _currentLocation == null) {
      showLocationSettingsDialog(context);
      return;
    }

    final info = await _showAddPlaceWizard(localContext);
    if (info == null) return;

    final category = info['category'] as String? ?? 'altro';
    final mediaFiles = info['media'] as List<File>? ?? [];
    final title = info['title'] as String? ?? 'Segnaposto';
    final description = info['description'] as String? ?? '';

    final latLng = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    final newPlace = await _placesController.addPlace(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      userId: user.uid,
      category: category,
      title: title,
      description: description,
      mediaFiles: mediaFiles,
    );

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'uploadedPlaces': FieldValue.arrayUnion([newPlace.id]),
    });

    await _initUser();
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(newPlace.latitude, newPlace.longitude)),
    );
  }

  // --------------------------------------------------
  // Visualizzazione dettagli (preview bottom sheet)
  // --------------------------------------------------
  void _showPlaceDetails(Place place) async {
    final localContext = context;
    String username = 'Sconosciuto';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(place.userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          username = data['username'] ?? 'Senza nome';
        }
      }
    } catch (e) {
      debugPrint('Errore username: $e');
    }
    final photoCount = (place.mediaFiles != null) ? place.mediaFiles!.length : 1;

    if (!mounted) return;
    showModalBottomSheet(
      context: localContext,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bottomSheetCtx) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: _buildFixedPlaceCard(place, username, photoCount, bottomSheetCtx),
        );
      },
    );
  }

  /// La card di preview del segnaposto.
  /// Se l'utente tocca il banner (area principale) viene chiuso il bottom sheet e si apre la pagina di dettaglio.
  Widget _buildFixedPlaceCard(Place place, String username, int photoCount, BuildContext bottomSheetCtx) {
    return GestureDetector(
      onTap: () {
        Navigator.of(bottomSheetCtx).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceDetailsPage(place: place),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner: se il segnaposto contiene più media, mostriamo un carousel (PageView)
          SizedBox(
            height: 150,
            width: double.infinity,
            child: _buildPlaceImage(place),
          ),
          const SizedBox(height: 8),
          Text(
            place.name,
            style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
          ),
          Text(username, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 8),
          if (place.description != null && place.description!.isNotEmpty)
            Text(place.description!, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          if (place.createdAt != null)
            Row(
              children: [
                const Icon(Icons.timer, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Caricato ${timeago.format(place.createdAt!)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('$photoCount di $photoCount', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(width: 12),
              if (place.userId == FirebaseAuth.instance.currentUser?.uid) ...[
                IconButton(
                  onPressed: () => _editPlace(place, bottomSheetCtx),
                  icon: const Icon(Icons.edit),
                  color: Colors.black54,
                ),
                IconButton(
                  onPressed: () => _deletePlace(place, bottomSheetCtx),
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  /// Se il segnaposto contiene più media, li visualizziamo in un PageView
  Widget _buildPlaceImage(Place place) {
    // Si assume che il modello Place ora contenga il campo "mediaFiles" (List<File>?) e/o "mediaUrls" (List<String>?)
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

  // --------------------------------------------------
  // Funzioni di modifica e cancellazione segnaposto
  // --------------------------------------------------
  Future<void> _editPlace(Place place, BuildContext boxContext) async {
    Navigator.of(boxContext).pop();

    final localContext = context;
    final info = await _askEditPlaceDialog(localContext, place);
    if (info == null) return;

    final newCategory = info['category'] as String;
    final newTitle = info['title'] as String? ?? '';
    final newDescription = info['description'] as String? ?? '';
    final newMediaFiles = info['media'] as List<File>? ?? [];

    await _placesController.updatePlace(
      placeId: place.id,
      userId: place.userId,
      newTitle: newTitle,
      newDescription: newDescription,
      newCategory: newCategory,
      newMediaFiles: newMediaFiles,
    );
  }

  Future<void> _deletePlace(Place place, BuildContext boxContext) async {
    Navigator.of(boxContext).pop();
    final localContext = context;
    final confirm = await showDialog<bool>(
      context: localContext,
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
      debugPrint('Eliminato segnaposto con ID: ${place.id}');
    }
  }

  /// Dialog per modificare un segnaposto esistente (supporta più media)
  Future<Map<String, dynamic>?> _askEditPlaceDialog(BuildContext localContext, Place place) async {
    String selectedCategory = place.category;
    List<File> pickedMedia = [];

    final titleController = TextEditingController(text: place.name);
    final descriptionController = TextEditingController(text: place.description);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: localContext,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctxSB, setStateSB) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Modifica Segnaposto',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Categoria: ', style: TextStyle(fontSize: 18)),
                        DropdownButton<String>(
                          value: selectedCategory,
                          items: kCategoryItems,
                          onChanged: (val) {
                            if (val != null) {
                              setStateSB(() => selectedCategory = val);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Campo per il Titolo
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Titolo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Campo per la Descrizione
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Descrizione', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          TextField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final media = await _placesController.pickMedia();
                        if (media != null && media.isNotEmpty) {
                          setStateSB(() {
                            pickedMedia.addAll(media);
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Theme.of(localContext).colorScheme.primary,
                      ),
                      child: const Text('Seleziona Nuovi Media', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (pickedMedia.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: pickedMedia.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  pickedMedia[index],
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Annulla', style: TextStyle(color: Colors.red, fontSize: 18)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop({
                              'category': selectedCategory,
                              'title': titleController.text,
                              'description': descriptionController.text,
                              'media': pickedMedia,
                            });
                          },
                          child: const Text('Salva', style: TextStyle(fontSize: 18)),
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
    );

    titleController.dispose();
    descriptionController.dispose();
    return result;
  }


  /// Costruisce la mappa
  Widget _buildGoogleMap() {
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      myLocationEnabled: _hasLocationPermission,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: _hasLocationPermission && _currentLocation != null
            ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
            : _defaultPosition,
        zoom: 14.0,
      ),
      onLongPress: _addMarkerAtPosition,
      markers: _placesController.markers.map((marker) {
        return marker.copyWith(
          onTapParam: () {
            final place = _placesController.places.firstWhere(
                  (p) => p.id == marker.markerId.value,
            );
            _showPlaceDetails(place);
          },
        );
      }).toSet(),
    );
  }

  void _openSearchPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchPage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      double lat = result['lat'];
      double lng = result['lng'];

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(lat, lng)),
      ); // Funzione che ora implementiamo
      setState(() {
        // Puoi scegliere se pulire i marker precedenti o meno
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildGoogleMap(),
          // Pulsante di ricerca (in alto a destra)
          Positioned(
            top: 80,
            right: 16,
            child: GestureDetector(
              onTap: () {
                // Naviga verso la SearchPage
                _openSearchPage();
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      spreadRadius: 2,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.search, color: Colors.black),
              ),
            ),
          ),

          // Pulsanti floating in basso a destra
          Positioned(
            bottom: 130,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  child: Icon(
                    Icons.my_location,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'btnAdd',
                  onPressed: _addMarkerOnMyPosition,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
