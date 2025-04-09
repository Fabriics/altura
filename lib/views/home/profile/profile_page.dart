import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:altura/models/user_model.dart';
import 'package:altura/services/altura_loader.dart';
import 'favorites_page.dart';
import 'updated_places_page.dart';

/// Pagina del profilo utente.
class ProfilePage extends StatelessWidget {
  final AppUser user;
  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/edit_profile_page');
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Errore di connessione.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AlturaLoader());
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

  /// Costruisce il corpo del profilo utente.
  Widget _buildProfileBody(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    final profileImageUrl = user.profileImageUrl;
    final avatar = (profileImageUrl != null && profileImageUrl.isNotEmpty)
        ? NetworkImage(profileImageUrl)
        : const AssetImage('assets/placeholder.png') as ImageProvider;

    final segnapostiCount = user.uploadedPlaces.length;
    final salvatiCount = user.favoritePlaces.length;

    return DefaultTabController(
      length: 2,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar in un contenitore con sfondo chiaro e bordi arrotondati.
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage: avatar,
              ),
            ),
            const SizedBox(height: 12),
            if (user.username.isNotEmpty)
              Text(
                user.username,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            // Chips per Località, Livello e Ore di volo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (user.location != null && user.location!.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.location_on, size: 16),
                      label: Text(user.location!),
                    ),
                  if (user.pilotLevel != null)
                    Chip(
                      avatar: const Icon(Icons.airplanemode_active, size: 16),
                      label: Text('Livello: ${user.pilotLevel}'),
                    ),
                  if (user.flightExperience != null)
                    Chip(
                      avatar: const Icon(Icons.timer, size: 16),
                      label: Text('Ore di volo: ${user.flightExperience}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
            // TabBar modernizzata con sfondo neutro.
            Container(
              color: Colors.grey[200],
              child: TabBar(
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(text: "Su di me"),
                  Tab(text: "Informazioni"),
                ],
              ),
            ),
            SizedBox(
              height: 500,
              child: TabBarView(
                children: [
                  _AboutMeSection(user: user),
                  _InfoSection(user: user),
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
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

/// Sezione "Su di me" con biografia e mappa.
class _AboutMeSection extends StatefulWidget {
  final AppUser user;
  const _AboutMeSection({required this.user});

  @override
  State<_AboutMeSection> createState() => _AboutMeSectionState();
}

class _AboutMeSectionState extends State<_AboutMeSection> {
  bool _isExpanded = false;
  // Inserisci qui la tua Google Maps Static API Key
  static const String _googleMapsApiKey = "LA_TUA_API_KEY";

  @override
  Widget build(BuildContext context) {
    final bio = widget.user.bio ?? "Nessuna descrizione";
    final maxLines = _isExpanded ? null : 5;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card moderna per la biografia.
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bio,
                  maxLines: maxLines,
                  overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!_isExpanded && _needsExpansion(bio))
                  InkWell(
                    onTap: () => setState(() => _isExpanded = true),
                    child: Text(
                      "Leggi tutto",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Visualizzazione della mappa se latitudine e longitudine sono disponibili.
        if (_hasLatLong(widget.user)) ...[
          Text(
            "Località",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: _buildStaticMap(widget.user.latitude!, widget.user.longitude!),
          ),
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

    return Image.network(
      staticMapUrl,
      fit: BoxFit.cover,
      height: 180,
    );
  }

  bool _needsExpansion(String text) => text.length > 200;
  bool _hasLatLong(AppUser user) => (user.latitude != null && user.longitude != null);
}

/// Sezione "Informazioni" con droni, social e certificazione.
class _InfoSection extends StatelessWidget {
  final AppUser user;
  const _InfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card per i droni con lista in stile moderno e logo della marca.
        if (user.dronesList.isNotEmpty) ...[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("I miei droni", style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.dronesList.map((drone) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundImage: AssetImage('assets/logos/${drone.toLowerCase()}.png'),
                        ),
                        label: Text(drone),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Card per i social
        if (_hasAnySocial(user)) ...[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Social", style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (user.instagram != null && user.instagram!.isNotEmpty)
                    _buildSocialRow(
                      context,
                      icon: Icons.camera_alt_outlined,
                      label: "Instagram",
                      value: user.instagram!,
                    ),
                  if (user.youtube != null && user.youtube!.isNotEmpty)
                    _buildSocialRow(
                      context,
                      icon: Icons.video_collection_outlined,
                      label: "YouTube",
                      value: user.youtube!,
                    ),
                  if (user.website != null && user.website!.isNotEmpty)
                    _buildSocialRow(
                      context,
                      icon: Icons.link,
                      label: "Website",
                      value: user.website!,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Card per la certificazione.
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCertificationInfo(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialRow(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            "$label: $value",
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationInfo(BuildContext context) {
    final theme = Theme.of(context);
    String certText;
    IconData certIcon;
    Color iconColor;

    if (user.certificationUrl != null && user.certificationUrl!.isNotEmpty) {
      // Controlla lo stato della certificazione.
      if (user.certificationStatus != null && user.certificationStatus == "approved") {
        certText = "Certificazione verificata";
        certIcon = Icons.check_circle;
        iconColor = Colors.green;
      } else if (user.certificationStatus != null && user.certificationStatus == "pending") {
        certText = "Certificazione in corso di verifica";
        certIcon = Icons.hourglass_bottom;
        iconColor = Colors.orange;
      } else {
        certText = "Certificazione non presente";
        certIcon = Icons.cancel;
        iconColor = Colors.red;
      }
    } else {
      certText = "Certificazione non presente";
      certIcon = Icons.cancel;
      iconColor = Colors.red;
    }

    return Row(
      children: [
        Icon(certIcon, color: iconColor),
        const SizedBox(width: 8),
        Text(
          certText,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
        ),
      ],
    );
  }

  bool _hasAnySocial(AppUser user) {
    return (user.instagram != null && user.instagram!.isNotEmpty) ||
        (user.youtube != null && user.youtube!.isNotEmpty) ||
        (user.website != null && user.website!.isNotEmpty);
  }
}
