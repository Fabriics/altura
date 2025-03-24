import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Campi di testo
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _flightExperienceController = TextEditingController();

  // **Nuovo**: Controller per la località
  final TextEditingController _locationController = TextEditingController();

  // Gestione droni selezionati
  final Set<String> _selectedDrones = {};
  final List<String> _availableDrones = [
    'DJI Mini 3 Pro',
    'DJI FPV',
    'Cinelog 25',
    '5-pollici Freestyle',
    '7-pollici Long Range',
    'Altro',
  ];

  // URL dell’immagine profilo attuale
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Carica i dati utente da Firestore e popola i campi del form
  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _instagramController.text = data['instagram'] ?? '';
          _youtubeController.text = data['youtube'] ?? '';
          _flightExperienceController.text =
          (data['flightExperience']?.toString() ?? '');
          _profileImageUrl = data['profileImageUrl'];

          // Se esiste la località salvata, la mettiamo nel controller
          _locationController.text = data['location'] ?? '';

          // Se esiste la lista droni salvata, la aggiungiamo al set
          if (data['drones'] != null) {
            final List<dynamic> droneList = data['drones'];
            for (var d in droneList) {
              _selectedDrones.add(d.toString());
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Errore nel recupero dei dati utente: $e');
    }
  }

  /// Permette all’utente di selezionare o sostituire la foto profilo
  Future<void> _uploadProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        final File imageFile = File(pickedFile.path);

        // Carichiamo l'immagine su Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$uid.jpg');
        final uploadTask = storageRef.putFile(imageFile);

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Aggiorniamo l'URL dell'immagine in Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profileImageUrl': downloadUrl,
        });

        setState(() {
          _profileImageUrl = downloadUrl;
        });
      } catch (e) {
        debugPrint('Errore durante il caricamento della foto profilo: $e');
      }
    }
  }

  /// Aggiorna i campi del profilo su Firestore
  Future<void> _updateProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final profileData = {
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'website': _websiteController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'youtube': _youtubeController.text.trim(),
        'flightExperience': int.tryParse(_flightExperienceController.text) ?? 0,
        'drones': _selectedDrones.toList(),
        // **Nuovo**: Aggiorniamo la località
        'location': _locationController.text.trim(),
      };

      // Aggiorna i campi sul documento utente
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(profileData);

      // Torna alla pagina precedente (es. ProfilePage)
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Errore nell\'aggiornamento del profilo: $e');
    }
  }

  /// Mostra un dialog per selezionare i droni da una lista
  void _showDroneSelectionDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            "Seleziona i tuoi droni",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: _availableDrones.map((drone) {
                return CheckboxListTile(
                  title: Text(
                    drone,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  value: _selectedDrones.contains(drone),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedDrones.add(drone);
                      } else {
                        _selectedDrones.remove(drone);
                      }
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                  checkColor: Theme.of(context).colorScheme.onPrimary,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Chiudi",
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  /// Costruisce un TextFormField generico
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[200],
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        prefixIcon:
        icon != null ? Icon(icon, color: Theme.of(context).colorScheme.primary) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Rilasciamo i controller
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _flightExperienceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // AppBar con titolo e pulsante "Salva"
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Modifica Profilo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              // Salva le modifiche
              if (_formKey.currentState?.validate() ?? false) {
                await _updateProfile();
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Sezione foto profilo
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                        (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                            ? NetworkImage(_profileImageUrl!)
                            : null,
                        child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                            ? Icon(
                          Icons.person,
                          size: 60,
                          color: theme.colorScheme.onSurface,
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: GestureDetector(
                          onTap: _uploadProfileImage,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Username
                _buildTextField(
                  controller: _usernameController,
                  labelText: "Username",
                  hintText: "Inserisci il tuo username",
                  icon: Icons.person,
                ),
                const SizedBox(height: 24),

                // Biografia
                _buildTextField(
                  controller: _bioController,
                  labelText: "Biografia",
                  hintText: "Scrivi una breve biografia su di te",
                  icon: Icons.info,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // **Nuovo**: Località
                _buildTextField(
                  controller: _locationController,
                  labelText: "Località",
                  hintText: "Es. Roma, Italia",
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 24),

                // Selezione droni
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "I tuoi droni:",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: _selectedDrones.map((drone) {
                    return Chip(
                      label: Text(drone),
                      deleteIcon: Icon(Icons.close, color: theme.colorScheme.primary),
                      onDeleted: () {
                        setState(() => _selectedDrones.remove(drone));
                      },
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(color: theme.colorScheme.primary),
                    );
                  }).toList(),
                ),
                ElevatedButton(
                  onPressed: _showDroneSelectionDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("Scegli i droni"),
                ),
                const SizedBox(height: 24),

                // Sito Web
                _buildTextField(
                  controller: _websiteController,
                  labelText: "Sito Web",
                  hintText: "https://iltuosito.com",
                  icon: Icons.web,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),

                // Instagram
                _buildTextField(
                  controller: _instagramController,
                  labelText: "Instagram",
                  hintText: "@iltuonomeutente",
                  icon: Icons.camera_alt,
                ),
                const SizedBox(height: 24),

                // YouTube
                _buildTextField(
                  controller: _youtubeController,
                  labelText: "Canale YouTube",
                  hintText: "Link al tuo canale YouTube",
                  icon: Icons.video_library,
                ),
                const SizedBox(height: 24),

                // Anni di volo
                _buildTextField(
                  controller: _flightExperienceController,
                  labelText: "Esperienza di volo (Anni)",
                  hintText: "es. 2",
                  icon: Icons.flight,
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 40),

                // Bottone Salva (in alternativa a quello dell'AppBar)
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      await _updateProfile();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    "Salva Modifiche",
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
