import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final Set<String> _selectedDrones = {};
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _flightExperienceController = TextEditingController();
  String? _profileImageUrl;

  final List<String> _drones = [
    'DJI Mini 3 Pro',
    'DJI FPV',
    'Cinelog 25',
    '5-pollici Freestyle',
    '7-pollici Long Range',
    'Altro',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        setState(() {
          _usernameController.text = userDoc.get('username') ?? '';
          _profileImageUrl = userDoc.get('profileImageUrl');
        });
      }
    } catch (e) {
      print('Errore nel recupero dei dati utente: $e');
    }
  }

  Future<void> _uploadProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        File imageFile = File(pickedFile.path);

        // Carica l'immagine su Firebase Storage, sovrascrivendo quella esistente
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$uid.jpg');
        UploadTask uploadTask = storageRef.putFile(imageFile);

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // Aggiorna l'URL dell'immagine in Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profileImageUrl': downloadUrl,
        });

        setState(() {
          _profileImageUrl = downloadUrl;
        });
      } catch (e) {
        print('Errore durante il caricamento della foto profilo: $e');
      }
    }
  }

  Future<void> _completeProfile() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      Map<String, dynamic> profileData = {
        'username': _usernameController.text,
        'bio': _bioController.text,
        'website': _websiteController.text,
        'instagram': _instagramController.text,
        'youtube': _youtubeController.text,
        'flightExperience': int.tryParse(_flightExperienceController.text) ?? 0,
        'drones': _selectedDrones.toList(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).update(profileData);

      Navigator.pushNamed(context, '/home_page');
    } catch (e) {
      print('Errore nell\'aggiornamento del profilo: $e');
    }
  }

  void _showDroneSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Seleziona i tuoi droni",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: _drones.map((drone) {
                return CheckboxListTile(
                  title: Text(drone, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  value: _selectedDrones.contains(drone),
                  onChanged: (bool? selected) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : null,
                        child: _profileImageUrl == null
                            ? Icon(
                          Icons.person,
                          size: 60,
                          color: Theme.of(context).colorScheme.onSurface,
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
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Campo Username
                _buildTextField(
                  controller: _usernameController,
                  labelText: "Username",
                  hintText: "Inserisci il tuo username",
                  icon: Icons.person,
                ),
                const SizedBox(height: 24),

                _buildTextField(
                  controller: _bioController,
                  labelText: "Biografia",
                  hintText: "Scrivi una breve biografia su di te",
                  icon: Icons.info,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Seleziona Droni
                Text(
                  "Seleziona i tuoi droni",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: _selectedDrones.map((drone) {
                    return Chip(
                      label: Text(drone),
                      deleteIcon: Icon(Icons.close, color: Theme.of(context).colorScheme.primary),
                      onDeleted: () {
                        setState(() {
                          _selectedDrones.remove(drone);
                        });
                      },
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                    );
                  }).toList(),
                ),
                ElevatedButton(
                  onPressed: _showDroneSelectionDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text("Scegli i droni"),
                ),
                const SizedBox(height: 24),

                _buildTextField(
                  controller: _websiteController,
                  labelText: "Sito Web",
                  hintText: "https://iltuosito.com",
                  icon: Icons.web,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _instagramController,
                  labelText: "Instagram",
                  hintText: "@iltuonomeutente",
                  icon: Icons.camera_alt,
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _youtubeController,
                  labelText: "Canale YouTube",
                  hintText: "Link al tuo canale YouTube",
                  icon: Icons.video_library,
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _flightExperienceController,
                  labelText: "Esperienza di volo (Anni)",
                  hintText: "es. 2",
                  icon: Icons.flight,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () async {
                    await _completeProfile();
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    "Completa il profilo",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
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
        prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).colorScheme.primary) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
    super.dispose();
  }
}
