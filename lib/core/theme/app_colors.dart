import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors - inspired by air/wind theme
  static const Color primaryColor = Color(0xFF4F46E5); // Indigo
  static const Color primaryVariant = Color(0xFF3730A3); // Darker indigo
  static const Color secondary = Color(0xFF06B6D4); // Cyan - represents airflow
  static const Color secondaryVariant = Color(0xFF0891B2); // Darker cyan
  
  // Background gradients
  static const Color gradientStart = Color(0xFF667EEA); // Light purple
  static const Color gradientEnd = Color(0xFF764BA2); // Darker purple
  
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
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkOnBackground = Color(0xFFF1F5F9);
  static const Color darkOnSurface = Color(0xFFE2E8F0);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  
  // File type colors
  static const Color fileImage = Color(0xFFEC4899);
  static const Color fileVideo = Color(0xFF8B5CF6);
  static const Color fileAudio = Color(0xFF06B6D4);
  static const Color fileDocument = Color(0xFFF59E0B);
  static const Color fileArchive = Color(0xFF84CC16);
  static const Color fileGeneric = Color(0xFF6B7280);
  
  // Opacity levels
  static const double highOpacity = 0.87;
  static const double mediumOpacity = 0.60;
  static const double lowOpacity = 0.38;
  static const double disabledOpacity = 0.12;
}
