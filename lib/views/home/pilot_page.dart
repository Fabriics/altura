import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// geoflutterfire_plus per la query geospaziale
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
// geolocator per permessi e coordinate
import 'package:geolocator/geolocator.dart';

import '../../models/user.dart';
import '../../services/chat.dart';
import 'chat/chat_page.dart';

class PilotPage extends StatelessWidget {
  const PilotPage({Key? key}) : super(key: key);

  /// Calcola la distanza (in km) tra due coordinate lat/long (Haversine formula).
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Raggio terrestre in km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  /// Ottiene la posizione utente usando Geolocator, gestendo i permessi.
  Future<Position> _getUserPosition() async {
    // 1) Verifica se i servizi di localizzazione sono abilitati
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Servizio di localizzazione disabilitato sul dispositivo.");
    }

    // 2) Verifica i permessi
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Permesso di localizzazione negato dall'utente.");
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Permesso di localizzazione negato permanentemente.");
    }

    // 3) Se arrivi qui, i permessi sono garantiti
    //    Ritorna la posizione attuale (con accuratezza default)
    return Geolocator.getCurrentPosition();
  }

  /// Query a Firestore (geospaziale) per ottenere i professionisti entro 50 km.
  Future<List<AppUser>> _getNearbyProfessionals(Position position) async {
    // 1) Riferimento alla collezione "users"
    final usersRef = FirebaseFirestore.instance.collection('users');

    // 2) Creiamo un GeoCollectionReference usando geoflutterfire_plus
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(usersRef);

    // 3) Creiamo un GeoFirePoint dal Position
    final centerPoint = GeoFirePoint(GeoPoint(position.latitude, position.longitude));

    // 4) Eseguiamo la query "fetchWithin" (raggio = 50 km)
    //    - 'location' deve contenere un GeoPoint e un geohash
    //    - Per generare geohash/GeoPoint, vedi la logica di salvataggio in Firestore
    final results = await geoCollection.fetchWithin(
      center: centerPoint,
      radiusInKm: 50,
      field: 'location', // deve corrispondere al campo in Firestore
      geopointFrom: (data) => data['location']['geopoint'] as GeoPoint,
      strictMode: true,
    );

    // 5) Convertiamo i risultati in AppUser
    return results.map((geoDoc) {
      return AppUser.fromMap(geoDoc.data as Map<String, dynamic>);
    }).toList();
  }

  /// Crea o recupera la chat 1-to-1 con l'utente [professionalUid].
  Future<String> _createChat(String professionalUid) async {
    final chatService = ChatService();
    return chatService.createOrGetChat(professionalUid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      // 1) Otteniamo la posizione via Geolocator
      future: _getUserPosition(),
      builder: (context, snapshot) {
        // Mentre carichiamo la posizione, mostriamo un loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Se errore (permessi negati o altro)
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Errore nel recupero della posizione:\n${snapshot.error}')),
          );
        }
        // Se non abbiamo dati (caso raro)
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('Impossibile ottenere la posizione.')),
          );
        }

        // 2) Ora che abbiamo la posizione, facciamo la query dei professionisti
        final userPosition = snapshot.data!;
        return FutureBuilder<List<AppUser>>(
          future: _getNearbyProfessionals(userPosition),
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

            // 3) Mostriamo la lista di professionisti
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
                  // Calcoliamo la distanza
                  final lat = pro.latitude ?? 0.0;
                  final lng = pro.longitude ?? 0.0;
                  final distanceKm = _calculateDistance(
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
                          // Distanza
                          Text("Distanza: ${distanceKm.toStringAsFixed(1)} km"),
                          // Breve bio
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
                          // Creiamo/Recuperiamo la chat con l'utente
                          final chatId = await _createChat(pro.uid);
                          // Navighiamo alla chat
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
