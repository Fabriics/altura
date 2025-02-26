import 'package:flutter/material.dart';
import 'package:altura/views/login_page.dart';


class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentIndex = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Scopri i migliori posti per volare con il tuo drone',
      'description': 'Trova luoghi bellissimi condivisi da altri appassionati e condividi le tue esperienze.',
      'image': 'Icons.image',
    },
    {
      'title': 'Conosci le normative locali sui droni',
      'description': 'Consulta le normative aggiornate per ogni paese, assicurandoti di volare in sicurezza e nel rispetto delle leggi.',
      'image': 'Icons.rule',
    },
    {
      'title': 'Accedi al marketplace e vendi i tuoi contenuti',
      'description': 'Compra e vendi documenti e risorse utili per gli appassionati di droni, inclusi tutorial e guide.',
      'image': 'Icons.shopping_cart',
    },
  ];

  void _nextPage() {
    if (_currentIndex < _onboardingData.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _goToLoginPage();
    }
  }

  void _goToLoginPage() {
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Top Section with Image Placeholder
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  child: Center(
                    child: Icon(
                      _currentIndex == 0
                          ? Icons.image
                          : _currentIndex == 1
                          ? Icons.rule
                          : Icons.shopping_cart,
                      size: 100,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),

              // Text Section
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _onboardingData[_currentIndex]['title']!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _onboardingData[_currentIndex]['description']!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),

              // Dots Indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _onboardingData.length,
                        (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: _currentIndex == index
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),

              // Button Section
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _currentIndex == _onboardingData.length - 1 ? 'Sign In' : 'Next',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // "Skip" Button
          Positioned(
            top: 40.0,
            right: 24.0,
            child: TextButton(
              onPressed: _goToLoginPage,
              child: Text(
                "Skip",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
