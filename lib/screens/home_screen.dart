import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trip_provider.dart';
import '../models/trip.dart';
import 'trip_details_screen.dart';
import 'active_trip_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Tracker'),
        actions: [
          Consumer<TripProvider>(
            builder: (context, tripProvider, child) {
              if (tripProvider.isTracking) {
                return IconButton(
                  icon: const Icon(Icons.directions_run),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ActiveTripScreen(),
                      ),
                    );
                  },
                  tooltip: 'View active trip',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          if (tripProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (tripProvider.trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_car,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No trips yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a new trip to begin tracking',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Start New Trip'),
                    onPressed: () {
                      _startNewTrip(context, tripProvider);
                    },
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => tripProvider.loadTrips(),
                child: ListView.builder(
                  itemCount: tripProvider.trips.length,
                  itemBuilder: (context, index) {
                    final trip = tripProvider.trips[index];
                    return _buildTripCard(context, trip, tripProvider);
                  },
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    _startNewTrip(context, tripProvider);
                  },
                  child: const Icon(Icons.add),
                  tooltip: 'Start new trip',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    Trip trip,
    TripProvider tripProvider,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final distanceInKm = (trip.distance / 1000).toStringAsFixed(2);
    
    // Determine the icon based on transportation mode
    IconData transportIcon;
    switch (trip.transportationMode) {
      case 'walking':
        transportIcon = Icons.directions_walk;
        break;
      case 'running':
        transportIcon = Icons.directions_run;
        break;
      case 'cycling':
        transportIcon = Icons.directions_bike;
        break;
      case 'driving':
        transportIcon = Icons.directions_car;
        break;
      default:
        transportIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          tripProvider.selectTrip(trip.id!);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TripDetailsScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(trip.startTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      _confirmDeleteTrip(context, trip, tripProvider);
                    },
                    tooltip: 'Delete trip',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(transportIcon),
                  const SizedBox(width: 8),
                  Text(
                    trip.transportationMode.substring(0, 1).toUpperCase() +
                        trip.transportationMode.substring(1),
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTripStat(
                    Icons.straighten,
                    '$distanceInKm km',
                    'Distance',
                  ),
                  _buildTripStat(
                    Icons.directions_walk,
                    '${trip.steps}',
                    'Steps',
                  ),
                  _buildTripStat(
                    Icons.access_time,
                    _formatDuration(trip.startTime, trip.endTime),
                    'Duration',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
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

  void _startNewTrip(BuildContext context, TripProvider tripProvider) {
    if (tripProvider.isTracking) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ActiveTripScreen(),
        ),
      );
    } else {
      tripProvider.startTrip();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ActiveTripScreen(),
        ),
      );
    }
  }

  void _confirmDeleteTrip(
    BuildContext context,
    Trip trip,
    TripProvider tripProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text(
          'Are you sure you want to delete this trip? This action cannot be undone.',
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
              tripProvider.deleteTrip(trip.id!);
              Navigator.pop(context);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
