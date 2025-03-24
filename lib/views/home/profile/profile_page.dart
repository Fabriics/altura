import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/user.dart';
import 'favorites_page.dart';
import 'updated_places_page.dart';

class ProfilePage extends StatelessWidget {
  final AppUser user;
  const ProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF02398E),
        title: Text(
          'Profilo',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/edit_profile');
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Errore di connessione.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Utente non trovato.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final updatedUser = AppUser.fromMap(data);

          return _buildProfileBody(context, updatedUser);
        },
      ),
    );
  }

  Widget _buildProfileBody(BuildContext context, AppUser user) {
    final theme = Theme.of(context);

    // Avatar
    final profileImageUrl = user.profileImageUrl;
    final avatar = (profileImageUrl != null && profileImageUrl.isNotEmpty)
        ? NetworkImage(profileImageUrl)
        : const AssetImage('assets/placeholder.png') as ImageProvider;

    // Contatori
    final segnapostiCount = user.uploadedPlaces.length;
    final salvatiCount = user.favoritePlaces.length;

    return DefaultTabController(
      length: 2, // o 3 se aggiungi "Servizi"
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Immagine profilo
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: avatar,
            ),
            const SizedBox(height: 12),

            // Nome utente
            if (user.username.isNotEmpty)
              Text(
                user.username,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

            // Località (campo user.location)
            if (user.location != null && user.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.location!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Row con contatori (Segnaposti, Salvati)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UploadedPlacesPage(
                          uploadedPlaceIds: user.uploadedPlaces,
                        ),
                      ),
                    );
                  },
                  child: _buildStatItem(context, 'Segnaposti', segnapostiCount.toString()),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FavoritesPage(
                          placeIds: user.favoritePlaces,
                        ),
                      ),
                    );
                  },
                  child: _buildStatItem(context, 'Salvati', salvatiCount.toString()),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // TabBar
            Container(
              color: Colors.grey[200],
              child: const TabBar(
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: [
                  Tab(text: "Su di me"),
                  Tab(text: "Informazioni"),
                  // Se vuoi una 3a tab:
                  // Tab(text: "Servizi"),
                ],
              ),
            ),

            // TabBarView
            SizedBox(
              height: 500, // Altezza fissa (oppure calcola dinamicamente)
              child: TabBarView(
                children: [
                  // 1) SU DI ME
                  _AboutMeSection(user: user),

                  // 2) INFORMAZIONI
                  _InfoSection(user: user),

                  // 3) SERVIZI (opzionale)
                  // _ServicesSection(user: user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
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
          style: theme.textTheme.labelLarge?.copyWith(color: Colors.grey[700]),
        ),
      ],
    );
  }
}

// Sezione "Su di me" con Static Map
class _AboutMeSection extends StatefulWidget {
  final AppUser user;
  const _AboutMeSection({Key? key, required this.user}) : super(key: key);

  @override
  State<_AboutMeSection> createState() => _AboutMeSectionState();
}

class _AboutMeSectionState extends State<_AboutMeSection> {
  bool _isExpanded = false;

  // Inserisci la tua Google Maps Static API Key
  static const String _googleMapsApiKey = "LA_TUA_API_KEY";

  @override
  Widget build(BuildContext context) {
    final bio = widget.user.bio ?? "Nessuna descrizione";
    final maxLines = _isExpanded ? null : 5;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Testo “Su di me” con espandibile
        Text(
          bio,
          maxLines: maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        if (!_isExpanded && _needsExpansion(bio))
          InkWell(
            onTap: () => setState(() => _isExpanded = true),
            child: const Text(
              "Leggi tutto",
              style: TextStyle(color: Colors.blue),
            ),
          ),

        const SizedBox(height: 24),

        // MAPPA (Static Map)
        if (_hasLatLong(widget.user)) ...[
          Text(
            "Località",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          // Se vuoi mostrare user.location come stringa
          if (widget.user.location != null && widget.user.location!.isNotEmpty)
            Text(
              widget.user.location!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          const SizedBox(height: 8),

          // Creiamo l'URL della static map
          _buildStaticMap(widget.user.latitude!, widget.user.longitude!),
        ],
      ],
    );
  }

  Widget _buildStaticMap(double lat, double lng) {
    final staticMapUrl =
        "https://maps.googleapis.com/maps/api/staticmap?"
        "center=$lat,$lng"
        "&zoom=14"
        "&size=600x300"
        "&markers=color:red%7C$lat,$lng"
        "&key=$_googleMapsApiKey";

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        staticMapUrl,
        fit: BoxFit.cover,
        height: 180,
        // Puoi aggiungere width se vuoi
      ),
    );
  }

  bool _needsExpansion(String text) {
    return text.length > 200; // soglia indicativa
  }

  bool _hasLatLong(AppUser user) {
    // Controlla se user.latitude e user.longitude non sono null
    return (user.latitude != null && user.longitude != null);
  }
}

// Sezione "Informazioni": droni, social
class _InfoSection extends StatelessWidget {
  final AppUser user;
  const _InfoSection({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Droni
        if (user.drones.isNotEmpty) ...[
          Text("I miei droni", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.drones.map((drone) {
              return Chip(
                label: Text(drone),
                backgroundColor: Colors.black87,
                labelStyle: const TextStyle(color: Colors.white),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Social
        if (_hasAnySocial(user)) ...[
          Text("Social", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (user.instagram != null && user.instagram!.isNotEmpty)
            _buildSocialRow(
              icon: Icons.camera_alt_outlined,
              label: "Instagram",
              value: user.instagram!,
            ),
          if (user.youtube != null && user.youtube!.isNotEmpty)
            _buildSocialRow(
              icon: Icons.video_collection_outlined,
              label: "YouTube",
              value: user.youtube!,
            ),
          if (user.website != null && user.website!.isNotEmpty)
            _buildSocialRow(
              icon: Icons.link,
              label: "Website",
              value: user.website!,
            ),
        ],
      ],
    );
  }

  bool _hasAnySocial(AppUser user) {
    return (user.instagram != null && user.instagram!.isNotEmpty) ||
        (user.youtube != null && user.youtube!.isNotEmpty) ||
        (user.website != null && user.website!.isNotEmpty);
  }

  Widget _buildSocialRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            "$label: $value",
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
