import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/trip_provider.dart';
import '../models/trip.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({Key? key}) : super(key: key);

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  Timer? _timer;
  DateTime _startTime = DateTime.now();
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    _startTime = tripProvider.activeTrip?.startTime ?? DateTime.now();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () => _confirmStopTrip(context),
            tooltip: 'Stop trip',
          ),
        ],
      ),
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          final activeTrip = tripProvider.activeTrip;
          final locationPoints = tripProvider.locationPoints;
          final transportationMode = tripProvider.transportationMode;
          final steps = tripProvider.steps;

          if (activeTrip == null) {
            return const Center(
              child: Text('No active trip'),
            );
          }

          return Column(
            children: [
              // Map section
              Expanded(
                flex: 3,
                child: locationPoints.isNotEmpty
                    ? FlutterMap(
                        options: MapOptions(
                          center: LatLng(
                            locationPoints.last.latitude,
                            locationPoints.last.longitude,
                          ),
                          zoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: locationPoints
                                    .map((point) => LatLng(
                                          point.latitude,
                                          point.longitude,
                                        ))
                                    .toList(),
                                color: Colors.blue,
                                strokeWidth: 4.0,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              // Current location marker
                              if (locationPoints.isNotEmpty)
                                Marker(
                                  width: 80,
                                  height: 80,
                                  point: LatLng(
                                    locationPoints.last.latitude,
                                    locationPoints.last.longitude,
                                  ),
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      )
                    : const Center(
                        child: Text('Waiting for location data...'),
                      ),
              ),

              // Trip info section
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timer
                      Center(
                        child: Text(
                          _formatDuration(_elapsed),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Trip stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTripStat(
                            _getTransportIcon(transportationMode),
                            transportationMode.substring(0, 1).toUpperCase() +
                                transportationMode.substring(1),
                            'Mode',
                          ),
                          _buildTripStat(
                            Icons.straighten,
                            '${(activeTrip.distance / 1000).toStringAsFixed(2)} km',
                            'Distance',
                          ),
                          _buildTripStat(
                            Icons.directions_walk,
                            '$steps',
                            'Steps',
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Stop trip button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.stop_circle),
                          label: const Text('STOP TRIP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _confirmStopTrip(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 30),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  IconData _getTransportIcon(String transportationMode) {
    switch (transportationMode) {
      case 'walking':
        return Icons.directions_walk;
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'driving':
        return Icons.directions_car;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _confirmStopTrip(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Trip'),
        content: const Text(
          'Are you sure you want to stop tracking this trip?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final tripProvider =
                  Provider.of<TripProvider>(context, listen: false);
              tripProvider.stopTrip();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to home screen
            },
            child: const Text('STOP'),
          ),
        ],
      ),
    );
  }
}
