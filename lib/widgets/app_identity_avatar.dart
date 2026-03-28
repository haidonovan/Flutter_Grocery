import 'package:flutter/material.dart';

class AppIdentityAvatar extends StatelessWidget {
  const AppIdentityAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.icon,
    this.size = 40,
  });

  final String? imageUrl;
  final String? initials;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trimmedUrl = imageUrl?.trim();
    final backgroundColor = scheme.primaryContainer.withValues(alpha: 0.9);
    final foregroundColor = scheme.onPrimaryContainer;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: size * 0.48, color: foregroundColor)
            : Text(
                (initials?.trim().isNotEmpty == true ? initials!.trim() : '?')
                    .toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
      );
    }

    if (trimmedUrl == null || trimmedUrl.isEmpty) {
      return fallback();
    }

    return ClipOval(
      child: Image.network(
        trimmedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
      ),
    );
  }
}
