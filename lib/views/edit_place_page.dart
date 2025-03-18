import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/places_service.dart';

const List<DropdownMenuItem<String>> kCategoryItems = [
  DropdownMenuItem(value: 'pista_decollo', child: Text('Pista di decollo')),
  DropdownMenuItem(value: 'area_volo_libera', child: Text('Area volo libera')),
  DropdownMenuItem(value: 'area_restrizioni', child: Text('Area soggetta a restrizioni')),
  DropdownMenuItem(value: 'punto_ricarica', child: Text('Punto di ricarica')),
  DropdownMenuItem(value: 'altro', child: Text('Altro')),
];

class EditPlacePage extends StatefulWidget {
  final Place place;

  const EditPlacePage({super.key, required this.place});

  @override
  State<EditPlacePage> createState() => _EditPlacePageState();
}

class _EditPlacePageState extends State<EditPlacePage> {
  // Gestione campi
  late String _selectedCategory;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Media esistenti (sia file locali che URL remoti)
  final List<File> _existingMediaFiles = [];
  final List<String> _existingMediaUrls = [];

  // Nuovi media selezionati
  final List<File> _pickedMedia = [];

  // Controller per la selezione dei media
  final PlacesController _placesController = PlacesController();

  @override
  void initState() {
    super.initState();

    // Inizializziamo i campi con i dati esistenti del segnaposto
    _selectedCategory = widget.place.category;
    _titleController.text = widget.place.name;
    _descriptionController.text = widget.place.description ?? '';

    // Popoliamo le liste con i media esistenti
    if (widget.place.mediaFiles != null && widget.place.mediaFiles!.isNotEmpty) {
      _existingMediaFiles.addAll(widget.place.mediaFiles!);
    }
    if (widget.place.mediaUrls != null && widget.place.mediaUrls!.isNotEmpty) {
      _existingMediaUrls.addAll(widget.place.mediaUrls!);
    }
  }

  /// Seleziona nuovi media da galleria/fotocamera
  Future<void> _pickNewMedia() async {
    final media = await _placesController.pickMedia();
    if (media != null && media.isNotEmpty) {
      setState(() {
        _pickedMedia.addAll(media);
      });
    }
  }

  /// Elimina un media esistente (URL o file) dalla lista
  void _removeExistingMedia(int index, bool isUrl) {
    setState(() {
      if (isUrl) {
        _existingMediaUrls.removeAt(index);
      } else {
        _existingMediaFiles.removeAt(index);
      }
    });
  }

  /// Elimina un media appena aggiunto
  void _removePickedMedia(int index) {
    setState(() {
      _pickedMedia.removeAt(index);
    });
  }

  /// Annulla la modifica e torna alla pagina precedente
  void _cancelEdit() {
    Navigator.of(context).pop(null);
  }

  /// Salva le modifiche e torna con i dati aggiornati
  void _saveEdit() {
    // Per la logica di salvataggio, potresti unire le due liste di media esistenti
    // e quelle nuove, oppure passare entrambe per poi gestirle nel tuo controller.
    // In questo esempio passiamo solo i NUOVI media, come da codice originale.
    // Se vuoi anche aggiornare la rimozione dei media esistenti, devi gestirlo
    // nel tuo `updatePlace`, ad esempio passando un "existingMediaToRemove".
    Navigator.of(context).pop({
      'category': _selectedCategory,
      'title': _titleController.text,
      'description': _descriptionController.text,
      'media': _pickedMedia,
      // Esempio: potresti passare anche le liste aggiornate:
      // 'remainingUrls': _existingMediaUrls,
      // 'remainingFiles': _existingMediaFiles,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.place.userId == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        elevation: 0,
        title: Text(
          'Impostazioni',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                // Logica per eliminare il segnaposto (opzionale)
                debugPrint('Elimina segnaposto');
              },
            )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1) Media esistenti (con "X" per eliminarli)
              if (_existingMediaFiles.isNotEmpty || _existingMediaUrls.isNotEmpty) ...[
                const Text(
                  'Media caricati',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Mostra i file locali esistenti
                      for (int i = 0; i < _existingMediaFiles.length; i++)
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _existingMediaFiles[i],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removeExistingMedia(i, false),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      // Mostra i link remoti esistenti
                      for (int i = 0; i < _existingMediaUrls.length; i++)
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _existingMediaUrls[i],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removeExistingMedia(i, true),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 2) Pulsante per aggiungere nuovi media
              ElevatedButton(
                onPressed: _pickNewMedia,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text(
                  'Aggiungi nuovi media',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),

              // Anteprima dei nuovi media
              if (_pickedMedia.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedMedia.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _pickedMedia[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _removePickedMedia(index),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // 3) Campo titolo
              const Text(
                'Titolo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4) Campo descrizione
              const Text(
                'Descrizione',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5) Campo categoria (UI migliorata con DropdownButtonFormField)
              const Text(
                'Categoria',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: kCategoryItems,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                  }
                },
              ),
              const SizedBox(height: 24),

              // 6) Pulsanti in fondo (Annulla a sinistra in rosso, Salva a destra in blu)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Pulsante Annulla
                  OutlinedButton(
                    onPressed: _cancelEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annulla', style: TextStyle(fontSize: 16)),
                  ),

                  // Pulsante Salva
                  ElevatedButton(
                    onPressed: _saveEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Salva',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
