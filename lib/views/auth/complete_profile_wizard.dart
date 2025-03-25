import 'package:flutter/material.dart';

// Esempio di "contenitore" che gestisce i 4 step del profilo.
class CompleteProfileWizard extends StatefulWidget {
  const CompleteProfileWizard({Key? key}) : super(key: key);

  @override
  State<CompleteProfileWizard> createState() => _CompleteProfileWizardState();
}

class _CompleteProfileWizardState extends State<CompleteProfileWizard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Qui puoi inserire i controller o i dati da raccogliere.
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  // Esempio: dati raccolti dallo step 3 (scelta droni e attività).
  String? selectedBrand;
  String? selectedModel;
  final Set<String> selectedActivities = {};

  // Altri campi dell'ultimo step
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController youtubeController = TextEditingController();

  // Pulsante "Salta": puoi decidere se chiudere la pagina, tornare indietro, ecc.
  void _skip() {
    // Esempio: naviga alla home o chiudi lo step
    Navigator.pushReplacementNamed(context, '/home_page');
  }

  // Pulsante "Avanti" / "Completa"
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
      // Ultimo step: invoca il salvataggio dei dati
      _completeProfile();
    }
  }

  Future<void> _completeProfile() async {
    // Qui salvi tutti i dati raccolti negli step
    // Esempio: invoca il tuo AuthService o ProfileService
    // ...
    Navigator.pushReplacementNamed(context, '/home_page');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack per eventuale sfondo/overlay se vuoi
      body: SafeArea(
        child: Stack(
          children: [
            // Pulsante "Salta" in alto a destra
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _skip,
                child: const Text("Salta"),
              ),
            ),
            // Contenuto principale
            Column(
              children: [
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
                      // 3) Selezione droni e attività
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
                // Pulsante Avanti / Completa in fondo
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      child: Text(
                        _currentIndex == 3 ? "Completa" : "Avanti",
                      ),
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 1) Widget per Foto e Username
// --------------------------------------------------------
class PhotoUsernameWidget extends StatelessWidget {
  final TextEditingController usernameController;
  // Qui potresti aggiungere un callback per caricare l'immagine

  const PhotoUsernameWidget({
    Key? key,
    required this.usernameController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            // Esempio di avatar e pulsante di upload
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              child: Icon(
                Icons.person,
                size: 50,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Esempio: logica di caricamento immagine
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text("Carica foto"),
            ),
            const SizedBox(height: 32),
            // Campo username
            TextFormField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            TextFormField(
              controller: bioController,
              decoration: const InputDecoration(
                labelText: "Biografia",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: "Località",
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 3) Widget per scelta Droni e Attività
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
  // Esempio di brand -> modelli
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
    // Se la brand selezionata non esiste più, reset
    if (localSelectedBrand != null && !brands.contains(localSelectedBrand)) {
      localSelectedBrand = null;
      localSelectedModel = null;
    }

    final modelsForBrand = localSelectedBrand == null
        ? <String>[]
        : brandModels[localSelectedBrand!] ?? <String>[];

    // Se il modello selezionato non è più presente, reset
    if (localSelectedModel != null && !modelsForBrand.contains(localSelectedModel)) {
      localSelectedModel = null;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            // Selezione brand
            DropdownButtonFormField<String>(
              value: localSelectedBrand,
              hint: const Text("Seleziona la marca"),
              items: brands
                  .map(
                    (brand) => DropdownMenuItem(
                  value: brand,
                  child: Text(brand),
                ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  localSelectedBrand = value;
                  localSelectedModel = null; // reset
                });
                widget.onBrandModelChanged(value, null);
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            // Selezione modello (dipende dalla brand)
            DropdownButtonFormField<String>(
              value: localSelectedModel,
              hint: const Text("Seleziona il modello"),
              items: modelsForBrand
                  .map(
                    (model) => DropdownMenuItem(
                  value: model,
                  child: Text(model),
                ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  localSelectedModel = value;
                });
                widget.onBrandModelChanged(localSelectedBrand, value);
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            // Attività (checkbox)
            Text(
              "Cosa ti piace fare?",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 4) Widget per gli altri campi
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            TextFormField(
              controller: websiteController,
              decoration: const InputDecoration(
                labelText: "Sito Web",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: instagramController,
              decoration: const InputDecoration(
                labelText: "Instagram",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: youtubeController,
              decoration: const InputDecoration(
                labelText: "YouTube",
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
