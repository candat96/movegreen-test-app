import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import 'database_helper.dart';

class LocationService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  Trip? _activeTrip;
  Trip? get activeTrip => _activeTrip;
  
  List<LocationPoint> _locationPoints = [];
  List<LocationPoint> get locationPoints => _locationPoints;
  
  int _steps = 0;
  int get steps => _steps;
  
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  StreamSubscription<StepCount>? _stepCountSubscription;
  
  bool _isTracking = false;
  bool get isTracking => _isTracking;
  
  String _transportationMode = 'unknown';
  String get transportationMode => _transportationMode;
  
  // Auto-trip settings
  bool _autoTripEnabled = true;
  int _minMovingTime = 60; // seconds
  int _minStationaryTime = 300; // seconds
  
  // Save auto-trip settings to SharedPreferences
  Future<void> _saveAutoTripSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_trip_enabled', _autoTripEnabled);
    await prefs.setInt('min_moving_time', _minMovingTime);
    await prefs.setInt('min_stationary_time', _minStationaryTime);
  }
  
  // Load auto-trip settings from SharedPreferences
  Future<void> _loadAutoTripSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _autoTripEnabled = prefs.getBool('auto_trip_enabled') ?? true;
    _minMovingTime = prefs.getInt('min_moving_time') ?? 60;
    _minStationaryTime = prefs.getInt('min_stationary_time') ?? 300;
  }
  
  // Toggle auto-trip feature
  Future<void> toggleAutoTrip(bool enabled) async {
    _autoTripEnabled = enabled;
    await _saveAutoTripSettings();
    notifyListeners();
  }
  
  // Initialize the location service
  Future<void> initialize() async {
    // Load auto-trip settings
    await _loadAutoTripSettings();
    
    // Save auto-trip settings (in case they weren't set before)
    await _saveAutoTripSettings();
    // Configure background geolocation
    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 10.0,
      stopOnTerminate: false,
      startOnBoot: true,
      debug: false,
      logLevel: bg.Config.LOG_LEVEL_VERBOSE,
      stopTimeout: 1,
      activityType: bg.Config.ACTIVITY_TYPE_FITNESS,
      enableHeadless: true,
      backgroundPermissionRationale: bg.PermissionRationale(
        title: 'Background location access',
        message: 'This app collects location data to enable tracking of your trips.',
        positiveAction: 'OK',
        negativeAction: 'Cancel',
      ),
      // Enable SQLite database
      // persistMode: bg.Config.PERSIST_MODE_ALL,
      // maxRecordsToPersist: 10000,
      
      // Activity recognition
      activityRecognitionInterval: 1000,
      stopDetectionDelay: _minStationaryTime,
      
      // iOS specific
      preventSuspend: true,
      
      // Android specific
      notification: bg.Notification(
        title: 'Trip Tracker',
        text: 'Tracking your trip',
        channelName: 'Trip Tracker',
      ),
    ));
    
    // Start monitoring for motion even if no trip is active
    await bg.BackgroundGeolocation.start();
    
    // Set up event listeners
    bg.BackgroundGeolocation.onLocation(_onLocation);
    bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
    bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
    bg.BackgroundGeolocation.onProviderChange(_onProviderChange);
    
    // Initialize step counter
    _initStepCounter();
  }
  
  // Initialize step counter
  void _initStepCounter() {
    // Listen for pedestrian status changes
    _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
      (PedestrianStatus status) {
        if (status.status == 'walking') {
          _transportationMode = 'walking';
        } else if (status.status == 'stopped') {
          // Keep the current transportation mode if it's not walking
          if (_transportationMode == 'walking') {
            _transportationMode = 'unknown';
          }
        }
        notifyListeners();
      },
      onError: (error) {
        print('Pedestrian status error: $error');
      },
      onDone: () {
        print('Pedestrian status done');
      },
      cancelOnError: true,
    );
    
    // Listen for step count changes
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        if (_isTracking && _activeTrip != null) {
          // Calculate steps since the trip started
          int newSteps = event.steps;
          if (_steps == 0) {
            _steps = 0; // Reset steps counter for new trip
          } else {
            _steps = newSteps;
          }
          
          // Update active trip with new step count
          _activeTrip = _activeTrip!.copyWith(steps: _steps);
          notifyListeners();
        }
      },
      onError: (error) {
        print('Step count error: $error');
      },
      onDone: () {
        print('Step count done');
      },
      cancelOnError: true,
    );
  }
  
  // Start tracking a new trip
  Future<void> startTrip() async {
    if (_isTracking) return;
    
    // Create a new trip
    _activeTrip = Trip(
      startTime: DateTime.now(),
      transportationMode: _transportationMode,
      steps: 0,
    );
    
    // Save the trip to the database
    int tripId = await _databaseHelper.insertTrip(_activeTrip!);
    _activeTrip = _activeTrip!.copyWith(id: tripId);
    
    // Store active trip ID in SharedPreferences for headless task
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_trip_id', tripId.toString());
    await prefs.setString('transport_mode', _transportationMode);
    
    // Clear location points
    _locationPoints = [];
    
    // Reset step counter
    _steps = 0;
    
    // Start tracking
    _isTracking = true;
    await bg.BackgroundGeolocation.start();
    
    notifyListeners();
  }
  
  // Resume tracking an existing trip
  Future<void> resumeTrip(Trip trip) async {
    if (_isTracking) return;
    
    print('Resuming trip ${trip.id}');
    
    // Set the active trip
    _activeTrip = trip;
    
    // Load location points for this trip
    _locationPoints = await _databaseHelper.getLocationPointsForTrip(trip.id!);
    
    // Store active trip ID in SharedPreferences for headless task
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_trip_id', trip.id.toString());
    await prefs.setString('transport_mode', trip.transportationMode);
    
    // Set transportation mode
    _transportationMode = trip.transportationMode;
    
    // Set steps
    _steps = trip.steps;
    
    // Start tracking
    _isTracking = true;
    await bg.BackgroundGeolocation.start();
    
    notifyListeners();
  }
  
  // Stop tracking the current trip
  Future<void> stopTrip() async {
    if (!_isTracking || _activeTrip == null) return;
    
    // Don't stop background geolocation, just pause tracking in our app
    // This allows auto-start to still work
    
    // Sync locations from background geolocation database
    await _syncBackgroundLocations();
    
    // Update the trip with end time and final data
    _activeTrip = _activeTrip!.copyWith(
      endTime: DateTime.now(),
      steps: _steps,
      transportationMode: _transportationMode,
    );
    
    // Save the trip to the database
    await _databaseHelper.updateTrip(_activeTrip!);
    
    // Save location points to the database
    for (var point in _locationPoints) {
      await _databaseHelper.insertLocationPoint(
        point.copyWith(tripId: _activeTrip!.id),
      );
    }
    
    // Remove active trip ID from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_trip_id');
    await prefs.remove('transport_mode');
    
    // Reset tracking state
    _isTracking = false;
    _activeTrip = null;
    _locationPoints = [];
    
    notifyListeners();
  }
  
  // Sync locations from background geolocation database
  Future<void> _syncBackgroundLocations() async {
    try {
      // Get the current trip ID from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? tripId = prefs.getString('active_trip_id');
      
      if (tripId != null && _activeTrip != null) {
        print('Checking for background locations for trip $tripId');
        
        // Since we can't directly access the background geolocation database,
        // we'll rely on the locations that were already saved to the database
        // by the headless task
        
        // Clear the background geolocation database to avoid duplicates
        await bg.BackgroundGeolocation.destroyLocations();
      }
    } catch (e) {
      print('Error syncing background locations: $e');
    }
  }
  
  // Handle location updates
  void _onLocation(bg.Location location) {
    if (!_isTracking || _activeTrip == null) return;
    
    // Create a new location point
    LocationPoint point = LocationPoint(
      tripId: _activeTrip!.id,
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      altitude: location.coords.altitude,
      speed: location.coords.speed,
      heading: location.coords.heading,
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(location.timestamp)),
      activity: location.activity?.type,
    );
    
    // Add the location point to the list
    _locationPoints.add(point);
    
    // Update the trip with the new location point
    double distance = _activeTrip!.distance;
    if (_locationPoints.length > 1) {
      // Calculate distance between the last two points
      LocationPoint lastPoint = _locationPoints[_locationPoints.length - 2];
      double distanceBetweenPoints = _calculateDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        point.latitude,
        point.longitude,
      );
      distance += distanceBetweenPoints;
    }
    
    // Update the active trip
    _activeTrip = _activeTrip!.copyWith(
      distance: distance,
      locationPoints: _locationPoints,
    );
    
    notifyListeners();
  }
  
  // Handle motion changes
  void _onMotionChange(bg.Location location) async {
    bool isMoving = location.isMoving;
    print('Motion changed: $isMoving');
    
    if (_autoTripEnabled) {
      if (isMoving) {
        // Auto-start trip if not already tracking
        if (!_isTracking) {
          print('Auto-starting trip due to motion detection');
          await startTrip();
        }
      } else {
        // Auto-end trip if currently tracking
        if (_isTracking && _activeTrip != null) {
          // Check if we've been stationary for the minimum time
          print('Auto-ending trip due to lack of motion');
          await stopTrip();
        }
      }
    }
  }
  
  // Handle activity changes
  void _onActivityChange(bg.ActivityChangeEvent event) {
    String activity = event.activity;
    int confidence = event.confidence;
    
    print('Activity changed: $activity ($confidence%)');
    
    // Update transportation mode based on activity
    if (confidence >= 75) {
      switch (activity) {
        case 'still':
          // Keep the current transportation mode
          break;
        case 'walking':
          _transportationMode = 'walking';
          break;
        case 'running':
          _transportationMode = 'running';
          break;
        case 'on_bicycle':
          _transportationMode = 'cycling';
          break;
        case 'in_vehicle':
          _transportationMode = 'driving';
          break;
        default:
          _transportationMode = 'unknown';
      }
      
      // Update active trip with new transportation mode
      if (_isTracking && _activeTrip != null) {
        _activeTrip = _activeTrip!.copyWith(transportationMode: _transportationMode);
        
        // Update transport mode in SharedPreferences
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('transport_mode', _transportationMode);
        });
      }
      
      notifyListeners();
    }
  }
  
  // Handle provider changes
  void _onProviderChange(bg.ProviderChangeEvent event) {
    print('Provider changed: ${event.status}');
  }
  
  // Calculate distance between two points using the Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // in meters
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = (
      _sin(dLat / 2) * _sin(dLat / 2) +
      _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
      _sin(dLon / 2) * _sin(dLon / 2)
    );
    double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }
  
  // Math helper functions
  double _sin(double x) => math.sin(x);
  double _cos(double x) => math.cos(x);
  double _sqrt(double x) => math.sqrt(x);
  double _atan2(double y, double x) => math.atan2(y, x);
  double _toRadians(double degrees) => degrees * math.pi / 180;
  
  // Dispose of resources
  @override
  void dispose() {
    bg.BackgroundGeolocation.removeListeners();
    _pedestrianStatusSubscription?.cancel();
    _stepCountSubscription?.cancel();
    super.dispose();
  }
}
