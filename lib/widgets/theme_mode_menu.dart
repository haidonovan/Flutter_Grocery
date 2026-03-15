import 'package:flutter/material.dart';

import '../main.dart';

class ThemeModeMenu extends StatelessWidget {
  const ThemeModeMenu({
    super.key,
    required this.themeMode,
    required this.themeStyle,
    required this.onChanged,
    required this.onStyleChanged,
  });

  final ThemeMode themeMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<ThemeMode> onChanged;
  final ValueChanged<AppThemeStyle> onStyleChanged;

  IconData get _icon {
    switch (themeMode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String get _styleLabel {
    switch (themeStyle) {
      case AppThemeStyle.golden:
        return 'Golden';
      case AppThemeStyle.pink:
        return 'Pink';
      case AppThemeStyle.classic:
        return 'Classic';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Theme',
      icon: Badge(
        label: Text(
          _styleLabel[0],
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        child: Icon(_icon),
      ),
      onSelected: (value) {
        switch (value) {
          case 'mode_system':
            onChanged(ThemeMode.system);
            break;
          case 'mode_light':
            onChanged(ThemeMode.light);
            break;
          case 'mode_dark':
            onChanged(ThemeMode.dark);
            break;
          case 'style_classic':
            onStyleChanged(AppThemeStyle.classic);
            break;
          case 'style_golden':
            onStyleChanged(AppThemeStyle.golden);
            break;
          case 'style_pink':
            onStyleChanged(AppThemeStyle.pink);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('Mode'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'mode_system',
          checked: themeMode == ThemeMode.system,
          child: const Text('System'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'mode_light',
          checked: themeMode == ThemeMode.light,
          child: const Text('Light'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'mode_dark',
          checked: themeMode == ThemeMode.dark,
          child: const Text('Dark'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('Style'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'style_classic',
          checked: themeStyle == AppThemeStyle.classic,
          child: const Text('Classic'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'style_golden',
          checked: themeStyle == AppThemeStyle.golden,
          child: const Text('Golden'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'style_pink',
          checked: themeStyle == AppThemeStyle.pink,
          child: const Text('Pink'),
        ),
      ],
    );
  }
}
