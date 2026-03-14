import 'package:flutter/material.dart';

class ThemeModeMenu extends StatelessWidget {
  const ThemeModeMenu({
    super.key,
    required this.themeMode,
    required this.onChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  IconData get _icon {
    switch (themeMode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.system:
      default:
        return Icons.brightness_auto;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme',
      icon: Icon(_icon),
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: ThemeMode.system,
          child: Text('System'),
        ),
        PopupMenuItem(
          value: ThemeMode.light,
          child: Text('Light'),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: Text('Dark'),
        ),
      ],
    );
  }
}
