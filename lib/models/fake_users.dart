import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class FakeUsersScreen extends StatefulWidget {
  const FakeUsersScreen({super.key});

  @override
  State<FakeUsersScreen> createState() => _FakeUsersScreenState();
}

class _FakeUsersScreenState extends State<FakeUsersScreen> {
  bool _loading = false;
  String _message = '';

  Future<void> addFakeUsers() async {
    setState(() {
      _loading = true;
      _message = 'Aggiunta utenti in corso...';
    });
    final firestore = FirebaseFirestore.instance;

    // Coordinate della posizione base (modifica baseLat e baseLng se necessario)
    const baseLat = 37.33233141;
    const baseLng = -122.0312186;
    final random = Random();

    // Liste di valori possibili per popolare i campi
    final List<String> pilotLevels = ['Beginner', 'Intermediate', 'Expert'];
    final List<String> certificationStatuses = ['pending', 'approved', 'rejected'];
    final List<String> certificationTypes = ['basic', 'advanced', 'professional'];
    final List<String> possibleDroneModels = ['DJI Phantom', 'DJI Mavic', 'Parrot Anafi'];
    final List<String> possibleDroneActivities = ['Volo', 'Cattura immagini', 'Monitoraggio', 'Ispezione'];
    final List<String> possiblePlaces = ['Roma', 'Milano', 'Napoli', 'Torino', 'Firenze'];

    for (int i = 1; i <= 20; i++) {
      // Genera offset casuali: 0.1 gradi circa equivalgono a ~11 km
      double offsetLat = (random.nextDouble() - 0.5) * 0.2; // fra -0.1 e 0.1
      double offsetLng = (random.nextDouble() - 0.5) * 0.2;
      double userLat = baseLat + offsetLat;
      double userLng = baseLng + offsetLng;

      // Calcola la distanza approssimativa in km dalla posizione base
      double distanceKm = sqrt(pow(offsetLat, 2) + pow(offsetLng, 2)) * 111;

      // Ottieni la data corrente in formato ISO8601
      String now = DateTime.now().toIso8601String();

      // Genera il GeoFirePoint con geopoint e geohash
      final geo = GeoFirePoint(GeoPoint(userLat, userLng));

      // Genera valori casuali per alcuni campi booleani e numerici
      bool emailVerified = random.nextBool();
      bool certified = random.nextBool();
      bool available = random.nextBool();
      int flightExperience = random.nextInt(100) + 1; // da 1 a 100 ore/esperienza
      String pilotLevel = pilotLevels[random.nextInt(pilotLevels.length)];
      String certificationStatus = certificationStatuses[random.nextInt(certificationStatuses.length)];
      String certificationType = certificationTypes[random.nextInt(certificationTypes.length)];

      // Seleziona in modo casuale una location dalla lista
      String location = possiblePlaces[random.nextInt(possiblePlaces.length)];

      // Costruisci liste per favoritePlaces e uploadedPlaces
      List<String> favoritePlaces = List.from(possiblePlaces)..shuffle(random);
      favoritePlaces = favoritePlaces.take(2).toList();

      List<String> uploadedPlaces = List.from(possiblePlaces)..shuffle(random);
      uploadedPlaces = uploadedPlaces.take(1).toList();

      // Seleziona alcune attività con i droni
      List<String> droneActivities = List.from(possibleDroneActivities)..shuffle(random);
      droneActivities = droneActivities.take(2).toList();

      // Genera la lista dei droni (sceglie casualmente alcuni modelli)
      List<String> dronesList = [];
      for (var model in possibleDroneModels) {
        if (random.nextBool()) {
          dronesList.add(model);
        }
      }
      if (dronesList.isEmpty) {
        dronesList.add(possibleDroneModels[random.nextInt(possibleDroneModels.length)]);
      }

      // Mappa dei dati utente da salvare, popolando tutti i campi definiti in AppUser
      Map<String, dynamic> data = {
        'uid': 'user_$i',
        'email': 'user$i@example.com',
        'username': 'user$i',
        'profileImageUrl': 'https://picsum.photos/200?random=$i',
        'bio': 'Questo è il profilo fittizio dell\'utente $i per il test di UI/UX.',
        'location': location,
        'favoritePlaces': favoritePlaces,
        'uploadedPlaces': uploadedPlaces,
        'droneActivities': droneActivities,
        'createdAt': now,
        'lastLogin': now,
        'isEmailVerified': emailVerified,
        'isCertified': certified,
        'isAvailable': available,
        'dronesList': dronesList,
        'flightExperience': flightExperience,
        'pilotLevel': pilotLevel,
        'instagram': 'https://instagram.com/user$i',
        'youtube': 'https://youtube.com/user$i',
        'website': 'https://user$i.com',
        'fcmToken': 'fcm_token_user_$i',
        // Includi il geopoint e il geohash per la query geografica
        'locationGeo': {
          'geopoint': geo.geopoint,
          'geohash': geo.geohash,
        },
        'certificationStatus': certificationStatus,
        'certificationUrl': 'https://certification.example.com/user_$i',
        'certificationType': certificationType,
        'distanceKm': distanceKm,
      };

      await firestore.collection('users').doc('user_$i').set(data);
      debugPrint('Aggiunto user_$i con lat: $userLat, lng: $userLng');
    }

    setState(() {
      _loading = false;
      _message = '20 utenti fittizi aggiunti con successo!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inserisci Fake Users')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: addFakeUsers,
              child: const Text('Aggiungi 20 utenti fittizi'),
            ),
            const SizedBox(height: 20),
            Text(_message),
          ],
        ),
      ),
    );
  }
}
