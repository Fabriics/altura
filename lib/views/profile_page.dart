import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


import '../models/user_model.dart';

class ProfilePage extends StatefulWidget {
  final AppUser user; // Ricevi un utente con user.uid almeno

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppUser? _user; // user locale, che aggiorneremo dopo _fetchUserFromFirestore

  @override
  void initState() {
    super.initState();
    // Memorizziamo l’utente iniziale
    _user = widget.user;
  }

  /// Ricarica i dati utente da Firestore
  Future<void> _fetchUserFromFirestore() async {
    if (_user == null) return;
    final uid = _user!.uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        // Creiamo un nuovo AppUser con i dati aggiornati
        final newData = doc.data()!;
        final updatedUser = AppUser.fromMap(newData);

        setState(() {
          _user = updatedUser;
        });
      }
    } catch (e) {
      debugPrint('Errore nel fetch utente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se non abbiamo ancora un utente (caso raro), mostriamo un loader
    if (_user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    // Recuperiamo l'URL dal campo profileImageUrl (unico per la foto profilo)
    final String? profileImageUrl = _user!.profileImageUrl;

    // Se profileImageUrl è non-null e non vuoto, usiamo NetworkImage
    final avatar = (profileImageUrl != null && profileImageUrl.isNotEmpty)
        ? NetworkImage(profileImageUrl)
        : const AssetImage('assets/placeholder.png') as ImageProvider;

    // Esempi di contatori
    final segnapostiCount = _user!.uploadedPlaces.length;
    final salvatiCount = _user!.favoritePlaces.length;

    // Converte flightExperience in stringa (es. "2" se flightExperience=2)
    final flightExperienceString =
    (_user!.flightExperience != null && _user!.flightExperience! > 0)
        ? _user!.flightExperience.toString()
        : '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        elevation: 0,
        title: Text(
          'Profilo',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              // Naviga alla pagina di modifica profilo
              Navigator.pushNamed(context, '/edit_profile').then((_) {
                // Ricarica i dati dopo il ritorno da EditProfile
                _fetchUserFromFirestore();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          children: [
            // 1) Foto profilo
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: avatar,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2) Username
            if (_user!.username.isNotEmpty)
              Text(
                _user!.username,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

            // 3) BIO
            if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  _user!.bio!,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // 4) Contatori
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Segnaposti', segnapostiCount.toString(), context),
                _buildStatItem('Salvati', salvatiCount.toString(), context),
              ],
            ),
            const SizedBox(height: 20),

            // 5) Droni con chip
            if (_user!.drones.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'I miei droni',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                children: _user!.drones.map((drone) {
                  return Chip(
                    label: Text(drone),
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(color: theme.colorScheme.primary),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // 6) Altre info (flightExperience, instagram, youtube, website)
            _buildBlueBorderField(
              context,
              label: 'Anni di volo',
              value: flightExperienceString,
            ),
            _buildBlueBorderField(
              context,
              label: 'Instagram',
              value: _user!.instagram,
            ),
            _buildBlueBorderField(
              context,
              label: 'YouTube',
              value: _user!.youtube,
            ),
            _buildBlueBorderField(
              context,
              label: 'Website',
              value: _user!.website,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Mostra un contatore (ad es. "16 Segnaposti")
  Widget _buildStatItem(String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  /// Mostra un TextField read-only con label blu se value è presente
  Widget _buildBlueBorderField(
      BuildContext context, {
        required String label,
        required String? value,
      }) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        readOnly: true,
        controller: TextEditingController(text: value),
        style: const TextStyle(fontSize: 14, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
