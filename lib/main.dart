import 'package:altura/views/auth/forgot_password_page.dart';
import 'package:altura/views/home/settings/change_password_page.dart';
import 'package:altura/views/home/settings/delete_account_page.dart';
import 'package:altura/views/home/settings/notifications_settings_page.dart';
import 'package:altura/views/auth/complete_profile_wizard.dart';
import 'package:altura/views/auth/login_page.dart';
import 'package:altura/main_screen.dart';
import 'package:altura/views/auth/onboarding_page.dart';
import 'package:altura/views/home/profile/profile_page.dart';
import 'package:altura/views/home/search_page.dart';
import 'package:altura/views/home/settings/settings_page.dart';
import 'package:altura/views/auth/signup_page.dart';
import 'package:altura/models/user_model.dart';
import 'package:altura/views/home/edit/edit_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:altura/theme/app_theme.dart';
import 'package:altura/views/home/map_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Recupera il flag per l'onboarding
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;
  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Altura",
      theme: appTheme,
      // Utilizziamo uno StreamBuilder per ascoltare i cambiamenti di stato dell'autenticazione
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Se l'utente è autenticato, mostriamo direttamente la home
          if (snapshot.hasData) {
            return const MainScreen();
          } else {
            // Utente non autenticato:
            // Se l'onboarding non è stato completato, lo mostriamo
            if (!seenOnboarding) {
              return const OnboardingPage();
            }
            // Altrimenti, se è già stato visualizzato, mostriamo la pagina di login
            return const LoginPage();
          }
        },
      ),
      routes: {
        '/home_page': (context) => const MapPage(),
        '/settings_page': (context) => const SettingsPage(),
        '/profile_page': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is AppUser) {
            return ProfilePage(user: args);
          } else {
            return const Scaffold(
              body: Center(child: Text("Nessun utente disponibile")),
            );
          }
        },
        '/login_page': (context) => const LoginPage(),
        '/onboarding_page': (context) => const OnboardingPage(),
        '/signup_page': (context) => const SignUpPage(),
        '/complete_profile_page': (context) => const CompleteProfileWizard(),
        '/change_password': (context) => const ChangePasswordPage(),
        '/forgot_password': (context) => ForgotPasswordPage(),
        '/delete_account_page': (context) => DeleteAccountPage(),
        '/edit_profile_page': (context) => EditProfilePage(),
        '/search_page': (context) => SearchPage(),
        '/notification_settings_page': (context) => NotificationSettingsPage(),
        '/main_screen': (context) => const MainScreen(),
      },
    );
  }
}
