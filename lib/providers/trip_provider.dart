import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../services/database_helper.dart';
import '../services/location_service.dart';

class TripProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final LocationService _locationService = LocationService();
  
  List<Trip> _trips = [];
  List<Trip> get trips => _trips;
  
  Trip? _selectedTrip;
  Trip? get selectedTrip => _selectedTrip;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  TripProvider() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    await _locationService.initialize();
    await loadTrips();
    
    // Check if there was an active trip when the app was killed
    await _checkForActiveTrip();
  }
  
  // Check if there was an active trip when the app was killed
  Future<void> _checkForActiveTrip() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? tripId = prefs.getString('active_trip_id');
      
      if (tripId != null) {
        print('Found active trip: $tripId');
        
        // Check if this is a trip that was auto-started in the background
        if (tripId.length > 10) { // Assuming auto-generated IDs are timestamps
          print('This appears to be an auto-started trip');
          
          // Get trip details from SharedPreferences
          String? startTimeStr = prefs.getString('trip_start_time');
          String? endTimeStr = prefs.getString('trip_end_time');
          String transportMode = prefs.getString('transport_mode') ?? 'unknown';
          int steps = prefs.getInt('trip_steps') ?? 0;
          
          if (startTimeStr != null) {
            DateTime startTime = DateTime.parse(startTimeStr);
            DateTime? endTime = endTimeStr != null ? DateTime.parse(endTimeStr) : null;
            
            // Create a new trip in the database
            Trip newTrip = Trip(
              startTime: startTime,
              endTime: endTime,
              transportationMode: transportMode,
              steps: steps,
            );
            
            // Save to database
            int dbTripId = await _databaseHelper.insertTrip(newTrip);
            print('Auto-started trip saved to database with ID: $dbTripId');
            
            // If the trip was not ended, resume it
            if (endTime == null) {
              Trip tripWithId = newTrip.copyWith(id: dbTripId);
              await _locationService.resumeTrip(tripWithId);
              print('Resuming auto-started trip');
            } else {
              // Trip was already ended, clean up SharedPreferences
              await prefs.remove('active_trip_id');
              await prefs.remove('trip_start_time');
              await prefs.remove('trip_end_time');
              await prefs.remove('transport_mode');
              await prefs.remove('trip_steps');
              print('Auto-started trip was already ended');
            }
          }
        } else {
          // This is a regular trip that was started in the app
          try {
            int numericTripId = int.parse(tripId);
            Trip? trip = await _databaseHelper.getTrip(numericTripId);
            
            if (trip != null) {
              // Check if the trip was marked for ending in the background
              String? endTimeStr = prefs.getString('trip_end_time');
              
              if (endTimeStr != null) {
                // Trip was auto-ended in the background
                DateTime endTime = DateTime.parse(endTimeStr);
                print('Trip was auto-ended at: $endTime');
                
                // Update the trip with end time
                Trip updatedTrip = trip.copyWith(endTime: endTime);
                await _databaseHelper.updateTrip(updatedTrip);
                
                // Clean up SharedPreferences
                await prefs.remove('active_trip_id');
                await prefs.remove('trip_start_time');
                await prefs.remove('trip_end_time');
                await prefs.remove('transport_mode');
                await prefs.remove('trip_steps');
                
                print('Trip auto-end processed');
              } else if (trip.endTime == null) {
                // Trip is still active, resume it
                print('Resuming active trip');
                await _locationService.resumeTrip(trip);
              } else {
                // Trip was already completed, remove from SharedPreferences
                await prefs.remove('active_trip_id');
                await prefs.remove('transport_mode');
              }
            }
          } catch (e) {
            print('Error processing regular trip: $e');
          }
        }
        
        // Reload trips
        await loadTrips();
        notifyListeners();
      }
    } catch (e) {
      print('Error checking for active trip: $e');
    }
  }
  
  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();
    
    _trips = await _databaseHelper.getAllTrips();
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> selectTrip(int tripId) async {
    _isLoading = true;
    notifyListeners();
    
    _selectedTrip = await _databaseHelper.getTrip(tripId);
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> startTrip() async {
    await _locationService.startTrip();
    notifyListeners();
  }
  
  Future<void> stopTrip() async {
    await _locationService.stopTrip();
    await loadTrips();
    notifyListeners();
  }
  
  Future<void> deleteTrip(int tripId) async {
    await _databaseHelper.deleteTrip(tripId);
    await loadTrips();
    
    if (_selectedTrip?.id == tripId) {
      _selectedTrip = null;
    }
    
    notifyListeners();
  }
  
  bool get isTracking => _locationService.isTracking;
  Trip? get activeTrip => _locationService.activeTrip;
  String get transportationMode => _locationService.transportationMode;
  int get steps => _locationService.steps;
  List<LocationPoint> get locationPoints => _locationService.locationPoints;
}
