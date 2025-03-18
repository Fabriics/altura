// lib/views/home_page.dart

import 'dart:async';
import 'dart:io';

import 'package:altura/views/place_details_page.dart';
import 'package:altura/views/search_page.dart'; // Nuova pagina di ricerca
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_open_app_settings/flutter_open_app_settings.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/place.dart';
import '../services/auth.dart';
import '../services/places_service.dart';
import 'edit_place_page.dart';

// Dropdown predefiniti per la selezione della categoria
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

/// HomePage: Mappa principale con gestione dei segnaposto
/// (la BottomNavigationBar è gestita in un altro file, ad es. main_screen.dart)
class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final Location _location = Location();
  LocationData? _currentLocation;

  final LatLng _defaultPosition = const LatLng(48.488, 13.678);
  bool _hasLocationPermission = false;
  bool _isLoading = true;

  StreamSubscription<LocationData>? _locationSubscription;
  late PlacesController _placesController;

  // Posizione centrale della mappa (usata per il mirino)
  LatLng? _centerPosition;

  // Flag per la "modalità selezione segnaposto"
  bool _selectingPosition = false;

  // Variabili di stato per la Card del segnaposto selezionato
  Place? _selectedPlace;
  String _selectedUsername = 'Sconosciuto';
  int _selectedPhotoCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _placesController = PlacesController();
    _initLocation();
    _initUser();
  }

  /// Inizializza l'utente controllando i dati su Firestore
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
        // Esempio: carica dati utente
        // _appUser = AppUser.fromMap(doc.data()!);
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
    // Al ritorno dell'app, reinizializza la posizione
    if (state == AppLifecycleState.resumed) {
      _initLocation();
    }
  }

  /// Funzione di utilità per gestire i casi in cui la localizzazione non sia disponibile
  void _handleLocationPermissionDenied() {
    if (!mounted) return;
    setState(() {
      _hasLocationPermission = false;
      _isLoading = false;
    });
    _setDefaultLocation();
  }

  /// Inizializza la localizzazione e gestisce i permessi
  Future<void> _initLocation() async {
    try {
      // Verifica che il servizio di localizzazione sia attivo
      if (!await _location.serviceEnabled()) {
        final bool serviceRequested = await _location.requestService();
        if (!serviceRequested) {
          _handleLocationPermissionDenied();
          return;
        }
      }

      // Controlla e richiede i permessi
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

      // Sottoscrizione agli aggiornamenti della posizione
      _locationSubscription?.cancel();
      _locationSubscription = _location.onLocationChanged.listen((locData) {
        if (!mounted) return;
        setState(() => _currentLocation = locData);
      });

      // Ottiene la posizione corrente
      final locData = await _location.getLocation();
      if (!mounted) return;
      setState(() {
        _currentLocation = locData;
        _hasLocationPermission = true;
        _isLoading = false;
      });
      _moveCameraToCurrentLocation();
    } on PlatformException catch (e) {
      // Gestione specifica per l'eccezione di permesso negato in modo permanente
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

  /// Imposta la camera sulla posizione di default
  void _setDefaultLocation() {
    _mapController?.animateCamera(CameraUpdate.newLatLng(_defaultPosition));
  }

  /// Muove la camera alla posizione corrente se i permessi sono stati concessi
  void _moveCameraToCurrentLocation() {
    if (_hasLocationPermission && _currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        ),
      );
    }
  }

  /// Mostra un dialog per aprire le impostazioni della localizzazione
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

  /// Effettua il sign out e torna alla pagina di login
  Future<void> signOut() async {
    await Auth().signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  // --------------------------------------------------
  // Wizard per la creazione di un nuovo segnaposto (2 step)
  // --------------------------------------------------
  /// Mostra il wizard per aggiungere un segnaposto, consentendo la selezione di media, titolo, descrizione e categoria
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

  // --------------------------------------------------
  // Funzioni per l'aggiunta di Marker
  // --------------------------------------------------
  /// Aggiunge un marker alla posizione selezionata
  Future<void> _addMarkerAtPosition(LatLng latLng) async {
    final localContext = context;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("Utente non loggato");
      return;
    }

    if (!_hasLocationPermission || _currentLocation == null) {
      showLocationSettingsDialog(context);
      return;
    }

    // Ottiene i dati inseriti dall'utente tramite il wizard
    final info = await _showAddPlaceWizard(localContext);
    if (info == null) return;

    final category = info['category'] as String? ?? 'altro';
    final mediaFiles = info['media'] as List<File>? ?? [];
    final title = info['title'] as String? ?? 'Segnaposto';
    final description = info['description'] as String? ?? '';

    // Aggiunge il nuovo segnaposto
    final newPlace = await _placesController.addPlace(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      userId: user.uid,
      category: category,
      title: title,
      description: description,
      mediaFiles: mediaFiles,
    );

    // Aggiorna il documento utente con il nuovo segnaposto
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'uploadedPlaces': FieldValue.arrayUnion([newPlace.id]),
    });

    // Ricarica i dati utente e sposta la mappa sul nuovo marker
    await _initUser();
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(newPlace.latitude, newPlace.longitude)),
    );
  }

// --------------------------------------------------
// Visualizzazione dettagli segnaposto con Card fissa
// --------------------------------------------------

  /// Quando un marker viene toccato, carichiamo i dettagli e settiamo la card
  void _showPlaceDetails(Place place) async {
    String username = 'Sconosciuto';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(place.userId)
          .get();
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

    // Aggiorniamo lo stato per far comparire la Card in basso
    setState(() {
      _selectedPlace = place;
      _selectedUsername = username;
      _selectedPhotoCount = photoCount;
    });
  }

  Widget _buildFixedPlaceCard(Place place, String username, int photoCount) {
    final bool isOwner = place.userId == FirebaseAuth.instance.currentUser?.uid;
    final int totalPhotos = place.totalPhotos; // mediaFiles + mediaUrls

    return Card(
      // Colore blu scuro come richiesto
      color: const Color(0xFF02398E),
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 4.0,
      child: InkWell(
        onTap: () {
          // Vai alla pagina di dettaglio
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaceDetailsPage(place: place),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            // Lasciamo che la card si adatti all’altezza del contenuto
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1) Immagine con bordi arrotondati
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 120, // Altezza fissa per l'immagine
                  width: double.infinity,
                  child: _buildPlaceImage(place),
                ),
              ),
              const SizedBox(height: 8),

              // 2) Nome del luogo (titolo)
              Text(
                place.name,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white, // Testo bianco per risaltare su sfondo blu
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),

              // 3) Descrizione (opzionale)
              if (place.description != null && place.description!.isNotEmpty)
                Text(
                  place.description!,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

              // 4) Se l’utente è proprietario, icone di modifica/eliminazione
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _editPlace(place, context),
                        icon: const Icon(Icons.edit),
                        color: Colors.white70,
                      ),
                      IconButton(
                        onPressed: () => _deletePlace(place, context),
                        icon: const Icon(Icons.delete),
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ),

              // Spacer per spingere data e foto in basso a destra
              const Spacer(),

              // 5) In fondo a destra: data di creazione e conteggio foto
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Data di creazione
                  if (place.createdAt != null) ...[
                    const Icon(Icons.timer, size: 18, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      timeago.format(place.createdAt!),
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(width: 16),
                  ],
                  // Icona foto + conteggio
                  const Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalPhotos',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  /// Se ci sono molte immagini, usa un PageView
  Widget _buildPlaceImage(Place place) {
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

  // --------------------------------------------------
  // Funzioni per la modifica e cancellazione del segnaposto
  // --------------------------------------------------
  /// Modifica il segnaposto esistente aprendo un dialog di editing
  Future<void> _editPlace(Place place, BuildContext boxContext) async {

    // Naviga verso la pagina di editing e attendi il risultato
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EditPlacePage(place: place),
      ),
    );

    // Se l'utente ha annullato o non è tornato nulla, interrompi
    if (result == null || result is! Map<String, dynamic>) return;

    // Estrai i dati restituiti dalla pagina di editing
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
  }

  /// Cancella il segnaposto dopo conferma
  Future<void> _deletePlace(Place place, BuildContext boxContext) async {

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

      // Se vuoi nascondere la Card dopo l’eliminazione:
      setState(() {
        if (_selectedPlace?.id == place.id) {
          _selectedPlace = null;
        }
      });
    }
  }

  /// Apre la pagina di ricerca e aggiorna la mappa in base al risultato
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
      );
      setState(() {
        // Esempio: aggiunge un marker temporaneo sul punto cercato
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

  /// Costruisce la mappa GoogleMap con gestione dei marker e della posizione
  Widget _buildGoogleMap() {
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      onCameraMove: (position) {
        _centerPosition = position.target;
      },
      myLocationEnabled: _hasLocationPermission,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: _hasLocationPermission && _currentLocation != null
            ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
            : _defaultPosition,
        zoom: 14.0,
      ),
      onTap: (LatLng latLng) {
        setState(() {
          _selectedPlace = null; // Chiude la card
        });
      },
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

  @override
  Widget build(BuildContext context) {
    // Non aggiungiamo la bottomNavigationBar qui,
    // perché è gestita in "main_screen.dart"
    return Scaffold(
      body: Stack(
        children: [
          // Visualizza la mappa o il caricamento
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildGoogleMap(),

          // Pulsante di ricerca in alto a destra
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

          // Pulsanti flottanti in basso a destra
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
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _selectingPosition
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: FloatingActionButton(
                    heroTag: 'btnAdd',
                    onPressed: () {
                      setState(() {
                        _selectingPosition = true;
                      });
                    },
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
                          setState(() {
                            _selectingPosition = false;
                          });
                        },
                        label: const Text("Qui"),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'btnCancel',
                        onPressed: () {
                          setState(() {
                            _selectingPosition = false;
                          });
                        },
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mirino visualizzato quando si è in modalità selezione posizione
          if (!_isLoading && _selectingPosition)
            Positioned(
              // Metà dell'altezza dello schermo meno metà della dimensione dell'icona
              top: (MediaQuery.of(context).size.height / 2) - 24,
              // Metà della larghezza dello schermo meno metà della dimensione dell'icona
              left: (MediaQuery.of(context).size.width / 2) - 24,
              child: const Icon(
                Icons.location_on,
                size: 48,
                color: Colors.redAccent,
              ),
            ),

          // La Card del segnaposto selezionato, se presente
          if (_selectedPlace != null)
            Positioned(
              // Aggiusta in base a quanto spazio occupa la bottom bar del main_screen
              bottom: kBottomNavigationBarHeight + 50,
              left: 16,
              right: 16,
              child: ConstrainedBox(
              // Impone un'altezza massima, il 35% dello schermo
              constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              // Se il contenuto supera la maxHeight, scorre
                child: SizedBox(
                  height: 300, // Tutte le card avranno la stessa altezza
                  child: _buildFixedPlaceCard(
                    _selectedPlace!,
                    _selectedUsername,
                    _selectedPhotoCount,
            ),
          ),
              ),
            ),
        ],
      ),
    );
  }
}
