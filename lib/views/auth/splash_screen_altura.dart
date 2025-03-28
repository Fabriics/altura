import 'package:flutter/material.dart';
import 'onboarding_page.dart';
import 'package:altura/services/logo_intro_animation.dart'; // Assicurati che il path sia corretto

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _textController;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    // Controlla se vuoi regolare i tempi in base a IntroAnimation
    // Qui durano 2 secondi, poi l'animazione rimane "ferma" al valore finale
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    // Animeremo il testo con una lieve scala da 0.8 a 1.0
    _textAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    // Dopo 4 secondi andiamo alla OnboardingPage con una transizione Fade
    Future.delayed(const Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
          const OnboardingPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2342), // blu profondo
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo animato
              const IntroAnimation(),
              const SizedBox(height: 16),
              // Testo animato
              ScaleTransition(
                scale: _textAnimation,
                child: Text(
                  'Λltura', // 'A' sostituita con la lettera greca 'Λ'
                  style: const TextStyle(
                    fontFamily: 'Poppins', // Assicurati di avere il font in pubspec.yaml
                    fontSize: 36,
                    color: Colors.white,
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
