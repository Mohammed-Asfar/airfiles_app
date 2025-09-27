import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors - inspired by the AirFiles icon spiral design
  static const Color primaryColor = Color(0xFF279A97); // Main teal from icon
  static const Color primaryVariant = Color(0xFF1F7A77); // Darker teal
  static const Color secondary = Color(0xFF4ECDC4); // Lighter teal/cyan
  static const Color secondaryVariant = Color(0xFF26A69A); // Medium teal
  
  // Icon spiral colors - matching the beautiful gradient
  static const Color spiralTeal = Color(0xFF279A97); // Main spiral color
  static const Color spiralTealLight = Color(0xFF4ECDC4); // Light spiral
  static const Color spiralTealDark = Color(0xFF1F7A77); // Dark spiral
  
  // Background gradients - inspired by air/wind theme with teal accent
  static const Color gradientStart = Color(0xFF4ECDC4); // Light teal
  static const Color gradientMid = Color(0xFF279A97); // Main teal
  static const Color gradientEnd = Color(0xFF1F7A77); // Dark teal
  
  // UI Colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  
  // Text colors
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF1E293B);
  static const Color onSurface = Color(0xFF334155);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Server status colors
  static const Color serverRunning = success;
  static const Color serverStopped = Color(0xFF6B7280);
  static const Color serverError = error;
  
  // Dark theme colors - enhanced for teal theme
  static const Color darkBackground = Color(0xFF0A1A1A); // Very dark with teal undertone
  static const Color darkSurface = Color(0xFF1A2E2E); // Dark teal surface
  static const Color darkSurfaceVariant = Color(0xFF2A3E3E); // Medium dark teal
  static const Color darkOnBackground = Color(0xFFF1F9F9); // Light text with teal tint
  static const Color darkOnSurface = Color(0xFFE2F4F4); // Light teal text
  static const Color darkOnSurfaceVariant = Color(0xFF94C7C7); // Medium teal text
  
  // Dark theme accent colors
  static const Color darkAccent = Color(0xFF4ECDC4); // Bright teal for accents
  static const Color darkAccentVariant = Color(0xFF26A69A); // Medium accent
  
  // File type colors - enhanced with teal theme
  static const Color fileImage = Color(0xFFEC4899);
  static const Color fileVideo = Color(0xFF8B5CF6);
  static const Color fileAudio = Color(0xFF4ECDC4); // Teal for audio
  static const Color fileDocument = Color(0xFFF59E0B);
  static const Color fileArchive = Color(0xFF84CC16);
  static const Color fileGeneric = Color(0xFF6B7280);
  
  // Opacity levels
  static const double highOpacity = 0.87;
  static const double mediumOpacity = 0.60;
  static const double lowOpacity = 0.38;
  static const double disabledOpacity = 0.12;
}
