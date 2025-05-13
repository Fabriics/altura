import 'package:altura/views/home/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:geolocator/geolocator.dart';

import '../../models/user_model.dart';
import '../../services/pilot_service.dart';

class PilotPage extends StatefulWidget {
  const PilotPage({Key? key}) : super(key: key);

  @override
  State<PilotPage> createState() => _PilotPageState();
}

class _PilotPageState extends State<PilotPage> {
  final PilotService _service = PilotService();

  // Flag per alternare la vista fra mappa e lista
  bool _isMapView = false;
  // Flag per mostrare i filtri (visibili solo nella vista lista)
  bool _showFilters = false;
  bool _certifiedOnly = false;
  bool _sortByDistance = false;
  final bool _availableOnly = true;
  double _sliderValue = 30;

  // Controller per lo scroll della lista
  final ScrollController _listScrollController = ScrollController();

  // Per la mappa: pilota selezionato (in caso di tap sul marker)
  AppUser? _selectedPilot;
  // Centro iniziale della mappa (aggiornato con la posizione corrente)
  latLng.LatLng _defaultMapCenter = latLng.LatLng(37.33233141, -122.0312186);

  @override
  void initState() {
    super.initState();
    _initLocation();
    _service.fetchUserLocationAndPilots().catchError((error) {
      debugPrint("Errore nel recuperare la posizione: $error");
    });
  }

  Future<void> _initLocation() async {
    try {
      final Position pos = await Geolocator.getCurrentPosition();
      setState(() {
        _defaultMapCenter = latLng.LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      debugPrint("Errore nel recuperare la mia posizione: $e");
    }
  }

  Future<void> _refreshData() async {
    await _service.fetchUserLocationAndPilots();
  }

  void _applyFilters() {
    _service.applyFilters(
      radius: _sliderValue,
      certifiedOnly: _certifiedOnly,
      availableOnly: _availableOnly,
      droneTypes: [],
      sortByDistance: _sortByDistance,
    );
  }

  void _openUserProfile(AppUser pilot) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(user: pilot)),
    );
  }

  /// Vista mappa: mostra la FlutterMap con i marker aggiornati
  Widget _buildMapView(List<AppUser> pilots) {
    // Costruiamo la lista dei marker
    final List<Marker> markers = [];

    // Marker per la mia posizione (blu)
    markers.add(
      Marker(
        width: 20,
        height: 20,
        point: _defaultMapCenter,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );

    // Marker per ogni pilota (neri)
    markers.addAll(
      pilots
          .where((pilot) => pilot.latitude != null && pilot.longitude != null)
          .map(
            (pilot) => Marker(
          width: 20,
          height: 20,
          point: latLng.LatLng(pilot.latitude!, pilot.longitude!),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPilot = pilot;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
      )
          .toList(),
    );

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _defaultMapCenter,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            ),
            MarkerLayer(markers: markers),
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
        // Preview del pilota selezionato in modalità mappa (senza header)
        if (_selectedPilot != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: (_selectedPilot!.profileImageUrl != null &&
                            _selectedPilot!.profileImageUrl!.isNotEmpty)
                            ? NetworkImage(_selectedPilot!.profileImageUrl!)
                            : null,
                        child: (_selectedPilot!.profileImageUrl == null ||
                            _selectedPilot!.profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 28)
                            : null,
                      ),
                      title: Text(
                        _selectedPilot!.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedPilot!.bio != null)
                            Text(
                              _selectedPilot!.bio!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (_selectedPilot!.distanceKm != null)
                                Text(
                                    "${_selectedPilot!.distanceKm!.toStringAsFixed(1)} km"),
                              const SizedBox(width: 8),
                              if (_selectedPilot!.isCertified == true)
                                const Text("Certificato"),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedPilot = null;
                          });
                        },
                      ),
                      onTap: () {
                        _openUserProfile(_selectedPilot!);
                      },
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (_selectedPilot!.flightExperience != null)
                          Chip(
                              label: Text(
                                  "${_selectedPilot!.flightExperience} h")),
                        if (_selectedPilot!.pilotLevel != null &&
                            _selectedPilot!.pilotLevel!.isNotEmpty)
                          Chip(label: Text(_selectedPilot!.pilotLevel!)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Vista lista: visualizza i filtri e una lista di card con informazioni dell'utente (rimane invariata)
  Widget _buildListView(List<AppUser> pilots) {
    return Column(
      children: [
        if (_showFilters)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Filtra per raggio"),
                    Slider(
                      min: 5,
                      max: 100,
                      divisions: 19,
                      label: "${_sliderValue.toInt()} km",
                      value: _sliderValue,
                      onChanged: (value) =>
                          setState(() => _sliderValue = value),
                      onChangeEnd: (_) => _applyFilters(),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _certifiedOnly,
                          onChanged: (value) {
                            setState(() {
                              _certifiedOnly = value ?? false;
                              _applyFilters();
                            });
                          },
                        ),
                        const Text("Solo piloti certificati"),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _sortByDistance,
                          onChanged: (value) {
                            setState(() {
                              _sortByDistance = value ?? false;
                              _applyFilters();
                            });
                          },
                        ),
                        const Text("Ordina per distanza / esperienza"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              controller: _listScrollController,
              itemCount: pilots.length,
              itemBuilder: (context, index) {
                final pilot = pilots[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: () => _openUserProfile(pilot),
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: (pilot.profileImageUrl != null &&
                          pilot.profileImageUrl!.isNotEmpty)
                          ? NetworkImage(pilot.profileImageUrl!)
                          : null,
                      child: (pilot.profileImageUrl == null ||
                          pilot.profileImageUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 28)
                          : null,
                    ),
                    title: Text(
                      pilot.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pilot.bio != null)
                          Text(
                            pilot.bio!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (pilot.distanceKm != null)
                              Chip(
                                label: Text(
                                  "${pilot.distanceKm!.toStringAsFixed(1)} km",
                                ),
                              ),
                            if (pilot.isCertified == true)
                              Chip(
                                label: const Text("Certificato"),
                                backgroundColor: Colors.blue,
                                labelStyle:
                                const TextStyle(color: Colors.white),
                              ),
                            if (pilot.flightExperience != null)
                              Chip(
                                label: Text("${pilot.flightExperience} h"),
                              ),
                            if (pilot.pilotLevel != null &&
                                pilot.pilotLevel!.isNotEmpty)
                              Chip(label: Text(pilot.pilotLevel!)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piloti'),
        actions: [
          // Pulsante per alternare tra vista mappa e lista
          IconButton(
            icon: Icon(_isMapView ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
                // Chiudiamo la preview se in modalità mappa
                _selectedPilot = null;
              });
            },
          ),
          // Pulsante per mostrare/nascondere i filtri (visibile nella vista lista)
          IconButton(
            icon: Icon(_showFilters ? Icons.close : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _service.pilotStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Errore: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pilots = snapshot.data!;
          return _isMapView ? _buildMapView(pilots) : _buildListView(pilots);
        },
      ),
    );
  }
}
