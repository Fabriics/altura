import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as lt show LatLng;
import '../../models/place_category.dart';
import '../../services/place_controller.dart';

class AddPlaceService extends StatefulWidget {
  final lt.LatLng latLng;
  const AddPlaceService({super.key, required this.latLng});
  @override
  _AddPlaceServiceState createState() => _AddPlaceServiceState();
}

class _AddPlaceServiceState extends State<AddPlaceService> {
  PlaceCategory? selectedCategory;
  List<File> chosenMedia = [];
  String? title;
  String? description;
  bool requiresPermission = false;
  String? permissionDetails;
  final PlacesController _placesController = PlacesController();

  void _pickMedia() async {
    final media = await _placesController.pickMedia();
    if (media != null && media.isNotEmpty) {
      setState(() {
        chosenMedia.addAll(media);
      });
    }
  }

  void _finish() {
    if (title == null || title!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Il campo Titolo è obbligatorio")),
      );
      return;
    }
    if (description == null || description!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Il campo Descrizione è obbligatorio")),
      );
      return;
    }
    if (chosenMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Caricamento immagine obbligatorio")),
      );
      return;
    }
    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seleziona una categoria")),
      );
      return;
    }
    Navigator.pop(context, {
      'category': selectedCategory!.name,
      'media': chosenMedia,
      'title': title,
      'description': description,
      'latLng': widget.latLng,
      'requiresPermission': requiresPermission,
      'permissionDetails': requiresPermission ? permissionDetails : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aggiungi Segnaposto"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Campo per il titolo
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(6),
                child: TextField(
                  onChanged: (val) => title = val,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  decoration: InputDecoration(
                    labelText: "Titolo",
                    hintText: "Es: Piazza del Duomo",
                    filled: true,
                    fillColor: const Color.fromRGBO(248, 249, 250, 1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Campo per la descrizione
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(8),
                child: TextField(
                  onChanged: (val) => description = val,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  keyboardType: TextInputType.multiline,
                  minLines: 3,
                  maxLines: 20,
                  decoration: InputDecoration(
                    labelText: "Descrizione",
                    hintText: "Es: Descrizione e dettagli del luogo",
                    filled: true,
                    fillColor: const Color.fromRGBO(248, 249, 250, 1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(thickness: 0.7),
              const SizedBox(height: 14),
              Text("Seleziona la Categoria", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              CategoryGridView(
                categories: placeCategories,
                selected: selectedCategory,
                onSelected: (cat) {
                  setState(() { selectedCategory = cat; });
                },
              ),
              const SizedBox(height: 14),
              const Divider(thickness: 0.7),
              const SizedBox(height: 14),
              SwitchListTile(
                value: requiresPermission,
                onChanged: (val) {
                  setState(() => requiresPermission = val);
                },
                title: Text("Richiede un'autorizzazione", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                inactiveTrackColor: Colors.grey[300],
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              if (requiresPermission)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    onChanged: (val) => permissionDetails = val,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Specificare quale autorizzazione",
                      hintText: "Es: ENAC, permesso comunale, luogo privato",
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      filled: true,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const Divider(thickness: 0.7),
              const SizedBox(height: 14),
              // Bottone per selezionare i media
              Container(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickMedia,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.camera_alt, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          chosenMedia.isEmpty ? "Seleziona foto" : "Aggiungi altre immagini",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (chosenMedia.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: chosenMedia.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                chosenMedia[index],
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => chosenMedia.removeAt(index)),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _finish,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  child: const Text("Salva", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
