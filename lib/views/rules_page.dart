// lib/views/rules_page.dart
import 'package:flutter/material.dart';

/// Pagina che mostra una lista di regole di volo per ciascun Paese.
/// Puoi sostituire [rulesByCountry] con una struttura dati dinamica
/// (es. caricata da Firestore, JSON locale o API esterna).
class RulesPage extends StatefulWidget {
  const RulesPage({Key? key}) : super(key: key);

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  // Esempio di regole di volo per paese
  // Puoi estendere la struttura come preferisci, ad esempio
  // usando un oggetto con più campi (distanze, altitudini consentite, ecc.)
  final Map<String, String> rulesByCountry = {
    'Italia': '1. Non volare sopra i 120m.\n2. Mantenere VLOS.\n3. No fly zone vicino aeroporti.\n4. Registrazione ENAC obbligatoria.',
    'Stati Uniti': '1. FAA Part 107.\n2. Registrazione droni > 250g.\n3. VLOS richiesto.\n4. No fly zone intorno a stadi, eventi, aeroporti.',
    'Francia': '1. Massimo 150m di altitudine.\n2. Divieto di sorvolo su aree affollate.\n3. Richiesta assicurazione RC.\n4. Rispettare le CTR militari.',
    'Spagna': '1. Altitudine massima 120m.\n2. Divieto di volo su zone urbane senza permesso.\n3. Registrazione AESA.\n4. Mantenere drone in VLOS.',
    'Germania': '1. Max 100m di altitudine.\n2. VLOS.\n3. Divieto di volo sopra infrastrutture sensibili.\n4. Registrazione LBA se > 2kg.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profilo'
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        // Pulsante in alto a destra per modificare il profilo
      ),
      body: ListView.builder(
        itemCount: rulesByCountry.length,
        itemBuilder: (context, index) {
          final country = rulesByCountry.keys.elementAt(index);
          final rules = rulesByCountry[country];

          return ExpansionTile(
            title: Text(country, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(rules ?? ''),
              ),
            ],
          );
        },
      ),
    );
  }
}
