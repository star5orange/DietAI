import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static String get fontFamily => GoogleFonts.inter().fontFamily!;
  static String get displayFontFamily =>
      GoogleFonts.plusJakartaSans().fontFamily!;
  static String get monoFontFamily => GoogleFonts.jetBrainsMono().fontFamily!;

  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 64,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.1,
        letterSpacing: -0.02 * 64,
      );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.15,
        letterSpacing: -0.015 * 48,
      );

  static TextStyle get displaySmall => GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.01 * 36,
      );

  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.25,
        letterSpacing: -0.01 * 32,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
        letterSpacing: -0.005 * 28,
      );

  static TextStyle get headlineSmall => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.35,
      );

  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.01 * 32,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.25,
        letterSpacing: -0.005 * 28,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get h4 => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.35,
      );

  static TextStyle get h5 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get h6 => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.6,
        letterSpacing: 0.01 * 16,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
        letterSpacing: 0.005 * 14,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get bodyXSmall => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.4,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
        letterSpacing: 0.1 * 14,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.3,
        letterSpacing: 0.08 * 12,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
        height: 1.3,
        letterSpacing: 0.08 * 10,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.3,
        letterSpacing: 0.05 * 12,
      );

  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        height: 1.6,
        letterSpacing: 1.5,
        textBaseline: TextBaseline.alphabetic,
      );

  static TextStyle get buttonLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textInverse,
        height: 1.25,
        letterSpacing: 0.02 * 16,
      );

  static TextStyle get buttonMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textInverse,
        height: 1.3,
        letterSpacing: 0.01 * 14,
      );

  static TextStyle get buttonSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textInverse,
        height: 1.3,
        letterSpacing: 0.01 * 12,
      );

  static TextStyle get numberLarge => GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        height: 1.1,
        letterSpacing: -0.01 * 32,
      );

  static TextStyle get numberMedium => GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
        height: 1.2,
      );

  static TextStyle get numberSmall => GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
        height: 1.3,
      );

  static TextStyle get numberXSmall => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.3,
      );

  static TextStyle get success => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.success,
        height: 1.4,
      );

  static TextStyle get warning => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.warning,
        height: 1.4,
      );

  static TextStyle get error => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.error,
        height: 1.4,
      );

  static TextStyle get info => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.info,
        height: 1.4,
      );

  static TextStyle get link => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
        height: 1.4,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primary,
        decorationThickness: 1.5,
      );

  static TextStyle get linkSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
        height: 1.3,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primary,
        decorationThickness: 1,
      );

  static TextStyle get inputText => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
        letterSpacing: 0.005 * 16,
      );

  static TextStyle get inputHint => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textHint,
        height: 1.5,
        letterSpacing: 0.005 * 16,
      );

  static TextStyle get inputLabel => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.3,
        letterSpacing: 0.01 * 14,
      );

  static TextStyle get brand => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        height: 1.2,
        letterSpacing: -0.01 * 24,
      );

  static TextStyle get price => GoogleFonts.jetBrainsMono(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get tag => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textInverse,
        height: 1.2,
        letterSpacing: 0.1 * 10,
      );

  static TextStyle get badge => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textInverse,
        height: 1.2,
        letterSpacing: 0.05 * 11,
      );

  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }

  static TextStyle withOpacity(TextStyle style, double opacity) {
    return style.copyWith(color: style.color?.withValues(alpha: opacity));
  }

  static double responsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) {
      return baseFontSize * 0.9;
    } else if (screenWidth > 600) {
      return baseFontSize * 1.1;
    }
    return baseFontSize;
  }

  static TextStyle responsive(BuildContext context, TextStyle baseStyle) {
    final baseFontSize = baseStyle.fontSize ?? 14;
    final newFontSize = responsiveFontSize(context, baseFontSize);
    final scale = newFontSize / baseFontSize;
    final newLetterSpacing = baseStyle.letterSpacing != null
        ? baseStyle.letterSpacing! * scale
        : null;
    return baseStyle.copyWith(
      fontSize: newFontSize,
      letterSpacing: newLetterSpacing,
    );
  }
}
