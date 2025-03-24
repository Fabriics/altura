import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:altura/services/auth_service.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Controller per i campi di input
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _flightExperienceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Selezione dei droni
  final Set<String> _selectedDrones = {};
  final List<String> _drones = [
    'DJI Mini 3 Pro',
    'DJI FPV',
    'Cinelog 25',
    '5-pollici Freestyle',
    '7-pollici Long Range',
    'Altro',
  ];

  // URL della foto profilo
  String? _profileImageUrl;

  final Auth _authService = Auth();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Carica i dati dell'utente tramite il service e aggiorna i controller.
  Future<void> _loadUserData() async {
    try {
      final data = await _authService.loadUserProfile();
      if (data != null) {
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _profileImageUrl = data['profileImageUrl'];
          _locationController.text = data['location'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _instagramController.text = data['instagram'] ?? '';
          _youtubeController.text = data['youtube'] ?? '';
          final exp = data['flightExperience'];
          if (exp != null) {
            _flightExperienceController.text = exp.toString();
          }
          final savedDrones = data['drones'];
          if (savedDrones is List) {
            _selectedDrones.addAll(savedDrones.map((e) => e.toString()));
          }
        });
      }
    } catch (e) {
      debugPrint('Errore nel recupero dei dati utente: $e');
    }
  }

  /// Seleziona e carica la foto profilo usando il service.
  Future<void> _uploadProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    try {
      final File imageFile = File(pickedFile.path);
      final downloadUrl = await _authService.uploadProfileImage(imageFile);
      setState(() {
        _profileImageUrl = downloadUrl;
      });
    } catch (e) {
      debugPrint('Errore durante il caricamento della foto profilo: $e');
    }
  }

  /// Completa il profilo invocando il service e naviga alla home page.
  Future<void> _completeProfile() async {
    try {
      await _authService.completeProfile(
        username: _usernameController.text,
        bio: _bioController.text,
        website: _websiteController.text,
        instagram: _instagramController.text,
        youtube: _youtubeController.text,
        flightExperience: _flightExperienceController.text,
        drones: _selectedDrones.toList(),
        location: _locationController.text,
      );
      Navigator.pushNamed(context, '/home_page');
    } catch (e) {
      debugPrint("Errore nell'aggiornamento del profilo: $e");
    }
  }

  /// Mostra un dialog per selezionare i droni.
  void _showDroneSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            "Seleziona i tuoi droni",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: _drones.map((drone) {
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
              onPressed: () => Navigator.pop(ctx),
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

  /// Costruisce un TextFormField generico.
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
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Completa il tuo profilo"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar + pulsante per cambiare foto
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (_profileImageUrl != null)
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: (_profileImageUrl == null)
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
              // Località
              _buildTextField(
                controller: _locationController,
                labelText: "Località",
                hintText: "Es. Roma, Italia",
                icon: Icons.location_on,
              ),
              const SizedBox(height: 24),
              // Selezione droni
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
                    onDeleted: () => setState(() => _selectedDrones.remove(drone)),
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
                child: const Text("Scegli i droni"),
              ),
              const SizedBox(height: 24),
              // Website
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
              // Esperienza di volo
              _buildTextField(
                controller: _flightExperienceController,
                labelText: "Esperienza di volo (Anni)",
                hintText: "es. 2",
                icon: Icons.flight,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 40),
              // Bottone "Completa il profilo"
              ElevatedButton(
                onPressed: _completeProfile,
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
    );
  }
}
