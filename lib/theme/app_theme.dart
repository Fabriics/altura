import 'package:flutter/material.dart' show BorderRadius, BorderSide, Brightness, ButtonTextTheme, ButtonThemeData, Color, ColorScheme, Colors, EdgeInsets, ElevatedButton, ElevatedButtonThemeData, FontWeight, IconThemeData, InputDecorationTheme, OutlineInputBorder, RoundedRectangleBorder, TextStyle, TextTheme, ThemeData;

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF02398E), // Blu scuro per il tema principale
    onPrimary: Colors.white, // Colore del testo e icone su sfondi primari
    secondary: const Color(0xFF64B5F6), // Blu chiaro per gli elementi secondari
    onSecondary: Colors.white, // Sfondo scuro generale
    surface: const Color(0xFF1E1E1E), // Colore delle card o superfici
    onSurface: Colors.white, // Colore del testo su superfici
    error: Colors.redAccent, // Colore per messaggi di errore
    onError: Colors.white, // Colore del testo su sfondi di errore
  ),
  scaffoldBackgroundColor: Colors.white, // Sfondo della schermata principale
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.black), // Titoli principali
    headlineMedium: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w700, color: Colors.black), // Titoli medi
    headlineSmall: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w400, color: Colors.black), // Sottotitoli grandi
    titleLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w500, color: Colors.black), // Sottotitoli medi
    bodyLarge: TextStyle(fontSize: 20.0, color: Colors.black), // Testo principale
    bodyMedium: TextStyle(fontSize: 18.0, color: Colors.black), // Testo descrittivo più piccolo
    labelLarge: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w400, color: Colors.grey), // Testo piccolo, es: per pulsanti o indicazioni
  ),

  buttonTheme: ButtonThemeData(
    buttonColor: const Color(0xFF0D47A1), // Colore dei pulsanti primari
    textTheme: ButtonTextTheme.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF0D47A1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: Colors.white70),
    labelStyle: const TextStyle(color: Colors.white),
  ),
  iconTheme: const IconThemeData(color: Colors.black),
);
