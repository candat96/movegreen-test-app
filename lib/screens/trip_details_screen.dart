import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/trip_provider.dart';
import '../models/trip.dart';

class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
      ),
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          if (tripProvider.isLoading || tripProvider.selectedTrip == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final trip = tripProvider.selectedTrip!;
          return _buildTripDetails(context, trip);
        },
      ),
    );
  }

  Widget _buildTripDetails(BuildContext context, Trip trip) {
    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final distanceInKm = (trip.distance / 1000).toStringAsFixed(2);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map section
          if (trip.locationPoints.isNotEmpty)
            SizedBox(
              height: 300,
              child: FlutterMap(
                options: MapOptions(
                  center: LatLng(
                    trip.locationPoints.first.latitude,
                    trip.locationPoints.first.longitude,
                  ),
                  zoom: 13.0,
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
                        points: trip.locationPoints
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
                      // Start marker
                      Marker(
                        width: 80,
                        height: 80,
                        point: LatLng(
                          trip.locationPoints.first.latitude,
                          trip.locationPoints.first.longitude,
                        ),
                        child: const Icon(
                          Icons.trip_origin,
                          color: Colors.green,
                          size: 30,
                        ),
                      ),
                      // End marker (if trip is completed)
                      if (trip.endTime != null)
                        Marker(
                          width: 80,
                          height: 80,
                          point: LatLng(
                            trip.locationPoints.last.latitude,
                            trip.locationPoints.last.longitude,
                          ),
                          child: const Icon(
                            Icons.place,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            )
          else
            const SizedBox(
              height: 200,
              child: Center(
                child: Text('No location data available for this trip'),
              ),
            ),

          // Trip info section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(trip.startTime),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${timeFormat.format(trip.startTime)} - ${trip.endTime != null ? timeFormat.format(trip.endTime!) : 'In progress'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Transportation mode
                _buildInfoRow(
                  _getTransportIcon(trip.transportationMode),
                  'Transportation',
                  trip.transportationMode.substring(0, 1).toUpperCase() +
                      trip.transportationMode.substring(1),
                ),
                const Divider(),

                // Distance
                _buildInfoRow(
                  Icons.straighten,
                  'Distance',
                  '$distanceInKm kilometers',
                ),
                const Divider(),

                // Duration
                _buildInfoRow(
                  Icons.timelapse,
                  'Duration',
                  _formatDuration(trip.startTime, trip.endTime),
                ),
                const Divider(),

                // Steps
                _buildInfoRow(
                  Icons.directions_walk,
                  'Steps',
                  '${trip.steps}',
                ),
                const Divider(),

                // Average speed (if trip is completed)
                if (trip.endTime != null)
                  _buildInfoRow(
                    Icons.speed,
                    'Average Speed',
                    _calculateAverageSpeed(
                      trip.distance,
                      trip.startTime,
                      trip.endTime!,
                    ),
                  ),
                if (trip.endTime != null) const Divider(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
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

  String _formatDuration(DateTime startTime, DateTime? endTime) {
    if (endTime == null) {
      return 'In progress';
    }

    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _calculateAverageSpeed(
    double distanceInMeters,
    DateTime startTime,
    DateTime endTime,
  ) {
    final durationInHours = endTime.difference(startTime).inSeconds / 3600;
    final distanceInKm = distanceInMeters / 1000;
    final speedKmh = distanceInKm / durationInHours;
    
    return '${speedKmh.toStringAsFixed(1)} km/h';
  }
}
