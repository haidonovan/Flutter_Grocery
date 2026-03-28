import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const _defaultMapCenter = LatLng(11.5564, 104.9282);
const _defaultMapZoom = 13.5;

class SelectedLocation {
  const SelectedLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.placeLabel,
  });

  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? placeLabel;

  String get label {
    final trimmed = placeLabel?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return formattedAddress;
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    this.initialPlaceLabel,
  });

  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialPlaceLabel;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedPoint;
  String? _resolvedAddress;
  bool _resolving = false;
  bool _searching = false;
  bool _findingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialLatitude != null &&
            widget.initialLongitude != null
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : null;
    _resolvedAddress = widget.initialAddress?.trim().isNotEmpty == true
        ? widget.initialAddress!.trim()
        : null;
    _searchController.text = widget.initialPlaceLabel?.trim().isNotEmpty == true
        ? widget.initialPlaceLabel!.trim()
        : widget.initialAddress?.trim() ?? '';

    if (_selectedPoint != null && _resolvedAddress == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveSelectedPoint();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectPoint(LatLng point, {bool moveMap = true}) async {
    setState(() {
      _selectedPoint = point;
    });
    if (moveMap) {
      _mapController.move(point, 16);
    }
    await _resolveSelectedPoint();
  }

  Future<void> _resolveSelectedPoint() async {
    final point = _selectedPoint;
    if (point == null) {
      return;
    }
    setState(() {
      _resolving = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      final placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final parts = [
        placemark?.name,
        placemark?.street,
        placemark?.subLocality,
        placemark?.locality,
        placemark?.administrativeArea,
        placemark?.postalCode,
        placemark?.country,
      ].where((value) => value != null && value.trim().isNotEmpty).cast<String>();

      setState(() {
        _resolvedAddress = parts.isNotEmpty
            ? parts.join(', ')
            : _coordinateFallback(point);
      });
    } catch (_) {
      setState(() {
        _resolvedAddress = _coordinateFallback(point);
      });
    } finally {
      if (mounted) {
        setState(() {
          _resolving = false;
        });
      }
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final locations = await locationFromAddress(query);
      if (!mounted) {
        return;
      }
      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching location found.')),
        );
        return;
      }
      final location = locations.first;
      await _selectPoint(
        LatLng(location.latitude, location.longitude),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not search that address.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _findingCurrentLocation = true;
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is needed to use current location.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      await _selectPoint(
        LatLng(position.latitude, position.longitude),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch your current location.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _findingCurrentLocation = false;
        });
      }
    }
  }

  void _confirmSelection() {
    final point = _selectedPoint;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a point on the map first.')),
      );
      return;
    }

    final label = _searchController.text.trim();
    Navigator.of(context).pop(
      SelectedLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        formattedAddress: _resolvedAddress ?? _coordinateFallback(point),
        placeLabel: label.isNotEmpty ? label : _resolvedAddress,
      ),
    );
  }

  String _coordinateFallback(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedPoint = _selectedPoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick delivery location'),
        actions: [
          IconButton(
            tooltip: 'Use current location',
            onPressed: _findingCurrentLocation ? null : _useCurrentLocation,
            icon: _findingCurrentLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAddress(),
                      decoration: const InputDecoration(
                        labelText: 'Search address or area',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _searching ? null : _searchAddress,
                    child: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Search'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tap the map to pin the delivery spot, or search an address first.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: selectedPoint ?? _defaultMapCenter,
                        initialZoom: selectedPoint != null ? 16 : _defaultMapZoom,
                        onTap: (_, point) => _selectPoint(point, moveMap: false),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.haidonovan.fluttergrocery',
                        ),
                        if (selectedPoint != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: selectedPoint,
                                width: 54,
                                height: 54,
                                child: Icon(
                                  Icons.location_on_rounded,
                                  size: 46,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                    Text(
                      'Selected location',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _resolving
                          ? 'Resolving address from map...'
                          : _resolvedAddress ??
                              'No point selected yet. Tap the map to choose one.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (selectedPoint != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Lat ${selectedPoint.latitude.toStringAsFixed(5)}  •  Lng ${selectedPoint.longitude.toStringAsFixed(5)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: selectedPoint == null || _resolving
                            ? null
                            : _confirmSelection,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Use this location'),
                      ),
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
