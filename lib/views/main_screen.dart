// lib/views/main_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'home_page.dart';
import 'rules_page.dart';
import 'professionals_page.dart';
import 'chat_page.dart';

/// MainScreen con Drawer + NavBar galleggiante + pulsante personalizzato
/// in alto a sinistra per aprire il Drawer.
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  AppUser? _appUser; // Dati personalizzati dell'utente

  // Pagine principali (Home, Regole, Professionisti, Chat)
  final List<Widget> _pages = const [
    HomePage(),
    RulesPage(),
    ProfessionalsPage(),
    ChatPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _initUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      debugPrint('Nessun utente loggato (firebaseUser == null)');
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    debugPrint('Doc for user ${firebaseUser.uid}: ${doc.data()}');

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final userModel = AppUser.fromMap(data);
      setState(() {
        _appUser = userModel;
        debugPrint('AppUser caricato con successo: $_appUser');
      });
    } else {
      debugPrint('Il documento non esiste o è vuoto');
    }
  }

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),

      // Stack per la pagina e la nav bar flottante
      body: Stack(
        children: [
          // 1) Pagina selezionata
          _pages[_selectedIndex],

          // 2) Pulsante per aprire il Drawer (in alto a sinistra)
          Positioned(
            top: 80.0,
            left: 16.0,
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        spreadRadius: 2,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu, color: Colors.black),
                ),
              ),
            ),
          ),

          // 3) BottomNavigationBar galleggiante in basso
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    // Personalizza ombra se vuoi
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  backgroundColor: Colors.white,
                  selectedItemColor: Colors.blue,
                  unselectedItemColor: Colors.grey,
                  onTap: _onItemTapped,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.map),
                      label: 'Mappa',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.rule),
                      label: 'Regole',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person),
                      label: 'Professionisti',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.chat),
                      label: 'Chat',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Esempio di Drawer personalizzato
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.primary,
        child: Column(
          children: [
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flight_takeoff, color: Colors.white, size: 48),
                  const SizedBox(height: 10),
                  Text(
                    'Altura',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Esempi di voci di menu...
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, color: Colors.white, size: 28),
              title: const Text('Profilo', style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/profile_page', arguments: _appUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white, size: 28),
              title: const Text('Impostazioni', style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/settings_page');
              },
            ),
            const Divider(color: Colors.white70),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.white, size: 28),
              title: const Text('Assistenza e Supporto', style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/support_page');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white, size: 28),
              title: const Text('Informazioni su Altura', style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/about_page');
              },
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white, size: 28),
                  title: const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 18)),
                  onTap: () {
                    // Logica logout
                    Navigator.pushReplacementNamed(context, '/login_page');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
