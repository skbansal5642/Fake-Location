import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';

/// A search box over a map. Picking a search result or tapping the map moves the pin.
///
/// [onChanged] receives the new position and, for search picks, the result's title.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.radiusMeters,
  });

  final LatLng initial;
  final void Function(LatLng position, String? title) onChanged;

  /// When set, draws a circle of this radius around the pin.
  final double? radiusMeters;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _geocoding = GeocodingService();
  final _mapController = MapController();
  final _searchController = TextEditingController();
  late LatLng _position = widget.initial;
  List<SearchResult> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _geocoding.search(_searchController.text, near: _position);
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = results.isEmpty ? 'No results' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Search failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(SearchResult result) {
    _move(result.position, result.title);
    _mapController.move(result.position, 17);
    setState(() => _results = []);
  }

  void _move(LatLng position, String? title) {
    setState(() => _position = position);
    widget.onChanged(position, title);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search place, address or "lat, lng"',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _position,
                  initialZoom: 16,
                  onTap: (_, p) {
                    setState(() => _results = []);
                    _move(p, null);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.spurge.fake_location',
                  ),
                  if (widget.radiusMeters != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _position,
                          radius: widget.radiusMeters!,
                          useRadiusInMeter: true,
                          color: scheme.primary.withValues(alpha: 0.15),
                          borderColor: scheme.primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _position,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
                      ),
                    ],
                  ),
                  SimpleAttributionWidget(
                    source: Text(_geocoding.usesGoogle
                        ? 'OpenStreetMap contributors · Search by Google'
                        : 'OpenStreetMap contributors'),
                  ),
                ],
              ),
              if (_results.isNotEmpty || _error != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 0,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: _error != null
                        ? ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: Text(_error!),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _error = null),
                            ),
                          )
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _results.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (_, i) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.place_outlined),
                                title: Text(_results[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(_results[i].subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                                onTap: () => _select(_results[i]),
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '${_position.latitude.toStringAsFixed(6)}, ${_position.longitude.toStringAsFixed(6)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
