import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:altura/services/auth_service.dart';

/// Complete Profile Wizard in 3 step:
/// - Step 1: Foto profilo, Biografia e Località (con pulsante per rilevare)
/// - Step 2: I Miei Droni e Certificazioni, con aggiunta inline di:
///           • un gruppo di radio button per il livello di pilotaggio
///           • uno slider per stimare le ore di volo (da 0 a 500, etichetta "500+")
/// - Step 3: Link ai profili social
class CompleteProfileWizard extends StatefulWidget {
  const CompleteProfileWizard({super.key});

  @override
  State<CompleteProfileWizard> createState() => _CompleteProfileWizardState();
}

class _CompleteProfileWizardState extends State<CompleteProfileWizard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Step 1: Controller per i campi di testo
  final TextEditingController bioController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  String? _profileImageUrl;

  // Step 2: Dati relativi ai droni e alle certificazioni
  final List<String> addedDrones = [];
  final List<String> addedCertifications = [];
  final Set<String> selectedActivities = {};

  // Nuovi campi per livello di pilotaggio e ore di volo
  String? pilotLevel;
  int flightHours = 0;

  // Step 3: Controller per i link social
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController youtubeController = TextEditingController();
  final TextEditingController facebookController = TextEditingController();
  final TextEditingController twitterController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();

  final Auth _authService = Auth();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Carica i dati utente da Firestore, se già presenti.
  Future<void> _loadUserData() async {
    final data = await _authService.loadUserProfile();
    if (data != null) {
      setState(() {
        bioController.text = data['bio'] ?? '';
        locationController.text = data['location'] ?? '';
        _profileImageUrl = data['profileImageUrl'];
        if (data['drones'] != null) {
          final List<dynamic> dronesList = data['drones'];
          addedDrones.addAll(dronesList.map((e) => e.toString()));
        }
        if (data['certifications'] != null) {
          final List<dynamic> certList = data['certifications'];
          addedCertifications.addAll(certList.map((e) => e.toString()));
        }
        if (data['instagram'] != null) {
          instagramController.text = data['instagram'];
        }
        if (data['youtube'] != null) {
          youtubeController.text = data['youtube'];
        }
        if (data['website'] != null) {
          websiteController.text = data['website'];
        }
        // Carica livello di pilotaggio e ore di volo se già presenti
        if (data['pilotLevel'] != null) {
          pilotLevel = data['pilotLevel'];
        }
        if (data['flightExperience'] != null) {
          flightHours = int.tryParse(data['flightExperience'].toString()) ?? 0;
        }
      });
    }
  }

  /// Rileva la posizione dell'utente utilizzando geolocator e placemarks.
  Future<void> _detectLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          locationController.text = "${place.locality}, ${place.country}";
        });
      }
    } else {
      setState(() {
        locationController.text = "Permesso negato";
      });
    }
  }

  /// Salta il completamento del profilo e naviga alla home.
  void _skip() {
    Navigator.pushReplacementNamed(context, '/main_screen');
  }

  /// Naviga allo step successivo o completa il profilo se è l'ultimo step.
  void _nextPage() {
    if (_currentIndex < 2) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeProfile();
    }
  }

  /// Salva i dati raccolti su Firestore.
  Future<void> _completeProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Salviamo i droni nella chiave "dronesList" e la certificazione
      // nei campi "certificationUrl", "certificationStatus" e "certificationType"
      final dataToSave = {
        "bio": bioController.text.trim(),
        "location": locationController.text.trim(),
        "profileImageUrl": _profileImageUrl,
        "dronesList": addedDrones, // <-- Usa "dronesList" invece di "drones"
        "certificationUrl": addedCertifications.isNotEmpty ? addedCertifications.last : null,
        "certificationStatus": addedCertifications.isNotEmpty ? "pending" : null,
        "certificationType": addedCertifications.isNotEmpty ? null : null,
        "instagram": instagramController.text.trim(),
        "youtube": youtubeController.text.trim(),
        "website": websiteController.text.trim(),
        "pilotLevel": pilotLevel,
        "flightExperience": flightHours,
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).update(dataToSave);
      Navigator.pushReplacementNamed(context, '/main_screen');
    } catch (e) {
      debugPrint("Errore completamento profilo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: $e")),
      );
    }
  }

  /// Torna allo step precedente.
  void _previousPage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentIndex + 1) / 3;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Completa profilo"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text("Salta", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Expanded(child: LinearProgressIndicator(value: progress)),
              ],
            ),
          ),
          // Contenuto degli step, gestiti con PageView (non scorrevole manualmente)
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1Widget(
                  bioController: bioController,
                  locationController: locationController,
                  profileImageUrl: _profileImageUrl,
                  onImagePicked: (url) {
                    setState(() {
                      _profileImageUrl = url;
                    });
                  },
                  detectLocation: _detectLocation,
                ),
                _Step2Widget(
                  addedDrones: addedDrones,
                  addedCertifications: addedCertifications,
                  pilotLevel: pilotLevel,
                  flightHours: flightHours,
                  onPilotLevelChanged: (value) {
                    setState(() {
                      pilotLevel = value;
                    });
                  },
                  onFlightHoursChanged: (value) {
                    setState(() {
                      flightHours = value;
                    });
                  },
                ),
                _Step3Widget(
                  instagramController: instagramController,
                  youtubeController: youtubeController,
                  facebookController: facebookController,
                  twitterController: twitterController,
                  websiteController: websiteController,
                ),
              ],
            ),
          ),
          // Pulsanti di navigazione
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  ElevatedButton(
                    onPressed: _previousPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back, color: Colors.black),
                        SizedBox(width: 8),
                        Text(
                          "Indietro",
                          style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentIndex < 2 ? Theme.of(context).colorScheme.primary : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      // Cambia il testo a seconda dello step corrente
                      // "Continua" negli step 1-2, "Completa" nello step 3
                      Text(
                        "Continua",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// STEP 1: Foto profilo, Biografia e Località (Niente username)
/// ----------------------------------------------------------------------
class _Step1Widget extends StatefulWidget {
  final TextEditingController bioController;
  final TextEditingController locationController;
  final String? profileImageUrl;
  final ValueChanged<String?> onImagePicked;
  final Future<void> Function() detectLocation;

  const _Step1Widget({
    required this.bioController,
    required this.locationController,
    required this.profileImageUrl,
    required this.onImagePicked,
    required this.detectLocation,
  });

  @override
  State<_Step1Widget> createState() => _Step1WidgetState();
}

class _Step1WidgetState extends State<_Step1Widget> {
  String? _localProfileImageUrl;

  /// Utilizza ImagePicker per selezionare e caricare la foto profilo
  Future<void> _pickProfileImage() async {
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
          _localProfileImageUrl = downloadUrl;
        });
        widget.onImagePicked(downloadUrl);
      } catch (e) {
        debugPrint('Errore durante il caricamento della foto profilo: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Inserisci i dettagli del tuo profilo",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Sezione Foto profilo
          GestureDetector(
            onTap: _pickProfileImage,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _localProfileImageUrl != null
                      ? NetworkImage(_localProfileImageUrl!)
                      : null,
                  child: _localProfileImageUrl == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 8),
                const Text("Clicca per caricare un'immagine", style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Sezione Posizione con bottone "Usa GPS"
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.locationController,
                  decoration: InputDecoration(
                    labelText: "Località",
                    hintText: "Es: Roma, Italia",
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
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.detectLocation,
                icon: Icon(Icons.navigation, size: 16, color: Colors.grey.shade600),
                label: Text("Usa GPS", style: TextStyle(color: Colors.grey.shade600)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(248, 249, 250, 1),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  fixedSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Sezione Biografia
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Biografia", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: widget.bioController,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: "Racconta qualcosa su di te e della tua esperienza con UAS...",
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
            ],
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// STEP 2: I Miei Droni e Certificazioni, livello di pilotaggio e ore di volo
/// ----------------------------------------------------------------------
class _Step2Widget extends StatefulWidget {
  final List<String> addedDrones;
  final List<String> addedCertifications;
  final String? pilotLevel;
  final int flightHours;
  final ValueChanged<String?> onPilotLevelChanged;
  final ValueChanged<int> onFlightHoursChanged;

  const _Step2Widget({
    required this.addedDrones,
    required this.addedCertifications,
    required this.pilotLevel,
    required this.flightHours,
    required this.onPilotLevelChanged,
    required this.onFlightHoursChanged,
  });

  @override
  State<_Step2Widget> createState() => _Step2WidgetState();
}

class _Step2WidgetState extends State<_Step2Widget> {
  // Variabili per gestire l'espansione dei box di aggiunta
  bool _showAddDroneFields = false;
  bool _showAddCertFields = false;

  // Variabili temporanee per la selezione del drone
  String? _tempBrand;
  String? _tempModel;

  // Lista di opzioni per marca e modello
  final List<String> _brands = ["DJI", "Cinelog", "BetaFPV", "Altro"];
  final Map<String, List<String>> _brandModels = {
    "DJI": [
      "Mini 4k",
      "Mini 2",
      "Mini 2 SE",
      "Mini 3",
      "Mini 3 Pro",
      "Mini 4 Pro",
      "Mavic Air",
      "Mavic Air 2",
      "Mavic Air 2S",
      "Mavic Mini",
      "Mavic 2 Pro",
      "Mavic 2 Zoom",
      "Mavic 3",
      "Mavic 3 Classic",
      "Mavic 3 Pro",
      "Mavic 3 Cine",
      "Phantom 3 Standard",
      "Phantom 3 Advanced",
      "Phantom 3 Pro",
      "Phantom 4",
      "Phantom 4 Pro",
      "Phantom 4 Pro V2.0",
      "Inspire 1",
      "Inspire 2",
      "Inspire 3",
      "FPV",
      "Avata",
      "Avata 2",
      "Agras T30",
      "Agras T40",
      "Matrice 100",
      "Matrice 200",
      "Matrice 210",
      "Matrice 300 RTK",
      "Matrice 350 RTK",
      "Spark",
      "Ryze Tello",
      "Neo"
    ],
    "GEPRC": [
      "CineLog 25",
      "CineLog 25 V2",
      "CineLog 30",
      "CineLog 30 V2",
      "CineLog 35",
      "CineLog 35 V2",
      "Crocodile Baby",
      "Crocodile 5",
      "Crocodile 7",
      "Mark4",
      "Mark5",
      "Mark5 HD",
      "Mark5 DC",
      "Peach 5",
      "Peach Whoop",
      "Smart 35",
      "TinyGo",
      "TinyGo 4K"
    ],
    "BetaFPV": [
      "Beta 65S",
      "Beta 65X",
      "Beta 65 Pro 2",
      "Beta 75X",
      "Beta 75 Pro 2",
      "Beta 85X",
      "Beta 85 Pro 2",
      "Beta 95X V2",
      "Beta 95X V3",
      "Beta 95X V3 HD",
      "HX100",
      "HX115",
      "HX115 LR",
      "X-Knight 35",
      "X-Knight 360",
      "Pavo30",
      "Pavo25",
      "Pavo20",
      "Pavo Pico"
    ],
    "iFlight": [
      "Nazgul5",
      "Nazgul5 V2",
      "Nazgul5 Evoque",
      "Nazgul5 Evoque V2",
      "Chimera4",
      "Chimera5",
      "Chimera7",
      "Chimera7 Pro",
      "Titan DC5",
      "Titan XL5",
      "Titan XL6",
      "Titan XL7",
      "ProTek25",
      "ProTek35",
      "ProTek60",
      "BOB57",
      "Taurus X8",
      "Alpha A85",
      "Alpha A65",
      "Green Hornet V3",
      "DC3",
      "DC5",
      "Cidora SL5",
      "Cidora SL5-E",
      "XL5 V5",
      "XL6 V5",
      "XL7 V5",
      "Megabee",
      "Megabee V2"
    ],
    "Emax": [
      "Tinyhawk",
      "Tinyhawk II",
      "Tinyhawk II Freestyle",
      "Tinyhawk III",
      "Tinyhawk III Plus",
      "Tinyhawk III Plus Freestyle",
      "Nanohawk",
      "Nanohawk X",
      "Babyhawk II HD",
      "Babyhawk O3",
      "Hawk Sport",
      "Hawk Pro",
      "Hawk Apex",
      "EZ Pilot",
      "EZ Pilot Pro",
      "Interceptor"
    ],
    "Diatone": [
      "Roma F3",
      "Roma F4",
      "Roma F5",
      "Roma F5 V2",
      "Roma F6",
      "Roma F7",
      "Roma L3",
      "Roma L5",
      "Taycan C3",
      "Taycan C3.1",
      "Taycan C25",
      "Taycan C25 MK2",
      "Filmmaster X8",
      "Lanterndor X",
      "GT-R 239",
      "GT-R 249",
      "GT-R 349",
      "MXC3.1",
      "Cube 229",
      "Intrepid V2"
    ],
    "Walksnail": [
      "Avatar HD Mini 1S Lite Kit"
    ],
    "Altro": [
      "Custom 3 pollici",
      "Custom 5 pollici",
      "Custom 6 pollici",
      "Custom 7 pollici",
      "Long Range artigianali",
      "Cinewhoop custom",
      "Toothpick"
    ],
  };

  // Lista di opzioni per la certificazione
  final List<String> _certOptions = ["A1/A3", "A2", "STS", "LUC", "Altro"];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Box per i droni
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("I miei Droni", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (widget.addedDrones.isEmpty)
                  const Text("Nessun drone aggiunto", style: TextStyle(color: Colors.grey)),
                if (widget.addedDrones.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: widget.addedDrones
                        .map((drone) => Chip(
                      label: Text(drone),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      labelStyle: const TextStyle(color: Colors.white),
                      onDeleted: () {
                        setState(() {
                          widget.addedDrones.remove(drone);
                        });
                      },
                      deleteIconColor: Colors.white,
                    ))
                        .toList(),
                  ),
                const SizedBox(height: 8),
                // Pulsante per espandere il box di aggiunta drone
                if (!_showAddDroneFields)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAddDroneFields = true;
                        _tempBrand = null;
                        _tempModel = null;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Aggiungi un drone"),
                  ),
                if (_showAddDroneFields)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown per selezionare la marca
                      DropdownButtonFormField<String>(
                        value: _tempBrand,
                        hint: const Text("Seleziona marca"),
                        items: _brands.map<DropdownMenuItem<String>>(
                              (brand) => DropdownMenuItem<String>(
                            value: brand,
                            child: Text(brand),
                          ),
                        ).toList(),
                        onChanged: (value) {
                          setState(() {
                            _tempBrand = value;
                            _tempModel = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Dropdown per selezionare il modello in base alla marca
                      DropdownButtonFormField<String>(
                        value: _tempModel,
                        hint: const Text("Seleziona modello"),
                        items: (_tempBrand != null ? _brandModels[_tempBrand!] ?? [] : [])
                            .map<DropdownMenuItem<String>>(
                              (model) => DropdownMenuItem<String>(
                            value: model,
                            child: Text(model),
                          ),
                        )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _tempModel = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Pulsanti "Annulla" e "Aggiungi" per il drone
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showAddDroneFields = false;
                              });
                            },
                            child: const Text("Annulla"),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              if (_tempBrand != null && _tempModel != null) {
                                setState(() {
                                  widget.addedDrones.add("$_tempBrand - $_tempModel");
                                  _showAddDroneFields = false;
                                  _tempBrand = null;
                                  _tempModel = null;
                                });
                              }
                            },
                            child: const Text("Aggiungi"),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Box per le certificazioni
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Certificazioni",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (widget.addedCertifications.isEmpty)
                  const Text(
                    "Nessuna certificazione aggiunta",
                    style: TextStyle(color: Colors.grey),
                  ),
                if (widget.addedCertifications.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: widget.addedCertifications
                        .map((cert) => Chip(
                      label: Text(cert),
                      labelStyle: const TextStyle(color: Colors.white),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onDeleted: () {
                        setState(() {
                          widget.addedCertifications.remove(cert);
                        });
                      },
                      deleteIconColor: Colors.white,
                    ))
                        .toList(),
                  ),
                // Se sono presenti certificazioni, mostra il pulsante per caricare il file
                if (widget.addedCertifications.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // TextButton per il caricamento del file
                      TextButton.icon(
                        onPressed: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'doc', 'docx'],
                          );
                          if (result != null && result.files.single.path != null) {
                            String filePath = result.files.single.path!;
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            final storageRef = FirebaseStorage.instance
                                .ref()
                                .child('certifications')
                                .child('$uid-${DateTime.now().millisecondsSinceEpoch}.pdf');
                            UploadTask uploadTask = storageRef.putFile(File(filePath));
                            TaskSnapshot snapshot = await uploadTask;
                            String downloadUrl = await snapshot.ref.getDownloadURL();
                            setState(() {
                              // Aggiorna l'ultima certificazione aggiunta per indicare che il file è stato caricato
                              widget.addedCertifications[widget.addedCertifications.length - 1] =
                              "${widget.addedCertifications.last} (file caricato)";
                            });
                          }
                        },
                        icon: const Icon(Icons.upload_file, color: Colors.white),
                        label: const Text(
                          "Carica file",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Il file verrà analizzato e verificato.",
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                const SizedBox(height: 8),
                // Se il box certificazioni non è espanso, mostra il pulsante per espanderlo
                if (!_showAddCertFields)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAddCertFields = true;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Aggiungi una certificazione"),
                  ),
                if (_showAddCertFields)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: null,
                        hint: const Text("Seleziona tipo di certificazione"),
                        items: _certOptions.map<DropdownMenuItem<String>>(
                              (cert) => DropdownMenuItem<String>(
                            value: cert,
                            child: Text(cert),
                          ),
                        ).toList(),
                        onChanged: (value) {
                          setState(() {
                            if (value != null) {
                              widget.addedCertifications.add(value);
                              _showAddCertFields = false;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _showAddCertFields = false;
                            });
                          },
                          child: const Text("Annulla"),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Nuovi campi per livello di pilotaggio e ore di volo
          const Text(
            "Livello di pilotaggio",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // Radio button per il livello di pilotaggio
          Column(
            children: [
              RadioListTile<String>(
                title: const Text("Principiante"),
                value: "Principiante",
                groupValue: widget.pilotLevel,
                onChanged: widget.onPilotLevelChanged,
              ),
              RadioListTile<String>(
                title: const Text("Intermedio"),
                value: "Intermedio",
                groupValue: widget.pilotLevel,
                onChanged: widget.onPilotLevelChanged,
              ),
              RadioListTile<String>(
                title: const Text("Avanzato"),
                value: "Avanzato",
                groupValue: widget.pilotLevel,
                onChanged: widget.onPilotLevelChanged,
              ),
              RadioListTile<String>(
                title: const Text("Pilota professionista"),
                value: "Pilota professionista",
                groupValue: widget.pilotLevel,
                onChanged: widget.onPilotLevelChanged,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Slider per stimare le ore di volo
          Text(
            "Ore di volo totali stimate: ${widget.flightHours == 500 ? "500+" : widget.flightHours}",
            style: const TextStyle(fontSize: 16),
          ),
          Slider(
            value: widget.flightHours.toDouble(),
            min: 0,
            max: 500,
            divisions: 500,
            label: widget.flightHours == 500 ? "500+" : widget.flightHours.toString(),
            onChanged: (double value) {
              widget.onFlightHoursChanged(value.round());
            },
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// STEP 3: Link Social
/// ----------------------------------------------------------------------
class _Step3Widget extends StatelessWidget {
  final TextEditingController instagramController;
  final TextEditingController youtubeController;
  final TextEditingController facebookController;
  final TextEditingController twitterController;
  final TextEditingController websiteController;

  const _Step3Widget({
    required this.instagramController,
    required this.youtubeController,
    required this.facebookController,
    required this.twitterController,
    required this.websiteController,
  });

  /// Funzione di supporto per creare una InputDecoration uniforme
  InputDecoration _inputDecoration({required String labelText, required String hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Aggiungi i link ai tuoi profili social",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Instagram
          TextFormField(
            controller: instagramController,
            decoration: _inputDecoration(
              labelText: "Instagram",
              hintText: "@tuonome",
            ).copyWith(prefixIcon: const Icon(Icons.camera_alt)),
          ),
          const SizedBox(height: 16),
          // YouTube
          TextFormField(
            controller: youtubeController,
            decoration: _inputDecoration(
              labelText: "YouTube",
              hintText: "URL del tuo canale YouTube",
            ).copyWith(prefixIcon: const Icon(Icons.video_library)),
          ),
          const SizedBox(height: 16),
          // Sito Web
          TextFormField(
            controller: websiteController,
            decoration: _inputDecoration(
              labelText: "Sito Web",
              hintText: "https://iltuosito.it",
            ).copyWith(prefixIcon: const Icon(Icons.web)),
          ),
        ],
      ),
    );
  }
}
