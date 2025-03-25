import 'package:altura/views/home/chat/chat_list_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/user_model.dart';
import 'views/home/map_page.dart';
import 'views/home/rules_page.dart';
import 'views/home/pilot_page.dart';

/// MainScreen con gestione dell'utente da Firestore e navigazione "fissa"
/// (Drawer e BottomNavigationBar) implementata con IndexedStack per mantenere
/// lo stato delle pagine. La logica di navigazione è posticipata al termine
/// del frame per evitare chiamate a setState() durante il build.
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

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
      HomePage(),      // Pagina 0
      RulesPage(),     // Pagina 1
      PilotPage(),     // Pagina 2
      ChatListPage(),  // Pagina 3
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
      setState(() {
        _isLoadingUser = false;
      });
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    debugPrint("[MainScreen] _initUser: doc.exists = ${doc.exists}");

    if (!doc.exists || doc.data() == null) {
      debugPrint("[MainScreen] _initUser: Il documento utente non esiste o è vuoto");
      setState(() {
        _appUser = null;
        _isLoadingUser = false;
      });
    } else {
      final data = doc.data()!;
      final userModel = AppUser.fromMap(data);

      debugPrint("[MainScreen] _initUser: Caricato con successo -> ${userModel.uid} / ${userModel.username}");

      setState(() {
        _appUser = userModel;
        _isLoadingUser = false;
      });
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
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Caricamento utente..."),
            ],
          ),
        ),
      );
    }

    // Se l'utente non è trovato su Firestore, posticipiamo la navigazione
    if (_appUser == null) {
      // Evitiamo di chiamare Navigator.pushNamed direttamente nel build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login_page');
      });
      // Restituiamo uno scaffold vuoto o un loader finché la navigazione non avviene
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Altrimenti, costruiamo la UI vera e propria
    return Scaffold(
      // Drawer personalizzato
      drawer: _buildDrawer(),

      // L'intero body è uno Stack:
      // 1) IndexedStack per le pagine, per mantenere lo stato di ogni tab.
      // 2) Pulsante per aprire il Drawer in alto a sinistra.
      // 3) BottomNavigationBar galleggiante in basso.
      body: Stack(
        children: [
          // 1) Pagine principali tramite IndexedStack
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),

          // 2) Pulsante in alto a sinistra per aprire il Drawer
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
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      offset: Offset(0, 5),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    currentIndex: _selectedIndex,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    selectedItemColor: Colors.blue,
                    unselectedItemColor: Colors.grey,
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
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
          ),
        ],
      ),
    );
  }

  /// Drawer personalizzato
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.primary,
        child: Column(
          children: [
            // Header del Drawer
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
            // Voci di menu
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
            // Logout posizionato in fondo al Drawer
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white, size: 28),
                  title: const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 18)),
                  onTap: () {
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
