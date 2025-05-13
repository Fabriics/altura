import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../models/place_model.dart';
import '../../../models/user_model.dart';
import '../../../services/map_service.dart';
import '../../../services/place_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Dropdown con categorie (valori univoci)
const List<DropdownMenuItem<String>> kCategoryItems = [
  DropdownMenuItem(value: "Spazio aperto", child: Text("Spazio aperto")),
  DropdownMenuItem(value: "Zona urbana", child: Text("Zona urbana")),
  DropdownMenuItem(value: "Zona naturale", child: Text("Zona naturale")),
  DropdownMenuItem(value: "Zona Cinematic", child: Text("Zona Cinematic")),
  DropdownMenuItem(value: "Zona freestyle", child: Text("Zona freestyle")),
  DropdownMenuItem(value: "Zona Indoor", child: Text("Zona Indoor")),
  DropdownMenuItem(value: "Zona NoFLy", child: Text("Zona NoFLy")),
  DropdownMenuItem(value: "Zona Panoramica", child: Text("Zona Panoramica")),
  DropdownMenuItem(value: "Racing", child: Text("Racing")),
  DropdownMenuItem(value: "Altro", child: Text("Altro")),
];

class EditPlacePage extends StatefulWidget {
  final Place place;
  const EditPlacePage({super.key, required this.place});

  @override
  State<EditPlacePage> createState() => _EditPlacePageState();
}

class _EditPlacePageState extends State<EditPlacePage> {
  late String _selectedCategory;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Liste per media esistenti e nuovi media aggiunti.
  final List<File> _existingMediaFiles = [];
  final List<String> _existingMediaUrls = [];
  final List<File> _pickedMedia = [];

  final PlacesController _placesController = PlacesController();
  late final MapService _mapService;

  // Variabili per il profilo del proprietario del posto.
  String _username = 'Sconosciuto';
  String? _profileImageUrl;
  AppUser? _appUser;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.place.category;
    if (!kCategoryItems.any((item) => item.value == _selectedCategory)) {
      _selectedCategory = kCategoryItems.first.value!;
    }
    _titleController.text = widget.place.name;
    _descriptionController.text = widget.place.description ?? '';

    if (widget.place.mediaFiles != null && widget.place.mediaFiles!.isNotEmpty) {
      _existingMediaFiles.addAll(widget.place.mediaFiles!);
    }
    if (widget.place.mediaUrls != null && widget.place.mediaUrls!.isNotEmpty) {
      _existingMediaUrls.addAll(widget.place.mediaUrls!);
    }

    _mapService = MapService(placesController: _placesController);
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.place.userId)
          .get();
      if (doc.exists && doc.data() != null) {
        final userData = doc.data() as Map<String, dynamic>;
        setState(() {
          _appUser = AppUser.fromMap(userData);
          _username = _appUser?.username ?? 'Sconosciuto';
          _profileImageUrl = _appUser?.profileImageUrl ?? '';
        });
      }
    } catch (e) {
      debugPrint('Errore nel recuperare i dati utente: $e');
    }
  }

  /// Rimuove un media esistente (file o URL) dalla lista e aggiorna Firebase (mediante PlacesController).
  Future<void> _removeExistingMedia(int index, bool isUrl) async {
    if (isUrl) {
      await _placesController.removeMediaFromPlace(widget.place.id, isUrl: true, index: index);
      setState(() {
        _existingMediaUrls.removeAt(index);
      });
    } else {
      setState(() {
        _existingMediaFiles.removeAt(index);
      });
    }
  }

  /// Rimuove un media appena aggiunto.
  void _removePickedMedia(int index) {
    setState(() {
      _pickedMedia.removeAt(index);
    });
  }

  void _cancelEdit() {
    Navigator.of(context).pop(null);
  }

  void _saveEdit() {
    Navigator.of(context).pop({
      'category': _selectedCategory,
      'title': _titleController.text,
      'description': _descriptionController.text,
      'media': _pickedMedia,
    });
  }

  Future<void> _pickNewMedia() async {
    final media = await _placesController.pickMedia();
    if (media != null && media.isNotEmpty) {
      setState(() {
        _pickedMedia.addAll(media);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isOwner = widget.place.userId == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        title: const Text('Modifica segnaposto'),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await _mapService.deletePlace(place: widget.place, context: context);
                // Torna alla MapPage dopo la cancellazione.
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_existingMediaFiles.isNotEmpty || _existingMediaUrls.isNotEmpty) ...[
                Text(
                  'Media caricati',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
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
              ElevatedButton(
                onPressed: _pickNewMedia,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: theme.colorScheme.primary,
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
              Text(
                'Titolo',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor ?? Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Descrizione',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 20,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor ?? Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Categoria',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: kCategoryItems,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor ?? Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  ElevatedButton(
                    onPressed: _saveEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Salva', style: TextStyle(fontSize: 16, color: Colors.white)),
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
