import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ServioMapWidget extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final bool interactive;
  final void Function(LatLng)? onTap;

  const ServioMapWidget({
    super.key,
    required this.center,
    this.zoom = 14.0,
    this.markers = const [],
    this.interactive = false,
    this.onTap,
  });

  @override
  State<ServioMapWidget> createState() => _ServioMapWidgetState();
}

class _ServioMapWidgetState extends State<ServioMapWidget> {
  final _tileProvider = NetworkTileProvider();

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        interactionOptions: InteractionOptions(
          flags:
              widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap:
            widget.onTap != null ? (_, latLng) => widget.onTap!(latLng) : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.servio_mobile_app',
          tileProvider: _tileProvider,
        ),
        if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
          ],
        ),
      ],
    );
  }
}

Marker buildPinMarker(LatLng point, {Color color = Colors.red}) => Marker(
      point: point,
      width: 40,
      height: 40,
      alignment: Alignment.topCenter,
      child: Icon(Icons.location_pin, color: color, size: 40),
    );
