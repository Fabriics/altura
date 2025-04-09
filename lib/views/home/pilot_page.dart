import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/pilot_service.dart';

class PilotPage extends StatefulWidget {
  const PilotPage({super.key});

  @override
  State<PilotPage> createState() => _PilotPageState();
}

class _PilotPageState extends State<PilotPage> {
  final PilotService _service = PilotService();
  bool _showFilters = false;
  double _sliderValue = 30;
  bool _sortByDistance = false;
  bool _certifiedOnly = false;
  // Impostato a true per mostrare solo i piloti disponibili
  final bool _availableOnly = true;

  @override
  void initState() {
    super.initState();
    _service.fetchUserLocationAndPilots();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piloti'),
        actions: [
          TextButton(
            onPressed: () async {
              // Sostituisci "USER_ID" con l'ID reale dell'utente corrente
              await _service.setCurrentUserAvailable("USER_ID");
            },
            child: const Text(
              'Diventa disponibile',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.close : Icons.filter_alt_outlined),
            onPressed: () => setState(() {
              _showFilters = !_showFilters;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.all(8.0),
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
                    onChanged: (value) {
                      setState(() => _sliderValue = value);
                    },
                    onChangeEnd: (_) => _applyFilters(),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _certifiedOnly,
                        onChanged: (value) {
                          setState(() => _certifiedOnly = value ?? false);
                          _applyFilters();
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
                          setState(() => _sortByDistance = value ?? false);
                          _applyFilters();
                        },
                      ),
                      const Text("Ordina per distanza / esperienza"),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _service.pilotStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final pilots = snapshot.data!;
                return ListView.builder(
                  itemCount: pilots.length,
                  itemBuilder: (context, index) {
                    final pilot = pilots[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (pilot.profileImageUrl != null &&
                            pilot.profileImageUrl!.isNotEmpty)
                            ? NetworkImage(pilot.profileImageUrl!)
                            : null,
                        child: (pilot.profileImageUrl == null ||
                            pilot.profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(pilot.username),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            children: pilot.dronesList
                                .map((d) => Chip(label: Text(d)))
                                .toList(),
                          ),
                          if (pilot.bio != null) Text(pilot.bio!),
                          if (pilot.distanceKm != null)
                            Text("Distanza: ${pilot.distanceKm!.toStringAsFixed(1)} km"),
                          Text("Esperienza: ${pilot.flightExperience ?? 0} anni"),
                          Text(
                            pilot.isCertified == true ? "Certificato" : "Non certificato",
                            style: TextStyle(
                                color: pilot.isCertified == true ? Colors.green : Colors.red),
                          ),
                          Text(
                            pilot.isAvailable == true ? "Disponibile" : "Non disponibile",
                            style: TextStyle(
                                color: pilot.isAvailable == true ? Colors.green : Colors.red),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.message),
                      onTap: () {
                        // Logica per contattare il pilota
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
