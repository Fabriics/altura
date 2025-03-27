import 'package:flutter/material.dart';
import 'package:altura/services/auth_service.dart';

/// Wizard in 4 step per completare il profilo utente.
class CompleteProfileWizard extends StatefulWidget {
  const CompleteProfileWizard({super.key});

  @override
  State<CompleteProfileWizard> createState() => _CompleteProfileWizardState();
}

class _CompleteProfileWizardState extends State<CompleteProfileWizard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Istanza del service per salvare i dati su Firebase
  final Auth _authService = Auth();

  // Controller e variabili condivisi tra gli step
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  // Step 3: Selezione droni e attività
  String? selectedBrand;
  String? selectedModel;
  final Set<String> selectedActivities = {};

  // Step 4: Altri campi
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController youtubeController = TextEditingController();

  /// Pulsante "Salta": naviga direttamente alla Home (o dove preferisci).
  void _skip() {
    Navigator.pushReplacementNamed(context, '/main_screen');
  }

  /// Pulsante "Avanti" / "Completa"
  void _nextPage() {
    if (_currentIndex < 3) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Ultimo step: salvataggio finale su Firebase
      _completeProfile();
    }
  }

  /// Combina i dati raccolti e li invia a Firestore tramite `Auth.completeProfile()`.
  Future<void> _completeProfile() async {
    // Esempio: costruiamo una lista di droni a partire da marca e modello
    final userDrones = <String>[];
    if (selectedBrand != null && selectedBrand!.isNotEmpty) {
      if (selectedModel != null && selectedModel!.isNotEmpty) {
        userDrones.add('$selectedBrand $selectedModel');
      } else {
        userDrones.add(selectedBrand!);
      }
    }

    try {
      await _authService.completeProfile(
        username: usernameController.text.trim(),
        bio: bioController.text.trim(),
        website: websiteController.text.trim(),
        instagram: instagramController.text.trim(),
        youtube: youtubeController.text.trim(),
        // Se hai un campo dedicato per l’esperienza di volo,
        // sostituisci "0" con flightExperienceController.text
        flightExperience: '0',
        drones: userDrones,
        location: locationController.text.trim(),
        // Aggiungi il parametro per le attività, se lo hai previsto in Auth
        droneActivities: selectedActivities.toList(),
      );

      // Naviga alla Home (o altra pagina) dopo il salvataggio
      Navigator.pushReplacementNamed(context, '/main_screen');
    } catch (e) {
      debugPrint("Errore completamento profilo: $e");
      // Eventualmente mostra un messaggio di errore all’utente
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar comune a tutti gli step
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        title: Text(
          'Completa profilo',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              'Salta',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Contenuto a pagine
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // 1) Foto e Username
                PhotoUsernameWidget(
                  usernameController: usernameController,
                ),
                // 2) Biografia e Località
                BioLocationWidget(
                  bioController: bioController,
                  locationController: locationController,
                ),
                // 3) Droni e Attività
                DronesActivitiesWidget(
                  selectedBrand: selectedBrand,
                  selectedModel: selectedModel,
                  onBrandModelChanged: (brand, model) {
                    setState(() {
                      selectedBrand = brand;
                      selectedModel = model;
                    });
                  },
                  selectedActivities: selectedActivities,
                ),
                // 4) Altri campi
                OtherDataWidget(
                  websiteController: websiteController,
                  instagramController: instagramController,
                  youtubeController: youtubeController,
                ),
              ],
            ),
          ),
          // Pulsante Avanti/Completa
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentIndex == 3 ? 'Completa' : 'Avanti',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// 1) Widget per Foto e Username
// --------------------------------------------------------
class PhotoUsernameWidget extends StatelessWidget {
  final TextEditingController usernameController;

  const PhotoUsernameWidget({
    Key? key,
    required this.usernameController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Foto profilo e Username",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Scegli una foto profilo e il tuo username.",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          // Avatar + pulsante
          Align(
            alignment: Alignment.center,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              child: Icon(
                Icons.person,
                size: 50,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implementa la logica di caricamento immagine (uploadProfileImage)
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text(
                "Carica foto",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Campo username
          Text(
            "Username",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: usernameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: "Inserisci il tuo username",
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// 2) Widget per Biografia e Località
// --------------------------------------------------------
class BioLocationWidget extends StatelessWidget {
  final TextEditingController bioController;
  final TextEditingController locationController;

  const BioLocationWidget({
    Key? key,
    required this.bioController,
    required this.locationController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "2. Biografia e Località",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Racconta qualcosa di te e indica dove ti trovi.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            "Biografia",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: bioController,
            maxLines: 3,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: "Scrivi una breve biografia su di te",
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Località",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: locationController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: "Es. Roma, Italia",
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// 3) Widget per Droni e Attività
// --------------------------------------------------------
class DronesActivitiesWidget extends StatefulWidget {
  final String? selectedBrand;
  final String? selectedModel;
  final void Function(String? brand, String? model) onBrandModelChanged;
  final Set<String> selectedActivities;

  const DronesActivitiesWidget({
    Key? key,
    required this.selectedBrand,
    required this.selectedModel,
    required this.onBrandModelChanged,
    required this.selectedActivities,
  }) : super(key: key);

  @override
  State<DronesActivitiesWidget> createState() => _DronesActivitiesWidgetState();
}

class _DronesActivitiesWidgetState extends State<DronesActivitiesWidget> {
  final List<String> brands = ["DJI", "Cinelog", "BetaFPV", "Altro"];
  final Map<String, List<String>> brandModels = {
    "DJI": ["Mini 3 Pro", "FPV", "Mavic Air", "Phantom"],
    "Cinelog": ["Cinelog 25", "Cinelog 35"],
    "BetaFPV": ["HX115 LR", "Beta 95X", "Beta 85 Pro 2"],
    "Altro": ["Custom 5 pollici", "Custom 7 pollici"],
  };

  final List<String> activities = [
    "Cinematica",
    "Freestyle",
    "Racing",
    "Hobby",
    "Lavoro (termoplanimetrie, ispezioni...)",
    "Altro",
  ];

  String? localSelectedBrand;
  String? localSelectedModel;

  @override
  void initState() {
    super.initState();
    localSelectedBrand = widget.selectedBrand;
    localSelectedModel = widget.selectedModel;
  }

  @override
  Widget build(BuildContext context) {
    final modelsForBrand = localSelectedBrand == null
        ? <String>[]
        : brandModels[localSelectedBrand!] ?? <String>[];

    // Se il modello salvato non è più presente, resettiamo
    if (localSelectedModel != null && !modelsForBrand.contains(localSelectedModel)) {
      localSelectedModel = null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "3. Droni e Attività",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Seleziona la marca e il modello del tuo drone, poi indica cosa ti piace fare.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          // Selezione marca
          Text(
            "Marca",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: localSelectedBrand,
            hint: const Text("Seleziona la marca"),
            items: brands
                .map((brand) => DropdownMenuItem(value: brand, child: Text(brand)))
                .toList(),
            onChanged: (value) {
              setState(() {
                localSelectedBrand = value;
                localSelectedModel = null;
              });
              widget.onBrandModelChanged(value, null);
            },
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
          // Selezione modello
          Text(
            "Modello",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: localSelectedModel,
            hint: const Text("Seleziona il modello"),
            items: modelsForBrand
                .map((model) => DropdownMenuItem(value: model, child: Text(model)))
                .toList(),
            onChanged: (value) {
              setState(() {
                localSelectedModel = value;
              });
              widget.onBrandModelChanged(localSelectedBrand, value);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Attività preferite",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ...activities.map((activity) {
            final isSelected = widget.selectedActivities.contains(activity);
            return CheckboxListTile(
              title: Text(activity),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    widget.selectedActivities.add(activity);
                  } else {
                    widget.selectedActivities.remove(activity);
                  }
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
            );
          }).toList(),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// 4) Widget per gli Altri Dati
// --------------------------------------------------------
class OtherDataWidget extends StatelessWidget {
  final TextEditingController websiteController;
  final TextEditingController instagramController;
  final TextEditingController youtubeController;

  const OtherDataWidget({
    Key? key,
    required this.websiteController,
    required this.instagramController,
    required this.youtubeController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "4. Altri dati",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Facoltativo: inserisci i tuoi contatti o link social.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            "Sito Web",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: websiteController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: "https://iltuosito.com",
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Instagram",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: instagramController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: "@iltuonomeutente",
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "YouTube",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: youtubeController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: "Link al tuo canale YouTube",
            ),
          ),
        ],
      ),
    );
  }
}
