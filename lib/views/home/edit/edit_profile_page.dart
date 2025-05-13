import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Controller per i campi testuali
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();

  // Nuovi campi per esperienza e pilotaggio
  String? _pilotLevel;
  int _flightHours = 0;

  // Droni: utilizziamo due dropdown per marca e modello
  String? _selectedBrand;
  String? _selectedModel;
  final List<String> _addedDrones = [];

  // Possibili marche e modelli (simile a complete profile)
  final List<String> _brands = ["DJI", "Cinelog", "BetaFPV", "Altro"];
  final Map<String, List<String>> _brandModels = {
    "DJI": ["Mini 3 Pro", "FPV", "Mavic Air", "Phantom"],
    "Cinelog": ["Cinelog 25", "Cinelog 35"],
    "BetaFPV": ["HX115 LR", "Beta 95X", "Beta 85 Pro 2"],
    "Altro": ["Custom 5 pollici", "Custom 7 pollici"],
  };

  // Certificazione
  String? _certificationFileUrl;
  String? _certificationType;

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
          _locationController.text = data['location'] ?? '';
          _profileImageUrl = data['profileImageUrl'];
          // Se sono presenti droni, li carica
          if (data['dronesList'] != null) {
            final List<dynamic> droneList = data['dronesList'];
            for (var d in droneList) {
              _addedDrones.add(d.toString());
            }
          }
          // Carica pilot level e flight hours (se presenti)
          _pilotLevel = data['pilotLevel'];
          if (data['flightExperience'] != null) {
            _flightHours = int.tryParse(data['flightExperience'].toString()) ?? 0;
          }
          // Carica certificazione
          _certificationFileUrl = data['certificationUrl'];
          _certificationType = data['certificationType'];
        });
      }
    } catch (e) {
      debugPrint('Errore nel recupero dei dati utente: $e');
    }
  }

  /// Metodo per caricare la foto profilo utilizzando ImagePicker.
  Future<void> _uploadProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;
        final File imageFile = File(pickedFile.path);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$uid.jpg');
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

  /// Metodo per aggiornare il profilo utente su Firestore.
  Future<void> _updateProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final profileData = {
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        'website': _websiteController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'youtube': _youtubeController.text.trim(),
        'flightExperience': _flightHours,
        'pilotLevel': _pilotLevel,
        'dronesList': _addedDrones,
        'certificationUrl': _certificationFileUrl,
        'certificationType': _certificationType,
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).update(profileData);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Errore nell\'aggiornamento del profilo: $e');
    }
  }

  /// Metodo per rilevare la posizione esatta dell'utente.
  Future<void> _detectLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        setState(() {
          _locationController.text = "${place.locality}, ${place.country}";
        });
      }
    } else {
      setState(() {
        _locationController.text = "Permesso negato";
      });
    }
  }

  /// Metodo per caricare il file di certificazione utilizzando file_picker.
  Future<void> _uploadCertificationFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;
        String filePath = result.files.single.path!;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('certifications')
            .child('$uid-${DateTime.now().millisecondsSinceEpoch}.pdf');
        UploadTask uploadTask = storageRef.putFile(File(filePath));
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        setState(() {
          _certificationFileUrl = downloadUrl;
        });
      } catch (e) {
        debugPrint('Errore durante il caricamento del file di certificazione: $e');
      }
    }
  }

  /// Dropdown per la selezione della marca.
  Widget _buildBrandDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBrand,
      hint: const Text("Seleziona la marca"),
      items: _brands.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
      onChanged: (value) {
        setState(() {
          _selectedBrand = value;
          _selectedModel = null; // reset modello
        });
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  /// Dropdown per la selezione del modello, in base alla marca selezionata.
  Widget _buildModelDropdown() {
    final models = _selectedBrand != null ? _brandModels[_selectedBrand!] ?? [] : [];
    return DropdownButtonFormField<String>(
      value: _selectedModel,
      hint: const Text("Seleziona il modello"),
      items: _brands.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
    onChanged: (value) {
        setState(() {
          _selectedModel = value;
        });
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  /// Sezione per la selezione multipla dei droni.
  Widget _buildDroneSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Droni posseduti:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _addedDrones.map((drone) {
              return Chip(
                label: Text(drone),
                onDeleted: () => setState(() => _addedDrones.remove(drone)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildBrandDropdown(),
          const SizedBox(height: 16),
          _buildModelDropdown(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_selectedBrand != null) {
                String drone = _selectedBrand!;
                if (_selectedModel != null && _selectedModel!.isNotEmpty) {
                  drone += " " + _selectedModel!;
                }
                setState(() {
                  _addedDrones.add(drone);
                  _selectedBrand = null;
                  _selectedModel = null;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text("Aggiungi Drone", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Sezione per il livello di pilotaggio e ore di volo.
  Widget _buildPilotSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Livello di pilotaggio:", style: TextStyle(fontWeight: FontWeight.bold)),
          Column(
            children: [
              RadioListTile<String>(
                title: const Text("Principiante"),
                value: "Principiante",
                groupValue: _pilotLevel,
                onChanged: (value) {
                  setState(() {
                    _pilotLevel = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text("Intermedio"),
                value: "Intermedio",
                groupValue: _pilotLevel,
                onChanged: (value) {
                  setState(() {
                    _pilotLevel = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text("Avanzato"),
                value: "Avanzato",
                groupValue: _pilotLevel,
                onChanged: (value) {
                  setState(() {
                    _pilotLevel = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text("Pilota professionista"),
                value: "Pilota professionista",
                groupValue: _pilotLevel,
                onChanged: (value) {
                  setState(() {
                    _pilotLevel = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("Ore di volo totali: $_flightHours", style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _flightHours.toDouble(),
            min: 0,
            max: 500,
            divisions: 500,
            label: _flightHours == 500 ? "500+" : _flightHours.toString(),
            onChanged: (value) {
              setState(() {
                _flightHours = value.round();
              });
            },
          ),
        ],
      ),
    );
  }

  /// Sezione per il caricamento del file di certificazione.
  Widget _buildCertificationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Certificazione:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _certificationFileUrl != null ? "File caricato" : "Nessun file caricato",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: _uploadCertificationFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _certificationFileUrl == null ? "Carica file" : "Modifica file",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Il file verrà analizzato e verificato.",
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
          ),
          const SizedBox(height: 16),
          // Dropdown per il tipo di certificazione
          DropdownButtonFormField<String>(
            value: _certificationType,
            hint: const Text("Seleziona il tipo di certificazione"),
            items: const [
              DropdownMenuItem(value: "A1", child: Text("A1")),
              DropdownMenuItem(value: "A2", child: Text("A2")),
              DropdownMenuItem(value: "A3", child: Text("A3")),
              DropdownMenuItem(value: "CRO", child: Text("CRO")),
              DropdownMenuItem(value: "Altro", child: Text("Altro")),
            ],
            onChanged: (value) {
              setState(() {
                _certificationType = value;
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  /// Metodo per costruire un campo di testo generico.
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
      readOnly: labelText == "Username", // Username in sola lettura
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[200],
        labelText: labelText,
        hintText: hintText,
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
    _locationController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica Profilo'),
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
              // Sezione Foto Profilo con box grigio chiaro
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
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
              // Sezione Informazioni Personali
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _locationController,
                            labelText: "Località",
                            hintText: "Es. Roma, Italia",
                            icon: Icons.location_on,
                          ),
                        ),
                        IconButton(
                          onPressed: _detectLocation,
                          icon: Icon(Icons.my_location, color: theme.colorScheme.primary),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Sezione Droni e Esperienza
              _buildDroneSection(),
              const SizedBox(height: 24),
              _buildPilotSection(),
              const SizedBox(height: 24),
              // Sezione Social
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Sezione Certificazione
              _buildCertificationSection(),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
