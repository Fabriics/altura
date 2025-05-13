import 'package:flutter/material.dart';

class CustomCategoryMarker extends StatelessWidget {
  final String category;

  const CustomCategoryMarker({super.key, required this.category});

  // Mappa categoria -> colore
  Color getMarkerColor() {
    switch (category.toLowerCase().trim()) {
      case 'zona cinematic':
        return Colors.deepPurple;
      case 'event':
        return Colors.green;
      case 'zona freestyle':
        return Colors.orange;
      case 'indoor':
        return Colors.blue;
      case 'zona naturale':
        return Colors.lightGreen;
      case 'zona NoFLy':
        return Colors.red;
      case 'spazio aperto':
        return Colors.teal;
      case 'zona panoramica':
        return Colors.indigo;
      case 'racing':
        return Colors.amber;
      case 'zona urbana':
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  // Mappa categoria -> icona
  IconData getIconData() {
    switch (category.toLowerCase().trim()) {
      case 'zona cinematic':
        return Icons.movie;
      case 'event':
        return Icons.event;
      case 'zona freestyle':
        return Icons.sports_esports;
      case 'zona indoor':
        return Icons.home;
      case 'zona naturale':
        return Icons.nature;
      case 'zona NoFly':
        return Icons.block;
      case 'spazio aperto':
        return Icons.landscape;
      case 'zona panoramica':
        return Icons.panorama;
      case 'racing':
        return Icons.speed;
      case 'zona urbana':
        return Icons.location_city;
      default:
        return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getMarkerColor();
    final icon = getIconData();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          )
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
