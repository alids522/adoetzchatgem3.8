import 'package:flutter/material.dart';

/// Precision Neutral Messenger v2.0 Design Tokens (Section 4 of PRD v2.0)
/// Calibrated for WCAG 2.2 AA contrast, zero neon/glow/glassmorphism.
@immutable
class AdoetzPalette extends ThemeExtension<AdoetzPalette> {
  final Color bgCanvas;
  final Color bgSurface;
  final Color bgElevated;
  final Color bgOverlay;
  final Color accentPrimary;
  final Color accentOnPrimary;
  final Color accentInteractive;
  final Color accentSubtle;
  final Color bubbleIncomingBg;
  final Color bubbleIncomingBorder;
  final Color bubbleIncomingText;
  final Color bubbleOutgoingBg;
  final Color bubbleOutgoingText;
  final Color bubbleQuoteOutgoingBg;
  final Color bubbleQuoteIncomingBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderHairline;
  final Color statusSuccess;
  final Color statusWarning;
  final Color statusDanger;
  final Color tickRead;
  final bool isDark;

  const AdoetzPalette({
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgElevated,
    required this.bgOverlay,
    required this.accentPrimary,
    required this.accentOnPrimary,
    required this.accentInteractive,
    required this.accentSubtle,
    required this.bubbleIncomingBg,
    required this.bubbleIncomingBorder,
    required this.bubbleIncomingText,
    required this.bubbleOutgoingBg,
    required this.bubbleOutgoingText,
    required this.bubbleQuoteOutgoingBg,
    required this.bubbleQuoteIncomingBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderHairline,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusDanger,
    required this.tickRead,
    required this.isDark,
  });

  /// Dark Mode (Default Charcoal) — Section 4.1
  static const dark = AdoetzPalette(
    bgCanvas: Color(0xFF0E1013),
    bgSurface: Color(0xFF15181E),
    bgElevated: Color(0xFF1E232B),
    bgOverlay: Color(0xFF272D37),
    accentPrimary: Color(0xFF3B82C4),
    accentOnPrimary: Color(0xFFFFFFFF),
    accentInteractive: Color(0xFF6BA8E5),
    accentSubtle: Color(0xFF1A2B3C),
    bubbleIncomingBg: Color(0xFF1D222A),
    bubbleIncomingBorder: Color(0xFF232933),
    bubbleIncomingText: Color(0xFFF1F5F9),
    bubbleOutgoingBg: Color(0xFF1E3E5C),
    bubbleOutgoingText: Color(0xFFF3F7FB),
    bubbleQuoteOutgoingBg: Color(0xFF142B40),
    bubbleQuoteIncomingBg: Color(0xFF151920),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A0B0),
    textMuted: Color(0xFF687382),
    borderHairline: Color(0xFF232933),
    statusSuccess: Color(0xFF48B884),
    statusWarning: Color(0xFFE5A93B),
    statusDanger: Color(0xFFEE6B6B),
    tickRead: Color(0xFF64B5F6),
    isDark: true,
  );

  /// Light Mode (Crisp Alabaster) — Section 4.1
  static const light = AdoetzPalette(
    bgCanvas: Color(0xFFF6F7F9),
    bgSurface: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFEFF2F6),
    bgOverlay: Color(0xFFE4E9F0),
    accentPrimary: Color(0xFF1F5F99),
    accentOnPrimary: Color(0xFFFFFFFF),
    accentInteractive: Color(0xFF1D5B94),
    accentSubtle: Color(0xFFE3EFFA),
    bubbleIncomingBg: Color(0xFFFFFFFF),
    bubbleIncomingBorder: Color(0xFFE2E7EE),
    bubbleIncomingText: Color(0xFF141920),
    bubbleOutgoingBg: Color(0xFFD8ECFF),
    bubbleOutgoingText: Color(0xFF102233),
    bubbleQuoteOutgoingBg: Color(0xFFC5E1FC),
    bubbleQuoteIncomingBg: Color(0xFFF2F4F7),
    textPrimary: Color(0xFF141920),
    textSecondary: Color(0xFF5A6573),
    textMuted: Color(0xFF7E8997),
    borderHairline: Color(0xFFE3E8EF),
    statusSuccess: Color(0xFF1E7E52),
    statusWarning: Color(0xFFB2720E),
    statusDanger: Color(0xFFC82323),
    tickRead: Color(0xFF1976D2),
    isDark: false,
  );

  static AdoetzPalette of(BuildContext context) {
    return Theme.of(context).extension<AdoetzPalette>() ?? dark;
  }

  @override
  AdoetzPalette copyWith({
    Color? bgCanvas,
    Color? bgSurface,
    Color? bgElevated,
    Color? bgOverlay,
    Color? accentPrimary,
    Color? accentOnPrimary,
    Color? accentInteractive,
    Color? accentSubtle,
    Color? bubbleIncomingBg,
    Color? bubbleIncomingBorder,
    Color? bubbleIncomingText,
    Color? bubbleOutgoingBg,
    Color? bubbleOutgoingText,
    Color? bubbleQuoteOutgoingBg,
    Color? bubbleQuoteIncomingBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderHairline,
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusDanger,
    Color? tickRead,
    bool? isDark,
  }) {
    return AdoetzPalette(
      bgCanvas: bgCanvas ?? this.bgCanvas,
      bgSurface: bgSurface ?? this.bgSurface,
      bgElevated: bgElevated ?? this.bgElevated,
      bgOverlay: bgOverlay ?? this.bgOverlay,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentOnPrimary: accentOnPrimary ?? this.accentOnPrimary,
      accentInteractive: accentInteractive ?? this.accentInteractive,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      bubbleIncomingBg: bubbleIncomingBg ?? this.bubbleIncomingBg,
      bubbleIncomingBorder: bubbleIncomingBorder ?? this.bubbleIncomingBorder,
      bubbleIncomingText: bubbleIncomingText ?? this.bubbleIncomingText,
      bubbleOutgoingBg: bubbleOutgoingBg ?? this.bubbleOutgoingBg,
      bubbleOutgoingText: bubbleOutgoingText ?? this.bubbleOutgoingText,
      bubbleQuoteOutgoingBg: bubbleQuoteOutgoingBg ?? this.bubbleQuoteOutgoingBg,
      bubbleQuoteIncomingBg: bubbleQuoteIncomingBg ?? this.bubbleQuoteIncomingBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderHairline: borderHairline ?? this.borderHairline,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusDanger: statusDanger ?? this.statusDanger,
      tickRead: tickRead ?? this.tickRead,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AdoetzPalette lerp(ThemeExtension<AdoetzPalette>? other, double t) {
    if (other is! AdoetzPalette) return this;
    return AdoetzPalette(
      bgCanvas: Color.lerp(bgCanvas, other.bgCanvas, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      bgOverlay: Color.lerp(bgOverlay, other.bgOverlay, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentOnPrimary: Color.lerp(accentOnPrimary, other.accentOnPrimary, t)!,
      accentInteractive: Color.lerp(accentInteractive, other.accentInteractive, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      bubbleIncomingBg: Color.lerp(bubbleIncomingBg, other.bubbleIncomingBg, t)!,
      bubbleIncomingBorder: Color.lerp(bubbleIncomingBorder, other.bubbleIncomingBorder, t)!,
      bubbleIncomingText: Color.lerp(bubbleIncomingText, other.bubbleIncomingText, t)!,
      bubbleOutgoingBg: Color.lerp(bubbleOutgoingBg, other.bubbleOutgoingBg, t)!,
      bubbleOutgoingText: Color.lerp(bubbleOutgoingText, other.bubbleOutgoingText, t)!,
      bubbleQuoteOutgoingBg: Color.lerp(bubbleQuoteOutgoingBg, other.bubbleQuoteOutgoingBg, t)!,
      bubbleQuoteIncomingBg: Color.lerp(bubbleQuoteIncomingBg, other.bubbleQuoteIncomingBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderHairline: Color.lerp(borderHairline, other.borderHairline, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusDanger: Color.lerp(statusDanger, other.statusDanger, t)!,
      tickRead: Color.lerp(tickRead, other.tickRead, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Precision Typography Scale — Section 4.2
class AdoetzTypography {
  const AdoetzTypography._();

  static TextStyle screenTitle(Color color) => TextStyle(
        fontSize: 20.0,
        height: 26.0 / 20.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.20,
        color: color,
      );

  static TextStyle sectionHeader(Color color) => TextStyle(
        fontSize: 13.0,
        height: 18.0 / 13.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.26,
        color: color,
      );

  static TextStyle listTitle(Color color, {bool unread = false}) => TextStyle(
        fontSize: 16.0,
        height: 22.0 / 16.0,
        fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: 0.0,
        color: color,
      );

  static TextStyle chatBody(Color color) => TextStyle(
        fontSize: 15.5,
        height: 21.5 / 15.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
        color: color,
      );

  static TextStyle listSubtitle(Color color) => TextStyle(
        fontSize: 14.0,
        height: 19.0 / 14.0,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.07,
        color: color,
      );

  static TextStyle buttonLabel(Color color) => TextStyle(
        fontSize: 14.5,
        height: 20.0 / 14.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.145,
        color: color,
      );

  static TextStyle captionTime(Color color, {bool bold = false}) => TextStyle(
        fontSize: 11.5,
        height: 15.0 / 11.5,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        letterSpacing: 0.115,
        color: color,
      );

  static TextStyle monoKey(Color color) => TextStyle(
        fontSize: 13.0,
        height: 19.0 / 13.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.52,
        fontFamily: 'monospace',
        color: color,
      );
}

/// Spatial Grid & Component Dimensions — Section 4.3 & Section 5
class AdoetzDimensions {
  const AdoetzDimensions._();

  static const double topAppBarHeight = 56.0;
  static const double bottomNavBarHeight = 64.0;
  static const double minTouchTarget = 48.0;
  static const double chatListItemHeight = 74.0;
  static const double callListItemHeight = 68.0;
  static const double chatDividerIndent = 76.0; // 16dp + 48dp + 12dp

  static const double radiusButton = 10.0;
  static const double radiusSearchOrComposer = 22.0;
  static const double radiusComposerMultiline = 14.0;
  static const double radiusBubble = 14.0;
  static const double radiusBubbleTail = 4.0;
  static const double radiusSheetOrDialog = 16.0;
  static const double radiusFab = 14.0;

  static const double bubbleMinWidth = 88.0;
  static const double bubbleMaxWidthFraction = 0.78;
  static const double bubbleSameGroupSpacing = 3.0;
  static const double bubbleDiffGroupSpacing = 10.0;

  static const double composerMinHeight = 44.0;
  static const double composerMaxHeight = 124.0;
  static const double swipeReplyThreshold = 56.0;
}
