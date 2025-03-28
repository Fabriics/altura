import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  fontFamily: 'Poppins', // Font principale Altura

  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF0A2342),        // Blu profondo
    onPrimary: Colors.white,
    secondary: const Color(0xFF4FA3F7),      // Azzurro Altura
    onSecondary: Colors.white,
    surface: const Color(0xFFD9E4F5),        // Grigio chiaro superfici
    onSurface: const Color(0xFF1C1F2A),      // Testo scuro su sfondo chiaro
    error: Colors.redAccent,
    onError: Colors.white,
  ),

  scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Sfondo chiaro generale

  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: Color(0xFF0A2342)),
    headlineMedium: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w700, color: Color(0xFF0A2342)),
    headlineSmall: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w500, color: Color(0xFF1C1F2A)),
    titleLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w500, color: Color(0xFF0A2342)),
    bodyLarge: TextStyle(fontSize: 18.0, color: Color(0xFF1C1F2A)),
    bodyMedium: TextStyle(fontSize: 16.0, color: Color(0xFF1C1F2A)),
    labelLarge: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w400, color: Colors.grey),
  ),

  buttonTheme: ButtonThemeData(
    buttonColor: const Color(0xFF0A2342),
    textTheme: ButtonTextTheme.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF0A2342),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFD9E4F5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: Color(0xFF1C1F2A)),
    labelStyle: const TextStyle(color: Color(0xFF0A2342)),
  ),

  iconTheme: const IconThemeData(color: Color(0xFF0A2342)),

  // Impostazione globale per le AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0A2342), // Utilizza il blu profondo
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white, // Testo bianco
    ),
    iconTheme: IconThemeData(
      color: Colors.white, // Icone (freccia back, etc.) in bianco
    ),
  ),
);
