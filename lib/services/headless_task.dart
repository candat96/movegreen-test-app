import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:shared_preferences/shared_preferences.dart';

// This function will be called when the app is running in the background
void headlessTask(bg.HeadlessEvent headlessEvent) async {
  print('[Headless] Event received: ${headlessEvent.name}');
  
  // Get the event type
  String eventName = headlessEvent.name;
  
  // Handle location event
  if (eventName == bg.Event.LOCATION) {
    bg.Location location = headlessEvent.event;
    
    try {
      // Get current trip ID from shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? tripId = prefs.getString('active_trip_id');
      String? transportMode = prefs.getString('transport_mode') ?? 'unknown';
      
      if (tripId != null) {
        // Add trip metadata to location
        location.extras = {
          "trip_id": tripId,
          "transport_mode": transportMode,
        };
        
        // The location is already saved to the built-in SQLite database
        // by the background geolocation plugin
        print('[Headless] Location recorded: ${location.coords.latitude}, ${location.coords.longitude}');
        
        print('[Headless] Location saved with trip_id: $tripId');
      } else {
        print('[Headless] No active trip found, location not saved');
      }
    } catch (e) {
      print('[Headless] Error: $e');
    }
  }
  
  // Handle motion change event
  else if (eventName == bg.Event.MOTIONCHANGE) {
    bg.Location location = headlessEvent.event;
    bool isMoving = location.isMoving;
    print('[Headless] Motion changed: $isMoving');
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool autoTripEnabled = prefs.getBool('auto_trip_enabled') ?? true;
      
      if (autoTripEnabled) {
        String? tripId = prefs.getString('active_trip_id');
        String transportMode = prefs.getString('transport_mode') ?? 'unknown';
        
        if (isMoving) {
          // Auto-start trip if not already tracking
          if (tripId == null) {
            print('[Headless] Auto-starting trip due to motion detection');
            
            // Create a new trip ID
            String newTripId = DateTime.now().millisecondsSinceEpoch.toString();
            
            // Store trip info in SharedPreferences
            await prefs.setString('active_trip_id', newTripId);
            await prefs.setString('trip_start_time', DateTime.now().toIso8601String());
            await prefs.setString('transport_mode', transportMode);
            await prefs.setInt('trip_steps', 0);
            
            print('[Headless] New trip started with ID: $newTripId');
          }
        } else {
          // Auto-end trip if currently tracking
          if (tripId != null) {
            print('[Headless] Auto-ending trip due to lack of motion');
            
            // Store trip end time in SharedPreferences
            await prefs.setString('trip_end_time', DateTime.now().toIso8601String());
            
            // We can't actually end the trip here because we don't have access to the database
            // The trip will be properly ended when the app is reopened
            print('[Headless] Trip $tripId marked for ending when app reopens');
          }
        }
      }
    } catch (e) {
      print('[Headless] Error in motion change handler: $e');
    }
  }
  
  // Handle activity change event
  else if (eventName == bg.Event.ACTIVITYCHANGE) {
    bg.ActivityChangeEvent event = headlessEvent.event;
    print('[Headless] Activity changed: ${event.activity} (${event.confidence}%)');
    
    try {
      // Update transport mode in shared preferences if confidence is high enough
      if (event.confidence >= 75) {
        String transportMode = 'unknown';
        
        switch (event.activity) {
          case 'walking':
            transportMode = 'walking';
            break;
          case 'running':
            transportMode = 'running';
            break;
          case 'on_bicycle':
            transportMode = 'cycling';
            break;
          case 'in_vehicle':
            transportMode = 'driving';
            break;
        }
        
        if (transportMode != 'unknown') {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('transport_mode', transportMode);
          
          // Get the active trip ID
          String? tripId = prefs.getString('active_trip_id');
          if (tripId != null) {
            print('[Headless] Transport mode updated for trip $tripId: $transportMode');
            
            // Note: We can't update the database directly from the headless task
            // because we don't have access to the DatabaseHelper.
            // The transport mode will be updated when the app is reopened.
          } else {
            print('[Headless] Transport mode updated: $transportMode (no active trip)');
          }
        }
      }
    } catch (e) {
      print('[Headless] Error updating transport mode: $e');
    }
  }
}
