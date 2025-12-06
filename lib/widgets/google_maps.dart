import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:label_marker/label_marker.dart';
import '';

class GoogleMaps extends StatefulWidget {
  GoogleMaps({
    super.key,
    required this.sliderValue,
    required this.currentPosition,
    required this.isInGame,
    required this.polylineCoordinates,
    this.gamePosition,
    this.circle,
    this.circle2,
  });

  final LatLng currentPosition; // Default position
  final double sliderValue;
  final bool isInGame;
  final LatLng? gamePosition;
  final List<LatLng> polylineCoordinates;
  final Circle? circle;
  final Circle? circle2;

  final markerKey = GlobalKey();

  @override
  State<GoogleMaps> createState() => GoogleMapsState();
}

class GoogleMapsState extends State<GoogleMaps> {
  late LatLng? gamePosition = widget.gamePosition;
  late LatLng _currentPosition;
  late bool isInGame;
  late List<LatLng> polylineCoordinates;
  Marker? currentMarker;
  GoogleMapController? _mapController; // Controller for the map
  StreamSubscription<Position>? _positionStreamSubscription;
  late final Set<Circle> _circles = {
    Circle(
      circleId: const CircleId('start_radius'),
      center: gamePosition!,
      radius: widget.sliderValue * 1000, // km -> m
      strokeColor: Colors.blue,
      strokeWidth: 2,
      fillColor: Colors.blue.withOpacity(0.3),
    ),
  };

  void addCircle({
    required LatLng center,
    required double radius, // meter
    Color strokeColor = Colors.red,
    Color fillColor = Colors.red,
    int strokeWidth = 2,
  }) 
  {
    final circle = Circle(
      circleId: CircleId('dynamic_${_circles.length}'),
      center: center,
      radius: radius,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      fillColor: fillColor.withOpacity(0.3),
    );
    setState(() => _circles.add(circle));
    //_mapController?.animateCamera(CameraUpdate.newLatLng(center));
  }

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentPosition;
    polylineCoordinates = widget.polylineCoordinates;
    isInGame = widget.isInGame; 
    if (widget.circle != null) _circles.add(widget.circle!);
    if (widget.circle2 != null) _circles.add(widget.circle2!);
// Set initial position
    // gamePosition = widget.gamePosition;

    // if (widget.circles != null) {
    //   _circles.add(
    //     Circle(
    //       circleId: const CircleId('start_radius'),
    //       center: _currentPosition,
    //       radius: rad, // km -> m
    //       strokeColor: Colors.red,
    //       strokeWidth: 2,
    //       fillColor: Colors.red.withOpacity(0.3),
    //     ),
    //   );
    // }
    //print(_circles);
    _startLocationUpdates();
    _getCurrentLocation(); // Update location on startup.
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        polylineCoordinates.add(_currentPosition);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied.');
      return;
    }

    // Get the current position.
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      currentMarker = Marker(
        markerId: const MarkerId("currentLocation"),
        position: _currentPosition,
        infoWindow: const InfoWindow(title: "You are here"),
      );
    });

    // Center the map on the current location if the controller is available.
    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }

  

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentPosition,
        zoom: 11.0,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      circles:
          !isInGame
              ? {
                Circle(
                  circleId: const CircleId('start_radius'),
                  center: _currentPosition,

                  radius: widget.sliderValue * 1000, // km -> m
                  strokeColor: Colors.blue,
                  strokeWidth: 2,

                  fillColor: Colors.blue.withOpacity(0.3),
                ),
              }
              : _circles, //krigsbrott men det funkar
      polylines:
          isInGame
              ? {
                Polyline(
                  polylineId: PolylineId('trail'),
                  points: polylineCoordinates,
                  color: Colors.red,
                  width: 5,
                ),
              }
              : {},
    );
  }
}
