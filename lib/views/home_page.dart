import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:altura/services/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:flutter_open_app_settings/flutter_open_app_settings.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/places_service.dart';
import '../models/place.dart';

/// Categorie aggiornate per i droni
/// NB: usiamo 'value' coerenti con la logica della tua app (Firestore, etc.)
const List<DropdownMenuItem<String>> kCategoryItems = [
  DropdownMenuItem(value: 'pista_decollo', child: Text('Pista di decollo')),
  DropdownMenuItem(value: 'area_volo_libera', child: Text('Area volo libera')),
  DropdownMenuItem(value: 'area_restrizioni', child: Text('Area soggetta a restrizioni')),
  DropdownMenuItem(value: 'punto_ricarica', child: Text('Punto di ricarica')),
  DropdownMenuItem(value: 'altro', child: Text('Altro')),
];

/// HomePage: Mappa principale con la gestione dei segnaposti
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Stato della HomePage
class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // --------------------------------------------------
  // Variabili Principali
  // --------------------------------------------------
  GoogleMapController? _mapController;
  final Location _location = Location();
  LocationData? _currentLocation;
  AppUser? _appUser; // qui salveremo i dati personalizzati dell'utente

  // Posizione di default se i permessi sono negati
  final LatLng _defaultPosition = const LatLng(48.488, 13.678);


  bool _hasLocationPermission = false; // Indica se abbiamo i permessi GPS
  bool _isLoading = true;              // Indica se stiamo caricando la posizione

  /// Flag per mostrare/nascondere la barra di ricerca
  bool _showSearchBar = false;

  /// Controller per il TextField della ricerca
  final TextEditingController _searchController = TextEditingController();

  /// Lista di suggerimenti per l'autocomplete
  List<Map<String, dynamic>> _predictions = [];

  /// StreamSubscription per ascoltare i cambiamenti di posizione
  StreamSubscription<LocationData>? _locationSubscription;

  /// Controller personalizzato che gestisce i segnaposti su Firestore
  late PlacesController _placesController;

  /// API key (Google Places API abilitata)
  static const _placesApiKey = 'AIzaSyBB6JMMFw8Vz1MniyHuz4_iN3xQ7QbWbv8';

  // --------------------------------------------------
  // Ciclo di vita
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Istanzia il controller che gestisce la logica dei segnaposti
    _placesController = PlacesController();

    // Inizializza la localizzazione
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

    debugPrint('Doc for user ${firebaseUser.uid}: ${doc.data()}');

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final userModel = AppUser.fromMap(data);

      setState(() {
        _appUser = userModel;
        debugPrint('AppUser caricato con successo: $_appUser');
      });
    } else {
      debugPrint('Il documento non esiste o è vuoto');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();  // Chiudi lo stream della localizzazione
    _searchController.dispose();      // Libera risorse dal controller di testo
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Se l'app torna in foreground, rieverifichiamo i permessi
    if (state == AppLifecycleState.resumed) {
      _initLocation();
    }
  }

  // --------------------------------------------------
  // Funzioni di Inizializzazione e Permessi
  // --------------------------------------------------
  Future<void> _initLocation() async {
    // Cattura il context attuale in una variabile locale,
    // così non usiamo 'context' dopo un eventuale 'await'
    final localContext = context;

    try {
      // Controllo se il servizio GPS è abilitato
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

      // Controllo permessi
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
        // Richiedi permessi
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

      // Avviamo l'ascolto continuo della posizione
      _locationSubscription?.cancel();
      _locationSubscription = _location.onLocationChanged.listen((locData) {
        if (!mounted) return;
        setState(() => _currentLocation = locData);
      });

      // Preleviamo la posizione corrente
      final locData = await _location.getLocation();
      if (!mounted) return;

      // Aggiorniamo stato
      setState(() {
        _currentLocation = locData;
        _hasLocationPermission = true;
        _isLoading = false;
      });

      // Muoviamo la camera dove si trova l'utente
      _moveCameraToCurrentLocation();
    } on PlatformException catch (e) {
      // Se l'utente nega i permessi in modo permanente
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

  /// Se permessi negati, impostiamo la camera su una posizione di default
  void _setDefaultLocation() {
    _mapController?.animateCamera(CameraUpdate.newLatLng(_defaultPosition));
  }

  /// Muove la camera sulla posizione corrente
  void _moveCameraToCurrentLocation() {
    if (_hasLocationPermission && _currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        ),
      );
    }
  }

  // --------------------------------------------------
  // Dialog e Messaggi di errore
  // --------------------------------------------------

  /// Mostra un dialog per invitare l'utente ad abilitare la localizzazione
  void _showSettingsDialog(BuildContext localContext) {
    showDialog(
      context: localContext,
      builder: (ctx) => AlertDialog(
        title: const Text("Permesso di Localizzazione Necessario"),
        content: const Text(
            "Per continuare, abilita la localizzazione dalle impostazioni dell'app."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              FlutterOpenAppSettings.openAppsSettings(
                  settingsCode: SettingsCode.APP_SETTINGS);
            },
            child: const Text("Vai alle Impostazioni",
                style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annulla",
                style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  /// Mostra un dialog di errore generico
  void _showErrorDialog(BuildContext localContext, String message) {
    if (!mounted) return;
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

  // --------------------------------------------------
  // Logout
  // --------------------------------------------------
  Future<void> signOut() async {
    await Auth().signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  // --------------------------------------------------
  // Creazione nuovo segnaposto (Wizard 2 step)
  // --------------------------------------------------

  /// Mostra un bottomSheet a 2 step (scegli categoria => inserisci dettagli)
  Future<Map<String, dynamic>?> _showAddPlaceWizard(BuildContext localContext) async {
    int currentStep = 0;       // Step 0 = categorie, Step 1 = dettagli
    String? selectedCategory;  // Categoria scelta
    File? chosenMedia;         // Foto/Video scelto
    String? title;            // Titolo
    String? description;      // Descrizione

    // Usiamo showModalBottomSheet in modo sincrono su localContext
    return showModalBottomSheet<Map<String, dynamic>>(
      context: localContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // StatefulBuilder per avere uno stato all’interno del bottomSheet
        return StatefulBuilder(
          builder: (context, setStateSB) {
            // Passo successivo
            void goNextStep() {
              if (currentStep == 0 && selectedCategory == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Seleziona una categoria')),
                );
                return;
              }
              setStateSB(() => currentStep = 1);
            }

            // Torna indietro
            void goPreviousStep() {
              setStateSB(() => currentStep = 0);
            }

            // Conclude
            void finishWizard() {
              if (title == null || title!.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Inserisci un titolo')),
                );
                return;
              }
              Navigator.of(ctx).pop({
                'category': selectedCategory,
                'media': chosenMedia,
                'title': title,
                'description': description,
              });
            }

            // Label step
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
                      // Barra in alto (icona back + label)
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
                              style:
                              const TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // STEP 0: Categorie
                      if (currentStep == 0) ...[
                        Text(
                          'Seleziona la Categoria',
                          style: Theme.of(localContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(localContext).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Container sfondo blu scuro
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white, // ~0.8
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
                                title: const Text(
                                  'Pista di decollo',
                                  style: TextStyle(color: Colors.black),

                                ),
                                activeColor: Colors.blue[900],
                                value: 'pista_decollo',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text(
                                  'Area volo libera',
                                  style: TextStyle(color: Colors.black),
                                ),
                                activeColor: Colors.blue[900],
                                value: 'area_volo_libera',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),

                              RadioListTile(
                                title: const Text(
                                  'Area soggetta a restrizioni',
                                  style: TextStyle(color: Colors.black),
                                ),
                                activeColor: Colors.blue[900],
                                value: 'area_restrizioni',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text(
                                  'Punto di ricarica',
                                  style: TextStyle(color: Colors.black),
                                ),
                                activeColor: Colors.blue[900],
                                value: 'punto_ricarica',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text(
                                  'Altro',
                                  style: TextStyle(color: Colors.black),
                                ),
                                activeColor: Colors.blue[900],
                                value: 'altro',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Bottone "Prossimo"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: goNextStep,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                Theme.of(localContext).colorScheme.primary,
                              ),
                              child: const Text(
                                'Prossimo',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ]

                      // STEP 1: Dettagli
                      else ...[
                        Text(
                          'Carica i dettagli',
                          style: Theme.of(localContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(localContext).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Container sfondo blu scuro (foto/video)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[900], // ~0.8
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final picked = await _placesController.pickImage();
                              if (picked != null) {
                                setStateSB(() => chosenMedia = picked);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(Icons.camera_alt, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    (chosenMedia == null)
                                        ? 'Carica Foto/Video'
                                        : 'Foto/Video selezionata',
                                    style: TextStyle(
                                       color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (chosenMedia != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              chosenMedia!,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Container sfondo blu scuro (titolo)
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
                                  decoration:  InputDecoration(
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

                        // Container  (descrizione)
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
                                decoration:  InputDecoration(
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
                        // Bottone finale
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: finishWizard,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                Theme.of(localContext).colorScheme.primary,
                              ),
                              child: const Text('Carica', style: TextStyle(color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
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
  // Aggiunta Marker
  // --------------------------------------------------

  /// Aggiunge un marker con LongPress in un punto a scelta
  Future<void> _addMarkerAtPosition(LatLng latLng) async {
    final localContext = context;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog(localContext, 'Devi essere loggato per creare un segnaposto.');
      return;
    }

    // Mostra wizard
    final info = await _showAddPlaceWizard(localContext);
    if (info == null) return;

    // Carichiamo i dati dal wizard
    final category = info['category'] as String? ?? 'altro';
    final mediaFile = info['media'] as File?;
    final title = info['title'] as String? ?? 'Segnaposto';
    final description = info['description'] as String? ?? '';

    // Salva su Firestore
    final newPlace = await _placesController.addPlace(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      userId: user.uid,
      category: category,
      title: title,
      description: description,
      imageFile: mediaFile,
    );

    // 1) Aggiorno l’utente
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'uploadedPlaces': FieldValue.arrayUnion([newPlace.id]),
    });

    // Ricarico i dati utente
    await _initUser();
    // Centra la mappa sul nuovo segnaposto
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(newPlace.latitude, newPlace.longitude)),
    );
  }

  /// Aggiunge un marker sulla posizione attuale dell’utente
  Future<void> _addMarkerOnMyPosition() async {
    final localContext = context;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog(localContext, 'Devi essere loggato per creare un segnaposto.');
      return;
    }
    if (!_hasLocationPermission || _currentLocation == null) {
      _showErrorDialog(localContext, 'Posizione non disponibile o permessi non concessi.');
      return;
    }

    // Mostra wizard
    final info = await _showAddPlaceWizard(localContext);
    if (info == null) return;

    final category = info['category'] as String? ?? 'altro';
    final mediaFile = info['media'] as File?;
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
      imageFile: mediaFile,
    );

    // Salva su Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'uploadedPlaces': FieldValue.arrayUnion([newPlace.id]),
    });

    //Ricarico i dati utente
    await _initUser();

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(newPlace.latitude, newPlace.longitude)),
    );
  }

  // --------------------------------------------------
  // Dettagli di un segnaposto
  // --------------------------------------------------

  /// Mostra il bottomSheet con i dettagli di un segnaposto
  void _showPlaceDetails(Place place) async {
    final localContext = context;

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

    final photoCount = 1;

    // Mostriamo i dettagli in un bottomSheet
    if (!mounted) return;
    showModalBottomSheet(
      context: localContext,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetCtx) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: _buildFixedPlaceCard(place, username, photoCount, bottomSheetCtx),
        );
      },
    );
  }

  /// Card con i dettagli fissi di un segnaposto
  Widget _buildFixedPlaceCard(
      Place place,
      String username,
      int photoCount,
      BuildContext bottomSheetCtx,
      ) {
    String relativeTime = '';
    if (place.createdAt != null) {
      relativeTime = timeago.format(place.createdAt!);
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    bool isOwner = (place.userId == currentUser?.uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Immagine con icona preferiti e icona categoria in overlay
        Stack(
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: _buildPlaceImage(place),
            ),
            // Icona preferiti
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => debugPrint('Preferito!'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white54,
                  ),
                  child: const Icon(Icons.star_border, color: Colors.black87),
                ),
              ),
            ),
            // Icona categoria
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white70,
                ),
                child: _buildCategoryIcon(place.category),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Nome del segnaposto
        Text(
          place.name,
          style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
        ),

        // Username proprietario
        Text(username, style: const TextStyle(fontSize: 14, color: Colors.black54)),

        const SizedBox(height: 8),

        // Descrizione
        if (place.description != null && place.description!.isNotEmpty)
          Text(place.description!, style: const TextStyle(fontSize: 14)),

        const SizedBox(height: 6),

        // LatLng
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

        // Tempo relativo
        if (relativeTime.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.timer, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text('Caricato $relativeTime',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),

        const Spacer(),

        // Bottone fotoCount e azioni (edit/delete se owner)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('$photoCount di $photoCount',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(width: 12),
            if (isOwner) ...[
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
    );
  }

  /// Crea il widget immagine per un Place (da file o da URL)
  Widget _buildPlaceImage(Place place) {
    if (place.imageFile != null) {
      return Image.file(place.imageFile!, fit: BoxFit.cover);
    } else if (place.imageUrl != null) {
      return Image.network(place.imageUrl!, fit: BoxFit.cover);
    } else {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        ),
      );
    }
  }

  /// Icona corrispondente alla categoria selezionata
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

  /// Modifica un segnaposto esistente
  Future<void> _editPlace(Place place, BuildContext boxContext) async {
    // Chiudiamo prima il bottomSheet per evitare conflitti di context
    Navigator.of(boxContext).pop();

    final localContext = context;
    final info = await _askEditPlaceDialog(localContext, place);
    if (info == null) return;

    final newCategory = info['category'] as String;
    final newTitle = info['title'] as String? ?? '';
    final newDescription = info['description'] as String? ?? '';
    final newImageFile = info['imageFile'] as File?;

    await _placesController.updatePlace(
      placeId: place.id,
      userId: place.userId,
      newTitle: newTitle,
      newDescription: newDescription,
      newCategory: newCategory,
      newImageFile: newImageFile,
    );
  }

  /// Elimina un segnaposto
  Future<void> _deletePlace(Place place, BuildContext boxContext) async {
    // Chiudiamo il bottomSheet
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

  /// Dialog per modificare un segnaposto esistente
  Future<Map<String, dynamic>?> _askEditPlaceDialog(BuildContext localContext, Place place) async {
    String selectedCategory = place.category;
    String? title = place.name;
    String? description = place.description;
    File? pickedImage;

    return showModalBottomSheet<Map<String, dynamic>>(
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
                    // Scelta categoria
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
                    // Titolo
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Titolo',
                              style:
                              TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          TextField(
                            controller: TextEditingController(text: title),
                            onChanged: (val) => title = val,
                            decoration:  InputDecoration(
                              // hintText: '',
                              //hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
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
                    // Descrizione
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Descrizione',
                              style:
                              TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          TextField(
                            controller: TextEditingController(text: description),
                            onChanged: (val) => description = val,
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
                    // Seleziona nuova foto
                    ElevatedButton(
                      onPressed: () async {
                        final img = await _placesController.pickImage();
                        if (img != null) {
                          setStateSB(() => pickedImage = img);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Theme.of(localContext).colorScheme.primary,
                      ),
                      child: const Text('Seleziona Nuova Foto', style: TextStyle(color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                    ),
                    // Mostra anteprima
                    if (pickedImage != null) ...[
                      const SizedBox(height: 8),
                      Image.file(pickedImage!, height: 100, fit: BoxFit.cover),
                    ] else if (place.imageFile != null) ...[
                      const SizedBox(height: 8),
                      Image.file(place.imageFile!, height: 100, fit: BoxFit.cover),
                    ] else if (place.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      Image.network(place.imageUrl!, height: 100, fit: BoxFit.cover),
                    ],
                    const SizedBox(height: 16),
                    // Pulsanti Annulla/Salva
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Annulla',
                              style: TextStyle(color: Colors.red, fontSize: 18)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop({
                              'category': selectedCategory,
                              'title': title,
                              'description': description,
                              'imageFile': pickedImage,
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
  }

  // --------------------------------------------------
  // Barra di ricerca e autocomplete
  // --------------------------------------------------

  /// Apre/chiude la barra di ricerca
  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        // Se chiudiamo la barra, resettiamo il testo e i suggerimenti
        _searchController.clear();
        _predictions.clear();
      }
    });
  }

  /// Funzione per ottenere i suggerimenti di autocomplete
  Future<void> _getAutocomplete(String input) async {
    if (input.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    final endpoint =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$input'
        '&types=(cities)'  // Rimuovi se vuoi cercare generico
        '&language=it'
        '&key=$_placesApiKey';

    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];
        if (status == 'OK') {
          final List predictions = data['predictions'];
          setState(() {
            _predictions = predictions.map<Map<String, dynamic>>((p) => {
              'description': p['description'],
              'place_id': p['place_id'],
            }).toList();
          });
        } else {
          debugPrint('Autocomplete errore status: $status');
          setState(() => _predictions = []);
        }
      } else {
        debugPrint('HTTP Error (autocomplete): ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore _getAutocomplete: $e');
    }
  }

  /// Richiede le coordinate di un place dall'API e sposta la mappa
  Future<void> _goToPlace(String placeId) async {
    final detailsUrl =
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&key=$_placesApiKey';

    try {
      final response = await http.get(Uri.parse(detailsUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final geometry = data['result']['geometry'];
          final loc = geometry['location'];
          final lat = loc['lat'];
          final lng = loc['lng'];

          // Sposta la mappa
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(LatLng(lat, lng)),
          );
        } else {
          debugPrint('Place Details errore: ${data['status']}');
        }
      } else {
        debugPrint('HTTP Error (details): ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore _goToPlace: $e');
    }
  }

  // --------------------------------------------------
  // UI Principale (build)
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // La UI reagisce a changes di _placesController
    return AnimatedBuilder(
      animation: _placesController,
      builder: (context, _) {
        return Scaffold(
          drawer: _buildDrawer(),
          body: Stack(
            children: [
              // Se stiamo caricando...
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                _buildGoogleMap(),

              // Se la barra di ricerca è chiusa, mostra il menu e l'icona search
              if (!_showSearchBar) ...[
                _buildMenuButton(),
                Positioned(
                  top: 80.0,
                  right: 16.0,
                  child: GestureDetector(
                    onTap: _toggleSearchBar,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(51), // ~0.2
                            spreadRadius: 2,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.search, color: Colors.black),
                    ),
                  ),
                ),
              ],

              // Se la barra di ricerca è aperta, mostriamo la textField e i suggerimenti
              if (_showSearchBar)
                Positioned(
                  top: 80.0,
                  left: 16.0,
                  right: 16.0,
                  child: Column(
                    children: [
                      // Barra di ricerca
                      Container(
                        height: 56.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(51),
                              spreadRadius: 2,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.black),
                                decoration: const InputDecoration(
                                  hintText: 'Cerca ...',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (value) {
                                  if (value.length > 2) {
                                    _getAutocomplete(value);
                                  } else {
                                    setState(() => _predictions = []);
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.black),
                              onPressed: _toggleSearchBar,
                            ),
                          ],
                        ),
                      ),

                      // Lista di suggerimenti
                      if (_predictions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(51),
                                spreadRadius: 2,
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _predictions.length,
                            itemBuilder: (ctx, i) {
                              final item = _predictions[i];
                              final description = item['description'] as String;
                              final placeId = item['place_id'] as String;
                              return ListTile(
                                dense: true,
                                contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                title: Text(
                                  description,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                onTap: () async {
                                  // Vai alle coordinate di questo place
                                  await _goToPlace(placeId);
                                  // Reset ricerche
                                  setState(() {
                                    _predictions.clear();
                                    _searchController.clear();
                                    _toggleSearchBar();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

              // Pulsanti floating in basso a destra
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bottone per centrare la mappa sull'utente
                    FloatingActionButton(
                      heroTag: 'btnLocation',
                      onPressed: () {
                        final localContext = context;
                        if (_hasLocationPermission) {
                          _moveCameraToCurrentLocation();
                        } else {
                          _showSettingsDialog(localContext);
                        }
                      },
                      backgroundColor: Theme.of(context).colorScheme.onPrimary,
                      child: Icon(
                        Icons.my_location,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bottone per aggiungere un segnaposto sulla mia posizione
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
      },
    );
  }

  /// Costruisce la GoogleMap
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

  /// Costruisce il pulsante di apertura Drawer (Menù)
  Widget _buildMenuButton() {
    return Positioned(
      top: 80.0,
      left: 16.0,
      child: Builder(
        builder: (context) => GestureDetector(
          onTap: () => Scaffold.of(context).openDrawer(),
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
            child: const Icon(Icons.menu, color: Colors.black),
          ),
        ),
      ),
    );
  }

  /// Drawer con le varie voci (Profilo, Impostazioni, etc.)
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.primary,
        child: Column(
          children: [
            // Header con logo
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flight_takeoff, color: Colors.white, size: 48),
                  const SizedBox(height: 10),
                  Text(
                    'Altura',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Voci di menu
            ListTile(
              leading: const Icon(Icons.account_circle_outlined,
                  color: Colors.white, size: 28),
              title: const Text('Profilo',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/profile_page', arguments: _appUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white, size: 28),
              title: const Text('Impostazioni',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/settings_page');
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(color: Colors.white70, thickness: 1),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.white, size: 28),
              title: const Text('Assistenza e Supporto',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/support_page');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white, size: 28),
              title: const Text('Informazioni su Altura',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/about_page');
              },
            ),

            // Logout in fondo
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white, size: 28),
                  title: const Text('Logout',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  onTap: signOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}