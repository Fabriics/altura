import 'package:altura/services/auth_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme,
      home:  StreamBuilder(
          stream: Auth().authStateChanges,
          builder: (context, snapshot){
            if(snapshot.hasData){
              return MainScreen();
            }else{
              return OnboardingPage();
            }
          }),
      routes: {
        '/home_page' : (context) => const HomePage(),
        '/settings_page' : (context) => const SettingsPage(),
        '/profile_page': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is AppUser) {
            return ProfilePage(user: args);
          } else {
            // Fallback se non è del tipo giusto
            return const Scaffold(
              body: Center(child: Text("Nessun utente disponibile")),
            );
          }
        },
        '/login_page' : (context) => const LoginPage(),
        '/onboarding_page' : (context) => const OnboardingPage(),
        '/signup_page' : (context) => const SignUpPage(),
        '/complete_profile_page' : (context) => const CompleteProfileWizard(),
        '/change_password': (context) => const ChangePasswordPage(),
        '/forgot_password': (context) =>  ForgotPasswordPage(),
        '/delete_account_page': (context) =>  DeleteAccountPage(),
        '/edit_profile': (context) => EditProfilePage(),
        '/search_page': (context) => SearchPage(),
        '/notification_settings_page' : (context) => NotificationSettingsPage(),
        '/main_screen': (context) => const MainScreen(),
      },
    );
  }
}



