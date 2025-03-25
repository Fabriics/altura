import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';

/// Il PilotService incapsula tutta la logica relativa al PilotPage:
/// - Ottenimento della posizione utente (con gestione dei permessi)
/// - Query geospaziali per ottenere i professionisti vicini
/// - Calcolo della distanza (formula di Haversine)
/// - Creazione/recupero della chat 1-to-1 con un professionista
class PilotService {
  /// Converte un angolo in gradi in radianti.
  double _degToRad(double deg) => deg * (math.pi / 180);

  /// Calcola la distanza (in km) tra due coordinate lat/lng usando la formula di Haversine.
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Raggio terrestre in km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Ottiene la posizione corrente del dispositivo.
  /// Verifica che il servizio di localizzazione sia abilitato e che i permessi siano concessi.
  Future<Position> getUserPosition() async {
    // Verifica se il servizio di localizzazione è attivo.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Servizio di localizzazione disabilitato sul dispositivo.");
    }

    // Verifica e richiede i permessi di localizzazione.
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

    // Ritorna la posizione corrente.
    return Geolocator.getCurrentPosition();
  }

  /// Esegue una query geospaziale su Firestore per ottenere i professionisti entro [radiusInKm] km dalla [position].
  Future<List<AppUser>> getNearbyProfessionals(Position position, {double radiusInKm = 50}) async {
    // Riferimento alla collezione "users" in Firestore.
    final usersRef = FirebaseFirestore.instance.collection('users');
    // Crea un GeoCollectionReference per eseguire query spaziali.
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(usersRef);
    // Crea un GeoFirePoint centrato sulla posizione corrente.
    final centerPoint = GeoFirePoint(GeoPoint(position.latitude, position.longitude));

    // Esegue la query spaziale.
    final results = await geoCollection.fetchWithin(
      center: centerPoint,
      radiusInKm: radiusInKm,
      field: 'location', // Il campo Firestore che contiene GeoPoint e geohash
      geopointFrom: (data) => data['location']['geopoint'] as GeoPoint,
      strictMode: true,
    );

    // Converte i risultati in una lista di AppUser.
    return results.map((geoDoc) {
      return AppUser.fromMap(geoDoc.data as Map<String, dynamic>);
    }).toList();
  }

  /// Crea o recupera la chat one-to-one con il professionista identificato da [professionalUid].
  Future<String> createChat(String professionalUid) async {
    final chatService = ChatService();
    return chatService.createOrGetChat(professionalUid);
  }
}
