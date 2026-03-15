import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth.dart';
import 'store/grocery_store_state.dart';

enum AppThemeStyle { classic, golden, pink }

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _apiBaseUrlEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _themePrefKey = 'theme_mode';
  static const String _themeStylePrefKey = 'theme_style';

  late final Future<GroceryStoreState> _storeFuture;
  ThemeMode _themeMode = ThemeMode.system;
  AppThemeStyle _themeStyle = AppThemeStyle.classic;

  @override
  void initState() {
    super.initState();
    _storeFuture = GroceryStoreState.create(baseUrl: _resolveApiBaseUrl());
    _loadThemeMode();
  }

  String _resolveApiBaseUrl() {
    if (_apiBaseUrlEnv.isNotEmpty) {
      return _apiBaseUrlEnv;
    }
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:4000';
      }
      return 'https://grocerystore-production-eea3.up.railway.app';
    }
    return 'http://localhost:4000';
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themePrefKey);
    final rawStyle = prefs.getString(_themeStylePrefKey);
    setState(() {
      _themeMode = _decodeThemeMode(raw);
      _themeStyle = _decodeThemeStyle(rawStyle);
    });
  }

  ThemeMode _decodeThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  AppThemeStyle _decodeThemeStyle(String? raw) {
    switch (raw) {
      case 'golden':
        return AppThemeStyle.golden;
      case 'pink':
        return AppThemeStyle.pink;
      case 'classic':
      default:
        return AppThemeStyle.classic;
    }
  }

  String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String _encodeThemeStyle(AppThemeStyle style) {
    switch (style) {
      case AppThemeStyle.golden:
        return 'golden';
      case AppThemeStyle.pink:
        return 'pink';
      case AppThemeStyle.classic:
        return 'classic';
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = mode;
    });
    await prefs.setString(_themePrefKey, _encodeThemeMode(mode));
  }

  Future<void> _setThemeStyle(AppThemeStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeStyle = style;
    });
    await prefs.setString(_themeStylePrefKey, _encodeThemeStyle(style));
  }

  Color _seedColorForStyle(AppThemeStyle style) {
    switch (style) {
      case AppThemeStyle.golden:
        return const Color(0xFFC69214);
      case AppThemeStyle.pink:
        return const Color(0xFFD85A9A);
      case AppThemeStyle.classic:
        return const Color(0xFF127C73);
    }
  }

  Color _surfaceTintForStyle(AppThemeStyle style, Brightness brightness) {
    switch (style) {
      case AppThemeStyle.golden:
        return brightness == Brightness.dark
            ? const Color(0xFF5B4311)
            : const Color(0xFFF6E2A8);
      case AppThemeStyle.pink:
        return brightness == Brightness.dark
            ? const Color(0xFF4A2137)
            : const Color(0xFFF8C9DE);
      case AppThemeStyle.classic:
        return brightness == Brightness.dark
            ? const Color(0xFF183445)
            : const Color(0xFFD9EEE9);
    }
  }

  Color _cardColorForStyle(
    AppThemeStyle style,
    Brightness brightness,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case AppThemeStyle.golden:
        return brightness == Brightness.dark
            ? const Color(0xFF21170D)
            : const Color(0xFFFFF8EA);
      case AppThemeStyle.pink:
        return brightness == Brightness.dark
            ? const Color(0xFF21121A)
            : const Color(0xFFFFF7FB);
      case AppThemeStyle.classic:
        return brightness == Brightness.dark ? colorScheme.surface : Colors.white;
    }
  }

  Color _inputFillForStyle(
    AppThemeStyle style,
    Brightness brightness,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case AppThemeStyle.golden:
        return brightness == Brightness.dark
            ? const Color(0xFF261A0E)
            : const Color(0xFFFFF4DD);
      case AppThemeStyle.pink:
        return brightness == Brightness.dark
            ? const Color(0xFF26151F)
            : const Color(0xFFFFF1F7);
      case AppThemeStyle.classic:
        return brightness == Brightness.dark ? colorScheme.surface : Colors.white;
    }
  }

  Color _buttonBackgroundForStyle(
    AppThemeStyle style,
    Brightness brightness,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case AppThemeStyle.golden:
        return brightness == Brightness.dark
            ? const Color(0xFFD3A63A)
            : const Color(0xFFB8860B);
      case AppThemeStyle.pink:
        return brightness == Brightness.dark
            ? const Color(0xFFE170A8)
            : const Color(0xFFD85A9A);
      case AppThemeStyle.classic:
        return colorScheme.primary;
    }
  }

  ThemeData _buildTheme(Brightness brightness, AppThemeStyle style) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColorForStyle(style),
      brightness: brightness,
    );
    final baseTheme = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();
    final textTheme = GoogleFonts.spaceGroteskTextTheme(baseTheme.textTheme);
    final surfaceTint = _surfaceTintForStyle(style, brightness);
    final cardColor = _cardColorForStyle(style, brightness, colorScheme);
    final inputFill = _inputFillForStyle(style, brightness, colorScheme);
    final buttonBackground = _buttonBackgroundForStyle(
      style,
      brightness,
      colorScheme,
    );

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: cardColor.withValues(alpha: 0.94),
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: surfaceTint.withValues(alpha: 0.26)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: surfaceTint.withValues(alpha: 0.45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: surfaceTint.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor.withValues(alpha: 0.96),
        indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBackground,
          foregroundColor: ThemeData.estimateBrightnessForColor(
                    buttonBackground,
                  ) ==
                  Brightness.dark
              ? Colors.white
              : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: surfaceTint.withValues(alpha: 0.45)),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: inputFill,
        selectedColor: surfaceTint.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: surfaceTint.withValues(alpha: 0.28)),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: surfaceTint.withValues(alpha: 0.28)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery Store',
      theme: _buildTheme(Brightness.light, _themeStyle),
      darkTheme: _buildTheme(Brightness.dark, _themeStyle),
      themeMode: _themeMode,
      builder: (context, child) {
        return AppBackground(
          themeStyle: _themeStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: FutureBuilder<GroceryStoreState>(
        future: _storeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Scaffold(
              body: Center(child: Text('Failed to load store data.')),
            );
          }

          return AuthGate(
            store: snapshot.data!,
            themeMode: _themeMode,
            themeStyle: _themeStyle,
            onThemeModeChanged: _setThemeMode,
            onThemeStyleChanged: _setThemeStyle,
          );
        },
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    required this.themeStyle,
  });

  final Widget child;
  final AppThemeStyle themeStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (background, accent, accentSecondary) = switch (themeStyle) {
      AppThemeStyle.golden => (
        isDark
            ? const [Color(0xFF17120A), Color(0xFF241A0E)]
            : const [Color(0xFFFBF4DF), Color(0xFFF2E2B7)],
        isDark ? const Color(0xFF8A6721) : const Color(0xFFE2C16C),
        isDark ? const Color(0xFF5D3D13) : const Color(0xFFF4D7A1),
      ),
      AppThemeStyle.pink => (
        isDark
            ? const [Color(0xFF170C13), Color(0xFF24101C)]
            : const [Color(0xFFFFF0F6), Color(0xFFF9D9E7)],
        isDark ? const Color(0xFF6A2E51) : const Color(0xFFF1A6C7),
        isDark ? const Color(0xFF3C1832) : const Color(0xFFF7C6DB),
      ),
      AppThemeStyle.classic => (
        isDark
            ? const [Color(0xFF0B0F14), Color(0xFF121D27)]
            : const [Color(0xFFF7F2EC), Color(0xFFE7F3F1)],
        isDark ? const Color(0xFF2A4154) : const Color(0xFFB7D6D0),
        isDark ? const Color(0xFF3A2B4A) : const Color(0xFFF0D9C6),
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: background,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentSecondary.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
