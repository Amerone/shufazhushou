import 'package:flutter/material.dart';

const kPrimaryBlue = Color(0xFF2F3A2F);
const kGreen = Color(0xFF6F8A68);
const kOrange = Color(0xFFC08A55);
const kRed = Color(0xFFB26A5D);

const kPaper = Color(0xFFF5F1E8);
const kSealRed = Color(0xFFB44A3E);
const kInkSecondary = Color(0xFF8B7D6B);
const kPaperCard = Color(0xFFFCFAF5);

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kPrimaryBlue,
    brightness: Brightness.light,
  ).copyWith(
    primary: kPrimaryBlue,
    secondary: kSealRed,
    error: const Color(0xFFB85042),
    surface: kPaperCard,
    onSurface: const Color(0xFF2A2A24),
  );

  final baseTextTheme = const TextTheme(
    bodyLarge: TextStyle(fontFamily: 'NotoSansSC'),
    bodyMedium: TextStyle(fontFamily: 'NotoSansSC'),
    bodySmall: TextStyle(fontFamily: 'NotoSansSC'),
    labelLarge: TextStyle(fontFamily: 'NotoSansSC'),
    labelMedium: TextStyle(fontFamily: 'NotoSansSC'),
    labelSmall: TextStyle(fontFamily: 'NotoSansSC'),
  );

  final textTheme = baseTextTheme.copyWith(
    headlineSmall: const TextStyle(
      fontFamily: 'serif',
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Color(0xFF28261F),
    ),
    titleLarge: const TextStyle(
      fontFamily: 'serif',
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: Color(0xFF302D25),
    ),
    titleMedium: const TextStyle(
      fontFamily: 'serif',
      fontWeight: FontWeight.w600,
      color: Color(0xFF3A352B),
    ),
    titleSmall: const TextStyle(
      fontFamily: 'NotoSansSC',
      fontWeight: FontWeight.w600,
      color: Color(0xFF3A352B),
    ),
    bodyMedium: const TextStyle(
      fontFamily: 'NotoSansSC',
      color: Color(0xFF474034),
    ),
    bodySmall: const TextStyle(
      fontFamily: 'NotoSansSC',
      color: kInkSecondary,
    ),
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    fontFamily: 'NotoSansSC',
    scaffoldBackgroundColor: kPaper,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF2F2A23),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: 0.6,
        color: Color(0xFF2F2A23),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.86),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: kInkSecondary.withValues(alpha: 0.16)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.74),
      hintStyle: const TextStyle(color: kInkSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: kInkSecondary.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: kInkSecondary.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: kPrimaryBlue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryBlue,
        side: BorderSide(color: kInkSecondary.withValues(alpha: 0.34)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryBlue,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : kPrimaryBlue,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? kPrimaryBlue : Colors.white.withValues(alpha: 0.74),
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: kInkSecondary.withValues(alpha: 0.26)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.7),
      selectedColor: kSealRed.withValues(alpha: 0.18),
      disabledColor: kInkSecondary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(color: Color(0xFF474034)),
      secondaryLabelStyle: const TextStyle(color: kSealRed),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: kInkSecondary.withValues(alpha: 0.2)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kPrimaryBlue : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? kPrimaryBlue.withValues(alpha: 0.35)
            : kInkSecondary.withValues(alpha: 0.22),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kPrimaryBlue : null,
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      iconColor: kPrimaryBlue.withValues(alpha: 0.88),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kSealRed,
      foregroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kPaperCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.82),
      indicatorColor: kSealRed.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'NotoSansSC',
          fontWeight:
              states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? kPrimaryBlue : kInkSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? kPrimaryBlue : kInkSecondary,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kPaperCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF3F3A31),
      contentTextStyle: const TextStyle(
        fontFamily: 'NotoSansSC',
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kSealRed,
    ),
    dividerColor: kInkSecondary.withValues(alpha: 0.2),
  );
}
