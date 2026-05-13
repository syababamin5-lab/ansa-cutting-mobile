import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds (REDUCED GREEN INTENSITY BY 50%)
  static const Color background = Color(0xFF02120D); 
  static const Color surface = Color(0xFF051D16); 
  static const Color surfaceLight = Color(0xFF0A2920); 
  
  // Accents
  static const Color primary = Color(0xFF3DE092); 
  static const Color activeTab = Color(0xFF3563FF); 
  static const Color navBackground = Color(0xFF010A08); 
  static const Color progressBar = Color(0xFF6C88FF); 
  
  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF6D8F82); 
  
  // Status
  static const Color success = Color(0xFF3DE092);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFFF4B4B);

  // Gradients (DARKER & MORE NEUTRAL)
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF08261E),
      Color(0xFF02120D),
    ],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3DE092), Color(0xFF00BFA5)],
  );

  static const LinearGradient activeGradient = LinearGradient(
    colors: [Color(0xFF3563FF), Color(0xFF6C88FF)],
  );
}
