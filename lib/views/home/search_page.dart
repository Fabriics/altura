import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Import del pacchetto Geolocator
import 'package:geolocator/geolocator.dart';

/// Pagina di ricerca che utilizza Google Places Autocomplete.
/// - Permette di visualizzare ricerche recenti
/// - Suggerisce risultati in base al testo digitato
/// - Integra la posizione dell’utente (via Geolocator) per dare priorità
///   ai risultati vicini (impostando i parametri location & radius nelle query).
class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // Controller per la TextField integrata nella SearchBar
  final TextEditingController _searchController = TextEditingController();

  // Lista di suggerimenti (autocomplete) provenienti da Google
  List<Map<String, dynamic>> _predictions = [];

  // La tua Google Places API Key
  static const _placesApiKey = 'SOSTITUISCI_QUI_CON_LA_TUA_API_KEY';

  // Lista di ricerche recenti (persistite con SharedPreferences)
  late List<String> _recentSearches = [];

  // **Nuovo**: memorizziamo la posizione utente (se disponibile) per migliorare la ricerca
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _initUserPosition(); // Tenta di ottenere la posizione attuale
  }

  /// Carica la lista di ricerche recenti da SharedPreferences.
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final storedList = prefs.getStringList('recentSearches') ?? [];
    setState(() {
      _recentSearches = storedList;
    });
  }

  /// Tenta di ottenere la posizione corrente dell'utente tramite Geolocator,
  /// salvandola in [_userPosition].
  Future<void> _initUserPosition() async {
    // 1) Controlla i permessi
    bool serviceEnabled;
    LocationPermission permission;

    // Verifica se il servizio di geolocalizzazione è attivo
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Se non è abilitato, puoi eventualmente mostrare un dialog o un fallback
      debugPrint('Servizio di localizzazione disabilitato.');
      return;
    }

    // Verifica lo stato dei permessi
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Richiedi i permessi
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permessi negati: usiamo fallback (nessuna posizione)
        debugPrint('Permesso negato dall’utente.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // L'utente ha scelto di non ricevere più richieste di permesso.
      debugPrint('Permesso negato permanentemente. Impossibile usare la posizione.');
      return;
    }

    // 2) Se siamo qui, i permessi sono concessi
    // Otteniamo la posizione attuale
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _userPosition = pos;
        debugPrint('Posizione utente: $_userPosition');
      });
    } catch (e) {
      debugPrint('Eccezione nel recupero posizione: $e');
      // Se vuoi gestire un fallback o avvisare l’utente
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Aggiunge una ricerca ai recenti (salvandola in cima alla lista).
  /// Se la ricerca era già presente, la rimuove e la reinserisce in testa.
  Future<void> _addToRecentSearches(String search) async {
    setState(() {
      _recentSearches.removeWhere((item) => item == search);
      _recentSearches.insert(0, search);

      // Limitiamo a 3 ricerche
      if (_recentSearches.length > 3) {
        _recentSearches.removeLast();
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', _recentSearches);
  }

  /// Rimuove una ricerca in posizione [index], poi salva su disco.
  Future<void> _removeFromRecentSearches(int index) async {
    setState(() {
      _recentSearches.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', _recentSearches);
  }

  /// Ottiene i suggerimenti di autocomplete da Google Places API,
  /// usando come bias la posizione utente (se disponibile).
  Future<void> _getAutocomplete(String input) async {
    // Se l'input è vuoto, svuotiamo i suggerimenti e usciamo
    if (input.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    // Costruiamo la base dell'endpoint
    final buffer = StringBuffer(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=$input'
            '&types=geocode'
            '&language=it'
            '&key=$_placesApiKey'
    );

    // Se abbiamo la posizione utente, aggiungiamo location & radius
    if (_userPosition != null) {
      final lat = _userPosition!.latitude;
      final lng = _userPosition!.longitude;
      // Esempio: 50 km di raggio
      buffer.write('&location=$lat,$lng&radius=50000');
    }

    final url = buffer.toString();
    debugPrint('Autocomplete URL: $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];

        if (status == 'OK') {
          final List predictions = data['predictions'];
          if (!mounted) return;
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
        if (!mounted) return;
        setState(() => _predictions = []);
      }
    } catch (e) {
      debugPrint('Errore _getAutocomplete: $e');
    }
  }

  /// Recupera lat/long di un place e chiude la pagina, restituendoli.
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

          // Torniamo lat/lng alla pagina precedente (ad es. la Home)
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
      // AppBar semplificato
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        title: Text(
          'Cerca luoghi',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Barra di ricerca (Material 3)
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

            // Sezione “RICERCHE RECENTI”
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Visibility(
                visible: _searchController.text.isEmpty && _recentSearches.isNotEmpty,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ricerche recenti:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Lista ricerche recenti
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Tappando sul testo, ripopola la searchbar
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
                                      style: const TextStyle(color: Colors.black, fontSize: 16),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeFromRecentSearches(index),
                                  child: const Icon(Icons.close, color: Colors.black54, size: 20),
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

            // Espandiamo la lista di suggerimenti
            Expanded(
              child: ListView.builder(
                itemCount: _predictions.length,
                itemBuilder: (ctx, index) {
                  final item = _predictions[index];
                  final description = item['description'] as String;
                  final placeId = item['place_id'] as String;

                  return ListTile(
                    title: Text(
                      description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    onTap: () {
                      // Aggiungiamo ai recenti
                      _addToRecentSearches(description);
                      // Recuperiamo lat/lng e torniamo alla Home
                      _goToPlace(placeId);
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
