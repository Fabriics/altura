// lib/views/professionals_page.dart

import 'package:flutter/material.dart';

/// Pagina di esempio per la ricerca e contatto con piloti professionisti.
class ProfessionalsPage extends StatelessWidget {
  const ProfessionalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professionisti'),
      ),
      body: const Center(
        child: Text(
          'Qui potrai cercare e metterti in contatto con piloti professionisti.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
