import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:url_launcher/url_launcher.dart';
import '../../services/altura_loader.dart';

class RulesPage extends StatefulWidget {
  const RulesPage({super.key});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPremium = false;
  String? _countryCode;
  Map<String, dynamic>? _countryData;
  List<Map<String, dynamic>> _allRules = [];

  @override
  void initState() {
    super.initState();
    _initLogic();
  }

  Future<void> _initLogic() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final position = await _getUserPosition();
      final code = await _getCountryCodeFromCoords(position.latitude, position.longitude);
      if (code == null) throw Exception("Impossibile determinare il Paese dalla tua posizione.");

      _countryCode = code;

      if (_isPremium) {
        await _loadAllRules();
      } else {
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

  Future<Position> _getUserPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Servizio di localizzazione disabilitato sul dispositivo.");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception("Permesso di localizzazione negato.");
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Permesso di localizzazione negato permanentemente.");
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<String?> _getCountryCodeFromCoords(double lat, double lng) async {
    final placemarks = await geo.placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return null;
    return placemarks.first.isoCountryCode;
  }

  Future<void> _loadAllRules() async {
    final querySnap = await FirebaseFirestore.instance.collection('flight_rules').get();
    _allRules = querySnap.docs.map((doc) {
      final data = doc.data();
      return {
        'countryCode': doc.id,
        ...data,
      };
    }).toList();
  }

  Future<void> _loadRuleForCountry(String code) async {
    final docSnap = await FirebaseFirestore.instance.collection('flight_rules').doc(code).get();
    if (!docSnap.exists) throw Exception("Nessuna regola trovata per $code");

    _countryData = {
      'countryCode': docSnap.id,
      ...docSnap.data()!,
    };
  }

  Widget _buildDisclaimer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(
        "Le informazioni riportate hanno solo valore indicativo e non costituiscono una fonte ufficiale. "
            "Per una corretta interpretazione e applicazione delle normative, si invita a fare sempre riferimento all'autorità aeronautica competente del paese di riferimento.",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLinkButton(String text, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          foregroundColor: Theme.of(context).colorScheme.primary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.link),
        label: Text(text),
      ),
    );
  }

  Widget _buildRegulationCard(Map<String, dynamic> data) {
    final country = data['countryName'] ?? data['countryCode'];
    final flagUrl = data['flag'] ?? "";
    final canFly = data['canFlyRecreational'] == true ? '✅' : '❌';
    final registered = data['registrationRequired'] == true ? '✅' : '❌';
    final patent = data['licenseRequired'] == true ? '✅' : '❌';
    final alt = data['maxAltitude']?.toString() ?? 'N/A';
    final description = data['description'] ?? "";
    final official = data['authorityLink'];
    final whereToFly = data['whereToFly'];
    final registerLink = data['registerAsDroneOperator'];
    final pilotTraining = data['pilotTraining'];
    final requestAuth = data['requestAuthorisation'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (flagUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(flagUrl, width: 50, height: 34, fit: BoxFit.cover),
              ),
            const SizedBox(width: 10),
            Text(
              country,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📌 Volo ricreativo consentito: $canFly"),
              Text("📝 Registrazione obbligatoria: $registered"),
              Text("📄 Richiede attestato: $patent"),
              Text("🛫 Altezza massima: $alt m"),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Descrizione dettagliata",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 24),
        _buildLinkButton("Sito ufficiale dell'autorità", official),
        _buildLinkButton("Dove volare", whereToFly),
        _buildLinkButton("Registrazione come operatore", registerLink),
        _buildLinkButton("Formazione per piloti", pilotTraining),
        _buildLinkButton("Richiedi autorizzazione al volo", requestAuth),
        _buildDisclaimer(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Regole di Volo")),
        body: const Center(child: AlturaLoader()),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text("Regole di Volo")),
        body: Center(child: Text(_errorMessage ?? "Errore sconosciuto")),
      );
    }

    if (!_isPremium) {
      return Scaffold(
        appBar: AppBar(title: const Text("Normativa di volo")),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildRegulationCard(_countryData!),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Normative di volo)")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allRules.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: _buildRegulationCard(_allRules[index]),
        ),
      ),
    );
  }
}
