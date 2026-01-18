import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AirFilesLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? textColor;
  final bool showBackground;
  
  const AirFilesLogo({
    super.key,
    this.size = 48.0,
    this.showText = false,
    this.textColor,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: showBackground ? BoxDecoration(
            gradient: AppTheme.spiralGradient,
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(
                color: AppColors.spiralTeal.withOpacity(0.3),
                blurRadius: size * 0.15,
                offset: Offset(0, size * 0.04),
              ),
            ],
          ) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.25),
            child: Image.asset(
              'assets/logo3.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icon if asset fails to load
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    gradient: AppTheme.spiralGradient,
                    borderRadius: BorderRadius.circular(size * 0.25),
                  ),
                  child: Icon(
                    Icons.air,
                    color: Colors.white,
                    size: size * 0.6,
                  ),
                );
              },
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.25),
          Text(
            'AirFiles',
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.bold,
              color: textColor ?? Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}