import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth.dart';
import 'store/grocery_store_state.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _apiBaseUrlEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _themePrefKey = 'theme_mode';

  late final Future<GroceryStoreState> _storeFuture;
  ThemeMode _themeMode = ThemeMode.system;

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
    setState(() {
      _themeMode = _decodeThemeMode(raw);
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

  String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = mode;
    });
    await prefs.setString(_themePrefKey, _encodeThemeMode(mode));
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF127C73),
      brightness: brightness,
    );
    final baseTheme =
        brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final textTheme = GoogleFonts.spaceGroteskTextTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
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
        color: brightness == Brightness.dark
            ? colorScheme.surface
            : Colors.white,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            brightness == Brightness.dark ? colorScheme.surface : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery Store',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      builder: (context, child) {
        return AppBackground(child: child ?? const SizedBox.shrink());
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
            onThemeModeChanged: _setThemeMode,
          );
        },
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const [Color(0xFF0B0F14), Color(0xFF121D27)]
        : const [Color(0xFFF7F2EC), Color(0xFFE7F3F1)];
    final accent = isDark ? const Color(0xFF2A4154) : const Color(0xFFB7D6D0);
    final accentSecondary =
        isDark ? const Color(0xFF3A2B4A) : const Color(0xFFF0D9C6);

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
