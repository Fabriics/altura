import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// geolocator per ottenere coordinate e permessi
import 'package:geolocator/geolocator.dart';
// geocoding per fare reverse geocoding (lat/long -> isoCountryCode, etc.)
import 'package:geocoding/geocoding.dart' as geo;

class RulesPage extends StatefulWidget {
  const RulesPage({Key? key}) : super(key: key);

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  /// Indica se stiamo caricando dati o meno
  bool _isLoading = true;

  /// Se c’è stato un errore generico
  bool _hasError = false;

  /// Messaggio di errore (se presente)
  String? _errorMessage;

  /// Indica se l’utente ha un account premium
  bool _isPremium = false;

  /// Se l’utente NON è premium, mostriamo solo la regola del suo paese
  String? _countryCode;
  Map<String, dynamic>? _countryData;

  /// Se l’utente è premium, carichiamo tutte le regole
  List<Map<String, dynamic>> _allRules = [];

  @override
  void initState() {
    super.initState();
    _initLogic();
  }

  /// Funzione principale che:
  /// 1) Ottiene la posizione utente (via Geolocator)
  /// 2) Fa reverse geocoding per scoprire isoCountryCode (es. "IT")
  /// 3) Carica i dati da Firestore (solo il paese, oppure tutti se premium)
  Future<void> _initLogic() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // 1) Otteniamo la posizione utente
      final position = await _getUserPosition();

      // 2) Reverse geocoding: otteniamo la isoCountryCode
      final code = await _getCountryCodeFromCoords(position.latitude, position.longitude);
      if (code == null) {
        throw Exception("Impossibile determinare il Paese dalla tua posizione.");
      }
      _countryCode = code; // Esempio: "IT", "US", "FR", ecc.

      // 3) Carichiamo le regole da Firestore
      if (_isPremium) {
        // Carichiamo TUTTI i doc
        await _loadAllRules();
      } else {
        // Carichiamo solo quello corrispondente a _countryCode
        await _loadRuleForCountry(_countryCode!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Ottiene la posizione utente usando Geolocator,
  /// gestendo i permessi e il servizio di localizzazione.
  Future<Position> _getUserPosition() async {
    // Verifica se i servizi di localizzazione sono attivi
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Se non lo sono, possiamo avvisare l'utente o lanciare eccezione
      throw Exception("Servizio di localizzazione disabilitato sul dispositivo.");
    }

    // Verifica i permessi
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Richiedi permessi
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Permesso di localizzazione negato dall'utente.");
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Permesso di localizzazione negato permanentemente.");
    }

    // A questo punto i permessi sono concessi
    // Recuperiamo la posizione effettiva
    return await Geolocator.getCurrentPosition();
  }

  /// Converte lat/lng -> isoCountryCode (es. "IT") usando geocoding
  Future<String?> _getCountryCodeFromCoords(double lat, double lng) async {
    final placemarks = await geo.placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return null;
    final place = placemarks.first;
    return place.isoCountryCode; // Esempio: "IT"
  }

  /// Carica tutti i documenti della collezione "flight_rules" da Firestore
  Future<void> _loadAllRules() async {
    final querySnap = await FirebaseFirestore.instance
        .collection('flight_rules')
        .get();

    _allRules = querySnap.docs.map((doc) {
      final data = doc.data();
      return {
        'countryCode': doc.id,
        ...data,
      };
    }).toList();
  }

  /// Carica il singolo documento corrispondente a [code] (isoCountryCode)
  Future<void> _loadRuleForCountry(String code) async {
    final docSnap = await FirebaseFirestore.instance
        .collection('flight_rules')
        .doc(code)
        .get();

    if (!docSnap.exists) {
      throw Exception("Nessuna regola trovata per $code");
    }
    _countryData = {
      'countryCode': docSnap.id,
      ...docSnap.data()!,
    };
  }

  @override
  Widget build(BuildContext context) {
    // 1) Se stiamo caricando
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Regole di Volo")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 2) Se c'è un errore
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text("Regole di Volo")),
        body: Center(
          child: Text(
            _errorMessage ?? "Errore sconosciuto",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 3) Se l’utente NON è premium -> mostriamo la regola di un singolo Paese
    if (!_isPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Regole di Volo"),
          centerTitle: true,
        ),
        body: _buildCountryCard(_countryData!),
      );
    }

    // 4) Se l'utente è premium -> mostriamo la lista di tutti i Paesi
    return Scaffold(
      appBar: AppBar(
        title: const Text("Regole di Volo (Premium)"),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: _allRules.length,
        itemBuilder: (context, index) {
          final item = _allRules[index];
          return _buildCountryCard(item);
        },
      ),
    );
  }

  /// Costruisce una card “moderna” con le info del Paese:
  /// - Nome Paese
  /// - Autorità
  /// - Altitudine max
  /// - Link ufficiale
  /// - e ovviamente le regole
  Widget _buildCountryCard(Map<String, dynamic> data) {
    final countryName = data['countryName'] ?? data['countryCode'];
    final rules = data['rules'] ?? 'Nessuna regola disponibile.';
    final authority = data['authorityName'] ?? 'N/A';
    final maxAlt = data['maxAltitude']?.toString() ?? 'N/A';
    final officialLink = data['officialLink'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome del Paese
            Text(
              countryName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Riga con Autorità e altitudine massima
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text("Autorità: $authority"),
                const Spacer(),
                const Icon(Icons.flight_takeoff, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text("Max Alt: $maxAlt m"),
              ],
            ),
            const SizedBox(height: 12),

            // Testo delle regole
            Text(
              rules,
              style: const TextStyle(fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 12),

            // Link ufficiale, se presente
            if (officialLink != null && officialLink.isNotEmpty)
              InkWell(
                onTap: () {
                  // Apri link nel browser (es. con url_launcher)
                  // Esempio:
                  // launchUrl(Uri.parse(officialLink));
                },
                child: Text(
                  officialLink,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
