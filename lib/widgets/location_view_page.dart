import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OrderLocationViewPage extends StatelessWidget {
  const OrderLocationViewPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeLabel,
    this.title = 'Delivery location',
  });

  final double latitude;
  final double longitude;
  final String address;
  final String? placeLabel;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final point = LatLng(latitude, longitude);
    final label = placeLabel?.trim().isNotEmpty == true
        ? placeLabel!.trim()
        : address;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 16,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.haidonovan.fluttergrocery',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 58,
                              height: 58,
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 48,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      address,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.my_location_outlined,
                          label: 'Lat ${latitude.toStringAsFixed(5)}',
                        ),
                        _MetaChip(
                          icon: Icons.explore_outlined,
                          label: 'Lng ${longitude.toStringAsFixed(5)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
