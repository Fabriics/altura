import 'package:altura/models/fake_users.dart';
import 'package:altura/services/altura_loader.dart';
import 'package:altura/views/home/chat/chat_list_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/user_model.dart';
import 'views/home/map_page.dart';
import 'views/home/rules_page.dart';
import 'views/home/pilot_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  /// Indice selezionato nella BottomNavigationBar
  int _selectedIndex = 0;

  /// Dati personalizzati dell'utente (caricati da Firestore)
  AppUser? _appUser;

  /// Flag per mostrare un loader quando stiamo caricando l'utente
  bool _isLoadingUser = true;

  /// Lista di pagine principali (Home, Regole, Professionisti, Chat)
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    debugPrint("[MainScreen] initState chiamato.");

    // Inizializziamo la lista di pagine
    _pages = const [
      MapPage(),      // Pagina 0
      RulesPage(),    // Pagina 1
      FakeUsersScreen(),  // Pagina 2 (es. Piloti o Chat, in base alla logica dell'app)
    ];

    // Carichiamo l'utente
    _initUser();
  }

  /// Carica i dati dell'utente da Firestore, se loggato
  Future<void> _initUser() async {
    debugPrint("[MainScreen] _initUser: inizio caricamento utente Firestore...");

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      debugPrint("[MainScreen] _initUser: Nessun utente loggato -> stop");
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    // Verifica che il widget sia ancora montato dopo l'await
    if (!mounted) return;

    debugPrint("[MainScreen] _initUser: doc.exists = ${doc.exists}");

    if (!doc.exists || doc.data() == null) {
      debugPrint("[MainScreen] _initUser: Il documento utente non esiste o è vuoto");
      if (mounted) {
        setState(() {
          _appUser = null;
          _isLoadingUser = false;
        });
      }
    } else {
      final data = doc.data()!;
      final userModel = AppUser.fromMap(data);
      debugPrint("[MainScreen] _initUser: Caricato con successo -> ${userModel.uid} / ${userModel.username}");
      if (mounted) {
        setState(() {
          _appUser = userModel;
          _isLoadingUser = false;
        });
      }
    }
  }

  /// Gestione tap su uno degli item della BottomNavigationBar
  void _onItemTapped(int index) {
    debugPrint("[MainScreen] _onItemTapped: index = $index");
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[MainScreen] build chiamato. _appUser = $_appUser, _isLoadingUser = $_isLoadingUser");

    // Se stiamo ancora caricando l'utente, mostriamo un loader
    if (_isLoadingUser) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              AlturaLoader(),
            ],
          ),
        ),
      );
    }

    // Se l'utente non è trovato su Firestore, posticipiamo la navigazione
    if (_appUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login_page');
        }
      });
      // Restituiamo uno scaffold vuoto o un loader finché la navigazione non avviene
      return const Scaffold(
        body: Center(
          child: AlturaLoader(),
        ),
      );
    }

    // Altrimenti, costruiamo la UI vera e propria
    return Scaffold(
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          // Pulsante in alto a sinistra per aprire il Drawer
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
        ],
      ),
      // BottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mappa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rule),
            label: 'Regole UAS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Piloti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
        ],
      ),
    );
  }

  /// Drawer completamente blu e logout in fondo
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.primary, // Tutto blu
        child: Column(
          children: [
            // Header
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/logo/altura_logo_static.png',
                      width: 100,
                    ),
                    // Scritta
                    Text(
                      'Λltura',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Voci di menu
            _buildDrawerTile(
              icon: Icons.account_circle_outlined,
              label: 'Profilo',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/profile_page', arguments: _appUser);
              },
            ),
            _buildDrawerTile(
              icon: Icons.settings,
              label: 'Impostazioni',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/settings_page');
              },
            ),
            _buildDivider(),
            _buildDrawerTile(
              icon: Icons.help_outline,
              label: 'Assistenza e Supporto',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/support_page');
              },
            ),
            _buildDrawerTile(
              icon: Icons.info_outline,
              label: 'Informazioni su Altura',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/about_page');
              },
            ),
            // Spazio flessibile per spingere Logout in fondo
            const Spacer(),
            // Logout in fondo
            _buildDrawerTile(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login_page');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Singolo item del Drawer (icone e testo in onPrimary)
  Widget _buildDrawerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        size: 28,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  /// Divider a larghezza piena sullo sfondo blu
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.onPrimary,
    );
  }

  @override
  void dispose() {
    // Se in futuro verranno aggiunti timer o stream, assicurarsi di annullarli qui.
    super.dispose();
  }
}
