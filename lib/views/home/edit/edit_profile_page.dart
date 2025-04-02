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

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _flightExperienceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final Set<String> _selectedDrones = {};
  final List<String> _availableDrones = [
    'DJI Mini 3 Pro',
    'DJI FPV',
    'Cinelog 25',
    '5-pollici Freestyle',
    '7-pollici Long Range',
    'Altro',
  ];

  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _instagramController.text = data['instagram'] ?? '';
          _youtubeController.text = data['youtube'] ?? '';
          _flightExperienceController.text = (data['flightExperience']?.toString() ?? '');
          _profileImageUrl = data['profileImageUrl'];
          _locationController.text = data['location'] ?? '';
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

  Future<void> _uploadProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        final File imageFile = File(pickedFile.path);
        final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');
        final uploadTask = storageRef.putFile(imageFile);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

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
        'location': _locationController.text.trim(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).update(profileData);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Errore nell\'aggiornamento del profilo: $e');
    }
  }

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
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

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
        fillColor: Theme.of(context).cardColor,
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        hintStyle: TextStyle(color: Theme.of(context).hintColor),
        prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).colorScheme.primary) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
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
      appBar: AppBar(
        title: Text(
          'Modifica Profilo',
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: theme.colorScheme.onPrimary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                await _updateProfile();
              }
            },
            color: theme.colorScheme.onPrimary,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                          ? Icon(Icons.person, size: 60, color: theme.colorScheme.onSurface)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploadProfileImage,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primary,
                          child: Icon(Icons.camera_alt, color: theme.colorScheme.onPrimary, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                controller: _usernameController,
                labelText: "Username",
                hintText: "Inserisci il tuo username",
                icon: Icons.person,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _bioController,
                labelText: "Su di te",
                hintText: "Scrivi qualcosa su di te...",
                icon: Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _locationController,
                labelText: "Località",
                hintText: "Es. Roma, Italia",
                icon: Icons.location_on,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _flightExperienceController,
                labelText: "Esperienza di volo (anni)",
                hintText: "Es. 2",
                icon: Icons.flight,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _websiteController,
                labelText: "Sito web",
                hintText: "https://iltuosito.com",
                icon: Icons.link,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _instagramController,
                labelText: "Instagram",
                hintText: "@iltuonomeutente",
                icon: Icons.camera_alt_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _youtubeController,
                labelText: "Canale YouTube",
                hintText: "Link al tuo canale",
                icon: Icons.ondemand_video,
              ),
              const SizedBox(height: 16),
              Text(
                "Droni posseduti:",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _selectedDrones.map((drone) {
                  return Chip(
                    label: Text(drone),
                    onDeleted: () => setState(() => _selectedDrones.remove(drone)),
                  );
                }).toList(),
              ),
              TextButton.icon(
                onPressed: _showDroneSelectionDialog,
                icon: const Icon(Icons.add),
                label: const Text("Aggiungi droni"),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    await _updateProfile();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Salva Modifiche",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
