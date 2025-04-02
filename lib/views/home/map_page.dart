import 'dart:io';

import 'package:altura/views/home/place_details_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;


import '../../models/place_model.dart';
import '../../services/altura_loader.dart';
import '../../services/map_service.dart';
import '../../services/place_controller.dart';


class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  late final MapService _mapService;
  late final PlacesController _placesController;

  // Variabili di stato locali per la UI
  LatLng? _centerPosition;
  bool _selectingPosition = false;
  Place? _selectedPlace;
  String _selectedUsername = 'Sconosciuto';
  int _selectedLikeCount = 0;
  String? _selectedProfileImageUrl; // Immagine del profilo

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
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      setState(() {
        // Qui potresti aggiornare il modello utente, se necessario
      });
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

  /// Wizard a 2 step per la creazione di un segnaposto.
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
            void goNextStep() {
              if (currentStep == 0 && selectedCategory == null) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('Seleziona una categoria')));
                return;
              }
              setStateSB(() => currentStep = 1);
            }

            void goPreviousStep() {
              setStateSB(() => currentStep = 0);
            }

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (currentStep == 1)
                            IconButton(
                              onPressed: goPreviousStep,
                              icon: const Icon(Icons.arrow_back, color: Colors.black),
                            )
                          else
                            const SizedBox(width: 48),
                          Text(
                            stepLabel,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
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
                                activeColor: Theme.of(localContext).colorScheme.primary,
                                value: 'pista_decollo',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text('Area volo libera', style: TextStyle(color: Colors.black)),
                                activeColor: Theme.of(localContext).colorScheme.primary,
                                value: 'area_volo_libera',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text('Area soggetta a restrizioni', style: TextStyle(color: Colors.black)),
                                activeColor: Theme.of(localContext).colorScheme.primary,
                                value: 'area_restrizioni',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text('Punto di ricarica', style: TextStyle(color: Colors.black)),
                                activeColor: Theme.of(localContext).colorScheme.primary,
                                value: 'punto_ricarica',
                                groupValue: selectedCategory,
                                onChanged: (val) => setStateSB(() => selectedCategory = val),
                              ),
                              RadioListTile(
                                title: const Text('Altro', style: TextStyle(color: Colors.black)),
                                activeColor: Theme.of(localContext).colorScheme.primary,
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
                            color: Theme.of(localContext).colorScheme.primary,
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
                                        child: GestureDetector(
                                          onTap: () => setStateSB(() {
                                            chosenMedia.removeAt(index);
                                          }),
                                          child: const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.black54,
                                            child: Icon(Icons.close, size: 16, color: Colors.white),
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
                            minLines: 3,
                            maxLines: 20,
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
                        )
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

  void _showPlaceDetails(Place place) async {
    String username = 'Sconosciuto';
    String? profileImageUrl; // variabile locale per l'immagine del profilo
    int likeCount = 0; // variabile per il conteggio dei like

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

    // Recupera il likeCount dal documento del segnaposto.
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
      _selectedProfileImageUrl = profileImageUrl; // salva anche l'immagine profilo (potrà essere vuota)
      _selectedLikeCount = likeCount; // salva il conteggio dei like
    });
  }

  Widget _buildFixedPlaceCard(Place place, String username, int likeCount) {
    //final bool isOwner = place.userId == FirebaseAuth.instance.currentUser?.uid;
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
                    Text(
                      place.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (place.description != null && place.description!.isNotEmpty)
                      Text(
                        place.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
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
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('$likeCount', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    )
                  ],
                ),
              )
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
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_mapService.isLoading) const Center(child: AlturaLoader()) else GoogleMap(
            onMapCreated: (controller) {
              _mapService.mapController = controller;
            },
            onCameraMove: (pos) {
              if (!_selectingPosition) {
                _centerPosition = pos.target;
              }
            },
            myLocationEnabled: _mapService.hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: CameraPosition(
              target: _mapService.hasLocationPermission && _mapService.currentLocation != null
                  ? LatLng(
                _mapService.currentLocation!.latitude!,
                _mapService.currentLocation!.longitude!,
              )
                  : _mapService.defaultPosition,
              zoom: 14.0,
            ),
            onTap: (_) => setState(() => _selectedPlace = null),
            markers: () {
              final markersSet = _placesController.markers.map((marker) {
                return marker.copyWith(
                  onTapParam: () {
                    final place = _placesController.places.firstWhere((p) => p.id == marker.markerId.value);
                    _showPlaceDetails(place);
                  },
                );
              }).toSet();
              if (_selectingPosition) {
                final tempMarker = Marker(
                  markerId: const MarkerId('tempMarker'),
                  position: _centerPosition ??
                      (_mapService.hasLocationPermission && _mapService.currentLocation != null
                          ? LatLng(
                        _mapService.currentLocation!.latitude!,
                        _mapService.currentLocation!.longitude!,
                      )
                          : _mapService.defaultPosition),
                  draggable: true,
                  onDragEnd: (newPosition) {
                    setState(() {
                      _centerPosition = newPosition;
                    });
                  },
                );
                markersSet.add(tempMarker);
              }
              return markersSet;
            }(),
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
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
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
                            await _mapService.addMarkerAtPosition(
                              latLng: _centerPosition!,
                              context: context,
                              showAddPlaceWizard: () => _showAddPlaceWizard(context),
                              initUser: _initUser,
                            );
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
          if (_selectedPlace != null)
            Positioned(
              bottom: 5,
              left: 16,
              right: 16,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Center(child: mediaWidget),
    );
  }
}
