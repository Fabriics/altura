import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../services/pilot_service.dart';
import 'chat/chat_page.dart';


/// PilotPage si occupa di mostrare l'interfaccia utente:
/// - Ottiene la posizione corrente e, a partire da essa,
///   esegue una query per i professionisti vicini.
/// - Mostra la lista dei professionisti con informazioni come distanza, bio e immagine.
/// - Permette di contattare il professionista aprendo una chat 1-to-1.
class PilotPage extends StatelessWidget {
  const PilotPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Istanza del service che incapsula la logica.
    final PilotService pilotService = PilotService();

    return FutureBuilder<Position>(
      future: pilotService.getUserPosition(),
      builder: (context, snapshot) {
        // Mostra un loader mentre si ottiene la posizione.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Gestione degli errori nel recupero della posizione.
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Errore nel recupero della posizione:\n${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('Impossibile ottenere la posizione.')),
          );
        }

        // Una volta ottenuta la posizione, esegue la query dei professionisti.
        final userPosition = snapshot.data!;
        return FutureBuilder<List<AppUser>>(
          future: pilotService.getNearbyProfessionals(userPosition),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Scaffold(
                body: Center(child: Text('Errore nel recupero dei professionisti:\n${snap.error}')),
              );
            }
            if (!snap.hasData || snap.data!.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('Nessun professionista trovato nel raggio di 50 km.')),
              );
            }

            // Mostra la lista dei professionisti.
            final professionals = snap.data!;
            return Scaffold(
              appBar: AppBar(
                title: const Text("Professionisti nelle vicinanze"),
                centerTitle: true,
              ),
              body: ListView.builder(
                itemCount: professionals.length,
                itemBuilder: (context, index) {
                  final pro = professionals[index];
                  // Calcola la distanza tra l'utente e il professionista.
                  final lat = pro.latitude ?? 0.0;
                  final lng = pro.longitude ?? 0.0;
                  final distanceKm = pilotService.calculateDistance(
                    userPosition.latitude,
                    userPosition.longitude,
                    lat,
                    lng,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: (pro.profileImageUrl != null && pro.profileImageUrl!.isNotEmpty)
                            ? NetworkImage(pro.profileImageUrl!)
                            : const AssetImage('assets/placeholder.png') as ImageProvider,
                      ),
                      title: Text(
                        pro.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Distanza: ${distanceKm.toStringAsFixed(1)} km"),
                          if (pro.bio != null && pro.bio!.isNotEmpty)
                            Text(
                              pro.bio!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          // Crea o recupera la chat con il professionista e naviga alla ChatPage.
                          final chatId = await pilotService.createChat(pro.uid);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(chatId: chatId),
                            ),
                          );
                        },
                        child: const Text('Contatta'),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
