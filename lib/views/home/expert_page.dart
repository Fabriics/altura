import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/expert_service.dart';

class ExpertPage extends StatelessWidget {
  const ExpertPage({super.key});

  // Widget helper per realizzare uno step del timeline.
  // Ogni step è rappresentato da un'icona a sinistra (da Font Awesome)
  // e da un box con titolo e descrizione.
  Widget buildTimelineStep(
      IconData iconData,
      String title,
      String description,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Area dell'icona e spazio per la linea verticale
        SizedBox(
          width: 40,
          child: Container(
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: FaIcon(iconData, size: 20, color: Colors.blueAccent),
          ),
        ),
        const SizedBox(width: 12),
        // Box contenente titolo e descrizione
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Header delle sezioni, centrato
  Widget buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  // Widget helper per gli item dei servizi offerti.
  Widget buildServiceItem(IconData iconData, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(iconData, size: 24, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper per il pulsante "Inizia ora"
  Widget buildStartButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => ExpertService.onStartPressed(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        textStyle: const TextStyle(fontSize: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: const Text("Inizia ora"),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Costante per la sezione "Flessibilità" per definire dimensioni
    const double bgHeight = 300;
    const double overlayHeight = 150; // altezza del container flessibilità

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diventa Esperto'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Immagine header con gradient overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: Image.asset(
                    'assets/drone.png',
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sezione: Titolo e descrizione centrati
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Text(
                    "Diventa un Esperto su Altura",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Condividi la tua esperienza, aiuta altri appassionati e inizia a guadagnare. Attiva i servizi che desideri offrire e ricevi richieste da chi ha bisogno del tuo aiuto.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  const SizedBox(height: 24),
                  buildStartButton(context),
                ],
              ),
            ),

            // Sezione: "Come funziona" (titolo della timeline)
            const SizedBox(height: 48),
            buildSectionHeader("Come funziona"),
            const SizedBox(height: 24),

            // Timeline dei passaggi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.blueAccent),
                  ),
                  Column(
                    children: [
                      buildTimelineStep(
                        FontAwesomeIcons.user,
                        "Crea il tuo profilo da esperto",
                        "Imposta il tuo profilo professionale e racconta in cosa sei esperto: PID tuning, zone legali, saldatura, editing video… più sei chiaro, più verrai contattato!",
                      ),
                      const SizedBox(height: 24),
                      buildTimelineStep(
                        FontAwesomeIcons.briefcase,
                        "Scegli i servizi da offrire",
                        "Decidi come vuoi aiutare: rispondere a domande tecniche, offrire sessioni 1:1 o pubblicare contenuti esclusivi.",
                      ),
                      const SizedBox(height: 24),
                      buildTimelineStep(
                        FontAwesomeIcons.comments,
                        "Ricevi richieste dagli utenti",
                        "Gli utenti ti trovano tramite ricerca o inviano richieste automatiche in base alle tue competenze.",
                      ),
                      const SizedBox(height: 24),
                      buildTimelineStep(
                        FontAwesomeIcons.moneyBillWave,
                        "Guadagna con le tue risposte",
                        "Ricevi una mancia per ogni risposta utile o un compenso per consulenze e contenuti esclusivi, gestiti tramite Stripe.",
                      ),
                      const SizedBox(height: 24),
                      buildTimelineStep(
                        FontAwesomeIcons.trophy,
                        "Costruisci la tua reputazione",
                        "Più aiuti, più recensioni e badge ottieni. Con una buona reputazione aumentano visibilità e richieste.",
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Pulsante intermedio
            const SizedBox(height: 40),
            buildStartButton(context),

            // Sezione: Servizi che puoi offrire
            const SizedBox(height: 48),
            buildSectionHeader("Servizi che puoi offrire come esperto"),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  buildServiceItem(
                    FontAwesomeIcons.comments,
                    "Risposte a domande tecniche",
                    "Ricevi domande su temi specifici e rispondi per mancia o compenso fisso.",
                  ),
                  buildServiceItem(
                    FontAwesomeIcons.video,
                    "Sessioni 1:1 personalizzate",
                    "Offri supporto diretto tramite chat o videochiamata per guidare l'utente.",
                  ),
                  buildServiceItem(
                    FontAwesomeIcons.bookOpen,
                    "Contenuti esclusivi",
                    "Condividi guide, video e configurazioni per chi ha effettuato un pagamento o sottoscritto un abbonamento.",
                  ),
                ],
              ),
            ),

            // Pulsante intermedio
            const SizedBox(height: 10),

            // Sezione: Flessibilità totale
            // Il container verrà posizionato in modo tale da sovrapporsi per metà alla foto (drone2)
            const SizedBox(height: 48),
            // Usiamo uno Stack con clipBehavior impostato su Clip.none per permettere l'overflow
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Immagine di sfondo
                Container(
                  height: bgHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/drone2.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Container flessibilità posizionato in modo che metà sia sopra e metà sotto la foto
                Positioned(
                  left: 24,
                  right: 24,
                  top: bgHeight - (overlayHeight / 2),
                  child: Container(
                    height: overlayHeight,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Flessibilità: scegli i servizi da attivare, decidi quando rispondere e imposta il valore delle tue consulenze, tutto come preferisci.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Ultimo pulsante
            const SizedBox(height: 80),
            buildStartButton(context),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
