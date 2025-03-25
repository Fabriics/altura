import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentIndex = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Scopri i migliori posti per volare',
      'description':
      'Esplora location straordinarie per il volo con il tuo drone, selezionate e condivise dalla nostra community di piloti esperti. Suggerimenti, immagini e recensioni per riprese uniche ti aspettano.',
      'image': 'Icons.image',
    },
    {
      'title': 'Normative Sempre Aggiornate',
      'description':
      'Rimani informato sulle normative locali e internazionali per volare in sicurezza. Approfondimenti e consigli pratici per evitare sanzioni e volare nel rispetto della legge.',
      'image': 'Icons.rule',
    },
    {
      'title': 'Marketplace per Appassionati',
      'description':
      'Accedi a un marketplace dedicato dove acquistare risorse esclusive o vendere i tuoi contenuti. Trasforma la tua passione in opportunità, condividendo esperienze con altri professionisti.',
      'image': 'Icons.shopping_cart',
    },
  ];

  final List<String> _backgrounds = [
    'assets/background_onboarding.png',
    'assets/background_onboarding2.jpg',
    'assets/background_onboarding3.jpeg',
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
    Navigator.pushReplacementNamed(context, '/signup_page');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background animato che cambia ad ogni step
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: Container(
              key: ValueKey<int>(_currentIndex),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_backgrounds[_currentIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Overlay per aumentare il contrasto (design minimalista)
          Container(
            color: Colors.black.withOpacity(0.4),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Contenuto in alto: Titolo e Descrizione con animazione
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      key: ValueKey<int>(_currentIndex),
                      children: [
                        Text(
                          _onboardingData[_currentIndex]['title']!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _onboardingData[_currentIndex]['description']!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Pulsante "Next" o "Sign In" in basso, con testo in grassetto
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0, // design flat e minimalista
                      ),
                      child: Text(
                        _currentIndex == _onboardingData.length - 1
                            ? 'Sign In'
                            : 'Next',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottone "Salta" posizionato in alto a destra
          Positioned(
            top: 40.0,
            right: 24.0,
            child: TextButton(
              onPressed: _goToLoginPage,
              child: Text(
                "Salta",
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
