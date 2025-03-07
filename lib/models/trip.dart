class Trip {
  final int? id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distance; // in meters
  final String transportationMode;
  final int steps;
  final List<LocationPoint> locationPoints;

  Trip({
    this.id,
    required this.startTime,
    this.endTime,
    this.distance = 0.0,
    this.transportationMode = 'unknown',
    this.steps = 0,
    this.locationPoints = const [],
  });

  Trip copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    double? distance,
    String? transportationMode,
    int? steps,
    List<LocationPoint>? locationPoints,
  }) {
    return Trip(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      transportationMode: transportationMode ?? this.transportationMode,
      steps: steps ?? this.steps,
      locationPoints: locationPoints ?? this.locationPoints,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'distance': distance,
      'transportationMode': transportationMode,
      'steps': steps,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      distance: map['distance'],
      transportationMode: map['transportationMode'],
      steps: map['steps'],
    );
  }

  @override
  String toString() {
    return 'Trip(id: $id, startTime: $startTime, endTime: $endTime, distance: $distance, transportationMode: $transportationMode, steps: $steps, locationPoints: ${locationPoints.length})';
  }
}

class LocationPoint {
  final int? id;
  final int? tripId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final String? activity;

  LocationPoint({
    this.id,
    this.tripId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestamp,
    this.activity,
  });

  LocationPoint copyWith({
    int? id,
    int? tripId,
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? activity,
  }) {
    return LocationPoint(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      activity: activity ?? this.activity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'activity': activity,
    };
  }

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      id: map['id'],
      tripId: map['tripId'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      altitude: map['altitude'],
      speed: map['speed'],
      heading: map['heading'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      activity: map['activity'],
    );
  }

  @override
  String toString() {
    return 'LocationPoint(id: $id, tripId: $tripId, latitude: $latitude, longitude: $longitude, timestamp: $timestamp)';
  }
}

enum TransportationMode {
  walking,
  running,
  cycling,
  driving,
  transit,
  unknown,
}

extension TransportationModeExtension on TransportationMode {
  String get name {
    switch (this) {
      case TransportationMode.walking:
        return 'Walking';
      case TransportationMode.running:
        return 'Running';
      case TransportationMode.cycling:
        return 'Cycling';
      case TransportationMode.driving:
        return 'Driving';
      case TransportationMode.transit:
        return 'Transit';
      case TransportationMode.unknown:
        return 'Unknown';
    }
  }

  String get icon {
    switch (this) {
      case TransportationMode.walking:
        return 'directions_walk';
      case TransportationMode.running:
        return 'directions_run';
      case TransportationMode.cycling:
        return 'directions_bike';
      case TransportationMode.driving:
        return 'directions_car';
      case TransportationMode.transit:
        return 'directions_transit';
      case TransportationMode.unknown:
        return 'help_outline';
    }
  }
}
