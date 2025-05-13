import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:altura/models/user_model.dart';
import 'package:altura/services/altura_loader.dart';
import '../chat/chat_page.dart';
import 'favorites_page.dart';
import 'updated_places_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:altura/services/chat_service.dart';

/// Pagina del profilo utente.
/// Il parametro [isOwner] era previsto per indicare se il profilo appartiene
/// all'utente corrente, ma in questo esempio il controllo viene eseguito
/// direttamente verificando il uid dell'utente con FirebaseAuth.
class ProfilePage extends StatelessWidget {
  final AppUser user;
  // Il parametro isOwner può essere mantenuto per altri scopi, ma il pulsante viene
  // visualizzato in base al controllo sul FirebaseAuth.
  final bool isOwner;

  const ProfilePage({super.key, required this.user, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    // Recupera l'utente corrente dal FirebaseAuth.
    final currentUser = FirebaseAuth.instance.currentUser;
    // Definisce isSelf come true se il profilo visualizzato appartiene all'utente corrente.
    final bool isSelf = currentUser != null && currentUser.uid == user.uid;

    return Scaffold(
      // AppBar con titolo centrato e, se l'utente sta visualizzando il proprio profilo,
      // viene mostrata l'icona di modifica.
      appBar: AppBar(
        title: const Text('Profilo'),
        centerTitle: true,
        actions: isOwner
            ? [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/edit_profile_page');
            },
          ),
        ]
            : null,
      ),
      // Il body si basa su uno StreamBuilder che ascolta le variazioni del documento utente in Firestore
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
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
      // Il pulsante "Contatta pilota" viene visualizzato in fondo alla pagina solo se
      // il profilo non appartiene all'utente corrente (isSelf è false)
      bottomNavigationBar: isSelf
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ElevatedButton(
            onPressed: () async {
              // Utilizza il ChatService per creare o ottenere l'identificativo della chat
              // relativa al pilota (basato sul suo uid)
              try {
                final chatId = await ChatService().createOrGetChat(user.uid);
                if (chatId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(chatId: chatId),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Errore nell'avvio della chat.")),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Errore: $e")),
                );
              }
            },
            child: const Text("Contatta pilota"),
          ),
        ),
      ),
    );
  }

  /// Costruisce il corpo principale del profilo utente.
  /// Utilizza un DefaultTabController per gestire le schede "Su di me", "Informazioni" e "Recensioni".
  Widget _buildProfileBody(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    // Recupera l'URL dell'immagine profilo o usa un placeholder se non presente
    final profileImageUrl = user.profileImageUrl;
    final avatar = (profileImageUrl != null && profileImageUrl.isNotEmpty)
        ? NetworkImage(profileImageUrl)
        : const AssetImage('assets/placeholder.png') as ImageProvider;

    // Conteggio dei segnaposti e dei posti salvati
    final segnapostiCount = user.uploadedPlaces.length;
    final salvatiCount = user.favoritePlaces.length;

    return DefaultTabController(
      length: 3,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Header simile ad Instagram: immagine profilo, username e chip per livello/esperienza
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: avatar,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user.username.isNotEmpty)
                            Text(
                              user.username,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),
                          // Mostra chip per livello e ore di volo
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (user.pilotLevel != null)
                                Chip(
                                  backgroundColor: Colors.blue.shade100,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  avatar: const Icon(
                                    Icons.airplanemode_active,
                                    size: 12,
                                  ),
                                  label: Text(
                                    '${user.pilotLevel}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                ),
                              if (user.flightExperience != null)
                                Chip(
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  avatar: const Icon(Icons.timer, size: 12),
                                  label: Text(
                                    '${user.flightExperience} ore di volo',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.grey, thickness: 1),
            const SizedBox(height: 16),
            // Statistiche: "Segnaposti" e, se l'utente è il proprietario, anche "Salvati"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                InkWell(
                  onTap: isOwner
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UploadedPlacesPage(
                          uploadedPlaceIds: user.uploadedPlaces,
                        ),
                      ),
                    );
                  }
                      : null,
                  child: _buildStatItem(context, 'Segnaposti', segnapostiCount.toString()),
                ),
                if (isOwner) ...[
                  Container(
                    height: 40,
                    child: const VerticalDivider(
                      color: Colors.grey,
                      thickness: 1,
                    ),
                  ),
                  InkWell(
                    onTap: isOwner
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FavoritesPage(
                            placeIds: user.favoritePlaces,
                          ),
                        ),
                      );
                    }
                        : null,
                    child: _buildStatItem(context, 'Salvati', salvatiCount.toString()),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.grey, thickness: 1),
            const SizedBox(height: 16),
            // TabBar per le sezioni "Su di me", "Informazioni" e "Recensioni"
            TabBar(
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: "Su di me"),
                Tab(text: "Informazioni"),
                Tab(text: "Recensioni"),
              ],
            ),
            SizedBox(
              height: 500,
              child: TabBarView(
                children: [
                  _AboutMeSection(user: user),
                  _InfoSection(user: user),
                  const _ReviewsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Costruisce un widget per visualizzare ciascuna statistica (per esempio, "Segnaposti" o "Salvati")
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

/// Sezione "Su di me": mostra la biografia e, se disponibile, la mappa della località.
class _AboutMeSection extends StatefulWidget {
  final AppUser user;
  const _AboutMeSection({required this.user});

  @override
  State<_AboutMeSection> createState() => _AboutMeSectionState();
}

class _AboutMeSectionState extends State<_AboutMeSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bio = widget.user.bio ?? "Nessuna descrizione";
    final maxLines = _isExpanded ? null : 5;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Box contenente la biografia
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bio,
                maxLines: maxLines,
                overflow:
                _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!_isExpanded && _needsExpansion(bio))
                InkWell(
                  onTap: () => setState(() => _isExpanded = true),
                  child: Text(
                    "Leggi tutto...",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blueAccent[200],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Se l'utente ha coordinate, mostra la mappa della località
        if (_hasLatLong(widget.user)) ...[
          Text(
            "Località",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              child: _buildOSMMap(widget.user.latitude!, widget.user.longitude!),
            ),
          ),
        ],
      ],
    );
  }

  /// Costruisce una mappa OpenStreetMap della località data
  Widget _buildOSMMap(double lat, double lng) {
    return SizedBox(
      height: 150,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 10,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.altura.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _needsExpansion(String text) => text.length > 200;
  bool _hasLatLong(AppUser user) =>
      (user.latitude != null && user.longitude != null);
}

/// Sezione "Informazioni": mostra droni, social e certificazioni.
class _InfoSection extends StatelessWidget {
  final AppUser user;
  const _InfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user.dronesList.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
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
                        backgroundImage: AssetImage(
                            'assets/logos/${drone.toLowerCase()}.png'),
                      ),
                      label: Text(drone),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (_hasAnySocial(user)) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Social", style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (user.instagram != null && user.instagram!.isNotEmpty)
                  _buildSocialRow(
                    context,
                    icon: FontAwesomeIcons.instagram,
                    label: "Instagram",
                    value: user.instagram!,
                  ),
                if (user.youtube != null && user.youtube!.isNotEmpty)
                  _buildSocialRow(
                    context,
                    icon: FontAwesomeIcons.youtube,
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
          const SizedBox(height: 24),
        ],
        // Sezione certificazioni
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildCertificationInfo(context),
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
          FaIcon(icon, color: theme.colorScheme.primary),
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
      if (user.certificationStatus != null &&
          user.certificationStatus == "approved") {
        certText = "Certificazione verificata";
        certIcon = Icons.check_circle;
        iconColor = Colors.green;
      } else if (user.certificationStatus != null &&
          user.certificationStatus == "pending") {
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

/// Sezione "Recensioni": placeholder per le recensioni.
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Sezione Recensioni",
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
