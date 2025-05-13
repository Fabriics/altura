import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

/// Pagina di ricerca che utilizza il servizio Nominatim di OpenStreetMap per l'autocomplete.
/// - Visualizza ricerche recenti salvate tramite SharedPreferences.
/// - Suggerisce risultati in base al testo digitato.
/// - Integra la posizione utente (via Geolocator) per dare priorità ai risultati vicini.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // Controller per la SearchBar
  final TextEditingController _searchController = TextEditingController();

  // Lista di suggerimenti (autocomplete) ottenuti da Nominatim
  // Ogni elemento è una mappa con 'description', 'lat' e 'lon'
  List<Map<String, dynamic>> _predictions = [];

  // Lista di ricerche recenti (persistita con SharedPreferences)
  late List<String> _recentSearches = [];

  // Memorizziamo la posizione utente (se disponibile) per migliorare la ricerca
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _initUserPosition(); // Prova a ottenere la posizione attuale
  }

  /// Carica la lista di ricerche recenti da SharedPreferences.
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final storedList = prefs.getStringList('recentSearches') ?? [];
    setState(() {
      _recentSearches = storedList;
    });
  }

  /// Tenta di ottenere la posizione attuale dell'utente tramite Geolocator.
  Future<void> _initUserPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Servizio di localizzazione disabilitato.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permesso negato dall’utente.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Permesso negato permanentemente. Impossibile usare la posizione.');
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _userPosition = pos;
        debugPrint('Posizione utente: $_userPosition');
      });
    } catch (e) {
      debugPrint('Errore nel recupero della posizione: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Aggiunge una ricerca alla lista dei recenti.
  Future<void> _addToRecentSearches(String search) async {
    setState(() {
      _recentSearches.removeWhere((item) => item == search);
      _recentSearches.insert(0, search);
      if (_recentSearches.length > 3) {
        _recentSearches.removeLast();
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', _recentSearches);
  }

  /// Rimuove una ricerca dai recenti.
  Future<void> _removeFromRecentSearches(int index) async {
    setState(() {
      _recentSearches.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', _recentSearches);
  }

  /// Ottiene i suggerimenti di autocomplete da Nominatim.
  /// L'endpoint usato è:
  /// https://nominatim.openstreetmap.org/search?q=<input>&format=json&addressdetails=1
  Future<void> _getAutocomplete(String input) async {
    if (input.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    // Costruiamo l'URL per Nominatim.
    final url = 'https://nominatim.openstreetmap.org/search?q=$input&format=json&addressdetails=1';

    try {
      // È buona pratica aggiungere un User-Agent per le richieste verso Nominatim.
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'YourAppName/1.0 (youremail@example.com)'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _predictions = data.map<Map<String, dynamic>>((item) {
            return {
              'description': item['display_name'],
              'lat': item['lat'],
              'lon': item['lon'],
            };
          }).toList();
        });
      } else {
        debugPrint('HTTP Error (autocomplete): ${response.statusCode}');
        setState(() => _predictions = []);
      }
    } catch (e) {
      debugPrint('Errore _getAutocomplete: $e');
      setState(() => _predictions = []);
    }
  }

  /// Seleziona un luogo dalla lista, recupera latitudine e longitudine, e torna alla pagina precedente.
  Future<void> _goToPlace(Map<String, dynamic> placeItem) async {
    final lat = double.tryParse(placeItem['lat']);
    final lon = double.tryParse(placeItem['lon']);
    if (lat != null && lon != null) {
      Navigator.pop(context, {'lat': lat, 'lng': lon});
    } else {
      debugPrint('Impossibile convertire lat/lng da: $placeItem');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerca luoghi'),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Barra di ricerca
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Cerca luoghi...',
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
              ),
            ),

            // Ricerche recenti (visibili solo se la searchbar è vuota)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Visibility(
                visible: _searchController.text.isEmpty && _recentSearches.isNotEmpty,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ricerche recenti:',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      itemCount: _recentSearches.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (ctx, index) {
                        final searchText = _recentSearches[index];
                        return Container(
                          color: Colors.grey[200],
                          margin: const EdgeInsets.only(bottom: 4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      _searchController.text = searchText;
                                      setState(() {});
                                      if (searchText.length > 1) {
                                        _getAutocomplete(searchText);
                                      } else {
                                        _predictions.clear();
                                      }
                                    },
                                    child: Text(
                                      searchText,
                                      style: const TextStyle(
                                          color: Colors.black, fontSize: 16),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeFromRecentSearches(index),
                                  child: const Icon(Icons.close,
                                      color: Colors.black54, size: 20),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            const Padding(
              padding: EdgeInsets.all(10),
              child: Divider(color: Colors.grey),
            ),

            // Lista dei suggerimenti (autocomplete)
            Expanded(
              child: ListView.builder(
                itemCount: _predictions.length,
                itemBuilder: (ctx, index) {
                  final item = _predictions[index];
                  final description = item['description'] as String;
                  return ListTile(
                    title: Text(
                      description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    onTap: () {
                      _addToRecentSearches(description);
                      _goToPlace(item);
                    },
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
