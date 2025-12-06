import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:client/views/home.dart';
import '../widgets/constants.dart';

class Result extends StatelessWidget {
  const Result({
    super.key,
    required this.stopWatch,
    required this.idToken,
    required this.distanceApart,
    required this.points,
    required this.totalPoints,
    required this.polylineCoordinates,
    required this.isInGame,
    required this.sliderValue,
    required this.currentPosition,
    required this.positionPicture,
  });

  final Stopwatch stopWatch;
  final String? idToken;
  final String distanceApart;
  final int points;
  final int totalPoints;
  final List<LatLng> polylineCoordinates; // kept for compatibility
  final bool isInGame;
  final double sliderValue;
  final LatLng currentPosition;
  final LatLng positionPicture;

  // helper getters -----------------------------------------------------------
  List<LatLng> get _line => [currentPosition, positionPicture];

  String get _timePretty =>
      DateFormat('mm:ss').format(DateTime(0).add(stopWatch.elapsed));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 1, 44, 41),
      appBar: AppBar(
        title: Text('Result', style: Constants.text40),
        backgroundColor: Colors.teal,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: size.height * 0.35,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.teal, width: 5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),

                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: currentPosition,
                      zoom: 11.5,
                    ),
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: _line,
                        color: Colors.blue,
                        width: 5,
                      ),
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('target'),
                        position: positionPicture,
                        infoWindow: const InfoWindow(title: 'Target'),
                      ),
                    },
                    myLocationEnabled: true,
                    zoomControlsEnabled: true,
                    compassEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              _InfoCard(
                icon: Icons.timer,
                label: 'Time',
                value: _timePretty,
                colour: Colors.deepPurple,
              ),
              const SizedBox(height: 5),
              _InfoCard(
                icon: Icons.social_distance,
                label: 'Distance from goal',
                value: '$distanceApart m',
                colour: Colors.indigo,
              ),
              const SizedBox(height: 5),
              _InfoCard(
                icon: Icons.workspace_premium,
                label: 'Trophies earned',
                value: '$points',
                colour: const Color.fromARGB(255, 240, 221, 55),
              ),
              const SizedBox(height: 5),
              _InfoCard(
                icon: Icons.emoji_events,
                label: 'Total trophies',
                value: '$totalPoints',
                colour: Colors.amber.shade700,
              ),
              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => MainApp(idToken: idToken, points: totalPoints),
                    ),
                    (_) => false,
                  );
                },
                label: Text('Continue', style: Constants.text40),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable card for stats
// ---------------------------------------------------------------------------
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.colour,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colour.withOpacity(0.15),
              radius: 24,
              child: Icon(icon, color: colour, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colour,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
