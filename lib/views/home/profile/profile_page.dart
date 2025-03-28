import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/altura_loader.dart';
import 'favorites_page.dart';
import 'updated_places_page.dart';

/// Pagina del profilo utente.
/// Utilizza uno stream per aggiornare in tempo reale i dati utente da Firestore e
/// mostra informazioni come avatar, nome, località e statistiche (Segnaposti, Salvati).
class ProfilePage extends StatelessWidget {
  final AppUser user;
  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final uid = user.uid;

    return Scaffold(
      // L'AppBar utilizza il tema globale, che prevede background blu profondo e icone bianche.
      appBar: AppBar(
        title: const Text('Profilo'),
        centerTitle: true,
        actions: [
          // IconButton per modificare il profilo; l'icona non è hard-coded, usa lo stile del tema.
          IconButton(
            icon: Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/edit_profile');
            },
          ),
        ],
      ),
      // Utilizza uno StreamBuilder per aggiornare in tempo reale i dati dell'utente.
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

          // Costruisce il corpo del profilo utilizzando i dati aggiornati.
          return _buildProfileBody(context, updatedUser);
        },
      ),
    );
  }

  /// Metodo che costruisce il corpo del profilo utente.
  /// Mostra avatar, nome, località, statistiche e una TabBar per ulteriori sezioni.
  Widget _buildProfileBody(BuildContext context, AppUser user) {
    final theme = Theme.of(context);

    // Avatar: se è presente una URL, la usa; altrimenti utilizza un'immagine di placeholder.
    final profileImageUrl = user.profileImageUrl;
    final avatar = (profileImageUrl != null && profileImageUrl.isNotEmpty)
        ? NetworkImage(profileImageUrl)
        : const AssetImage('assets/placeholder.png') as ImageProvider;

    // Contatori per segnaposti e posti salvati.
    final segnapostiCount = user.uploadedPlaces.length;
    final salvatiCount = user.favoritePlaces.length;

    return DefaultTabController(
      length: 2, // Modifica questo valore se aggiungi ulteriori tab (es. "Servizi")
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar utente con un CircleAvatar.
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: avatar,
            ),
            const SizedBox(height: 12),
            // Nome utente, se disponibile.
            if (user.username.isNotEmpty)
              Text(
                user.username,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  // Impostazione colore: usa il tema per mantenere coerenza (eventualmente theme.colorScheme.onSurface o simile)
                  color: theme.colorScheme.onSurface,
                ),
              ),
            // Visualizza la località, se presente.
            if (user.location != null && user.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.location!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Row con i contatori: "Segnaposti" e "Salvati".
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
            // TabBar per sezioni aggiuntive, con uno sfondo che utilizza il fillColor dell'inputDecorationTheme.
            Container(
              color: Theme.of(context).inputDecorationTheme.fillColor,
              child: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: "Su di me"),
                  Tab(text: "Informazioni"),
                  // Aggiungi ulteriori tab se necessario, ad esempio: Tab(text: "Servizi"),
                ],
              ),
            ),
            // Visualizza il contenuto della tab selezionata in una TabBarView.
            SizedBox(
              height: 500, // Altezza fissa; puoi renderla dinamica se necessario.
              child: TabBarView(
                children: [
                  // Sezione "Su di me"
                  _AboutMeSection(user: user),
                  // Sezione "Informazioni"
                  _InfoSection(user: user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Costruisce un widget per visualizzare un contatore (statistica) con etichetta.
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

/// Sezione "Su di me" che mostra la biografia e una mappa statica della località.
/// Include anche un'opzione per espandere il testo se troppo lungo.
class _AboutMeSection extends StatefulWidget {
  final AppUser user;
  const _AboutMeSection({super.key, required this.user});

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
    // Se il testo è espanso, non limitare il numero di righe
    final maxLines = _isExpanded ? null : 5;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Testo della biografia con possibilità di espansione
        Text(
          bio,
          maxLines: maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        // Se il testo necessita di espansione, mostra il link "Leggi tutto"
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
        const SizedBox(height: 24),
        // Se l'utente ha latitudine e longitudine, mostra la sezione della mappa.
        if (_hasLatLong(widget.user)) ...[
          Text(
            "Località",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          // Mostra la località come stringa, con stile allineato al tema.
          if (widget.user.location != null && widget.user.location!.isNotEmpty)
            Text(
              widget.user.location!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          const SizedBox(height: 8),
          // Costruisce e visualizza una mappa statica tramite NetworkImage.
          _buildStaticMap(widget.user.latitude!, widget.user.longitude!),
        ],
      ],
    );
  }

  /// Costruisce l'URL per una mappa statica e la visualizza in un'immagine.
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
      ),
    );
  }

  /// Determina se il testo richiede espansione in base alla sua lunghezza.
  bool _needsExpansion(String text) {
    return text.length > 200;
  }

  /// Verifica se l'utente ha latitudine e longitudine.
  bool _hasLatLong(AppUser user) {
    return (user.latitude != null && user.longitude != null);
  }
}

/// Sezione "Informazioni" che mostra dati come droni e social.
/// I dati social vengono visualizzati con chip e righe in base ai valori presenti.
class _InfoSection extends StatelessWidget {
  final AppUser user;
  const _InfoSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Se l'utente ha droni, li mostra in un Wrap con Chip
        if (user.drones.isNotEmpty) ...[
          Text("I miei droni", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.drones.map((drone) {
              return Chip(
                label: Text(drone),
                backgroundColor: theme.colorScheme.primary,
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        // Se sono presenti dati social, li mostra in una lista.
        if (_hasAnySocial(user)) ...[
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
      ],
    );
  }

  /// Determina se l'utente ha almeno un social link.
  bool _hasAnySocial(AppUser user) {
    return (user.instagram != null && user.instagram!.isNotEmpty) ||
        (user.youtube != null && user.youtube!.isNotEmpty) ||
        (user.website != null && user.website!.isNotEmpty);
  }

  /// Costruisce una riga per mostrare un'informazione social.
  Widget _buildSocialRow(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
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
}
