// lib/views/search_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

/// Pagina di ricerca con UI a "pill" come nello screenshot
class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  // Lista di suggerimenti (autocomplete)
  List<Map<String, dynamic>> _predictions = [];

  // Sostituisci con la tua Google Places API Key
  static const _placesApiKey = 'AIzaSyBB6JMMFw8Vz1MniyHuz4_iN3xQ7QbWbv8';


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Funzione per ottenere i suggerimenti di autocomplete
  Future<void> _getAutocomplete(String input) async {
    // Se l'input è vuoto, svuota i suggerimenti e ritorna
    if (input.isEmpty) {
      if (!mounted) return;
      setState(() => _predictions = []);
      return;
    }

    final endpoint =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$input'
        '&types=geocode'
        '&language=it'
        '&key=$_placesApiKey';

    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];

        if (status == 'OK') {
          final List predictions = data['predictions'];
          if (!mounted) return; // Se il widget è stato smontato, esci
          setState(() {
            _predictions = predictions.map<Map<String, dynamic>>((p) => {
              'description': p['description'],
              'place_id': p['place_id'],
            }).toList();
          });
        } else {
          debugPrint('Autocomplete errore status: $status');
          if (!mounted) return;
          setState(() => _predictions = []);
        }
      } else {
        debugPrint('HTTP Error (autocomplete): ${response.statusCode}');
        // (Facoltativo) Se vuoi svuotare i suggerimenti:
        // if (!mounted) return;
        // setState(() => _predictions = []);
      }
    } catch (e) {
      debugPrint('Errore _getAutocomplete: $e');
    }
  }


  /// funzione per recuperare lat/long di un place e chiudere la pagina
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

          // ritorniamo un lat/lng alla HomePage
          Navigator.pop(context, {'lat': lat, 'lng': lng});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 10,
        title: Text(
            'Cerca posizione',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),

      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // SearchBar di Material 3
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Cerca...',
                // Imposta il colore del testo su nero
                textStyle: WidgetStateProperty.all(
                  const TextStyle(color: Colors.black),
                ),
                leading: const Icon(Icons.search),
                trailing: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _predictions.clear());
                      },
                    ),
                ],
                onChanged: (value) {
                  setState(() {});
                  if (value.length > 1) {
                    _getAutocomplete(value);
                  } else {
                    _predictions.clear();
                  }
                },
              )
            ),

            // Lista di suggerimenti
            Expanded(
              child: ListView.builder(
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final item = _predictions[index];
                  final description = item['description'] as String;
                  final placeId = item['place_id'] as String;

                  return ListTile(
                    title: Text(description, style: Theme.of(context).textTheme.bodyLarge),
                    onTap: () => _goToPlace(placeId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}