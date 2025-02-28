// lib/views/main_screen.dart

import 'package:flutter/material.dart';
import 'home_page.dart'; // Sostituisci con le tue pagine reali

/// MainScreen con Drawer + NavBar galleggiante + pulsante personalizzato
/// in alto a sinistra per aprire il Drawer.
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Pagine principali (aggiungi le altre se necessario)
  final List<Widget> _pages = const [
    HomePage(),
    // RulesPage(),
    // ProfessionalsPage(),
    // ChatPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Drawer definito qui
      drawer: _buildDrawer(),

      // Body come Stack: pagina + pulsante drawer + nav bar galleggiante
      body: Stack(
        children: [
          // 1) Pagina selezionata (es. mappa)
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

          // 3) BottomNavigationBar galleggiante
          Positioned(
            left: 16,
            right: 16,
            bottom: 16, // Margine dal fondo
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  // Personalizza ombra se vuoi
                  BoxShadow(
                    // color: Colors.black,
                    // blurRadius: 8,
                    // offset: Offset(0, 4),
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
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, color: Colors.white, size: 28),
              title: const Text('Profilo', style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/profile_page');
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
