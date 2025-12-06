import 'dart:convert';
import 'dart:typed_data';

import 'package:client/views/duelPage.dart';
import 'package:client/views/settings.dart';
import 'package:client/views/start_game.dart';
import 'package:client/widgets/google_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/constants.dart';

class Play extends StatefulWidget {
  const Play({super.key, required this.headers});
  final String? headers;
  @override
  State<Play> createState() => _Play();
}

class _Play extends State<Play> {
  final LatLng _currentPosition = const LatLng(0, 0);
  late String? idToken = widget.headers;

  late Map<String, String> headers = {"Authorization": "Bearer $idToken"};

  late final double locationLatitude;
  late final double locationLongitude;
  late LatLng gamePosition;
  final GlobalKey<GoogleMapsState> _mapKey = GlobalKey<GoogleMapsState>();

  double sliderValue = 5.5;
  late List<String?> friendList = [];
  late List<int?> pointsList = [];
  late Position position;
  late LatLng actualPos = LatLng(position.latitude, position.longitude);

  @override
  void initState() {
    super.initState();
  }

  Future<void> getFriendsList() async {
    final url = Uri.parse('http://${Constants.ipAddress}:8080/GetFriendList');
    try {
      // Ändra URL:en till din servers endpoint för leaderboard.

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // Omvandlar JSON-svaret till en lista med objekt
        final decoded = json.decode(response.body);
        setState(() {
          friendList = List<String?>.from(decoded['Friends']);
          pointsList = List<int?>.from(decoded['Points']);
        });
      } else {
        // print('Servern svarade med statuskod: ${response.statusCode}');
      }
    } catch (e) {
      // print('HTTP-fel: $e');
    }
  }

  Future<void> duelFriend(String displayName) async {
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/SendDuelRequest?name=${displayName}',
    );
    try {
      // Ändra URL:en till din servers endpoint för leaderboard.

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // Omvandlar JSON-svaret till en lista med objekt
        final decoded = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    Duelpage(friendName: displayName, headers: idToken),
          ),
        );

        //TODO: snacka med backend grabbarna vad man ska kunan ha här?
      } else {
        // print('Servern svarade med statuskod: ${response.statusCode}');
      }
    } catch (e) {
      // print('HTTP-fel: $e');
    }
  }

  Future<void> getDuelRequest(String displayName) async {
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/GetDuelRequest?name=${displayName}',
    );
    try {
      // Ändra URL:en till din servers endpoint för leaderboard.

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // Omvandlar JSON-svaret till en lista med objekt
        final decoded = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    Duelpage(friendName: displayName, headers: idToken),
          ),
        );

        //TODO: snacka med backend grabbarna vad man ska kunan ha här?
      } else {
        // print('Servern svarade med statuskod: ${response.statusCode}');
      }
    } catch (e) {
      // print('HTTP-fel: $e');
    }
  }

  Future<void> sendLocation() async {
    position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    // LatLng position = LatLng(
    //   59.83968232794139,
    //   17.646918147808357
    // ); // TODO: just here for testing

    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/GenerateGame?lat=${position.latitude}&lon=${position.longitude}&rad=${sliderValue.toInt()}',
    );

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        locationLatitude = decodedJson['Latitude'];
        locationLongitude = decodedJson['Longitude'];
        gamePosition = LatLng(locationLatitude, locationLongitude);
      } else {
        print('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  final _overlayController = OverlayPortalController();
  double value10 = 5;
  double value20 = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
         
          Padding(
            padding: const EdgeInsets.only(
              top: 15,
              left: 10,
              right: 10,
              bottom: 10,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4,

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.teal, width: 5),
              ),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),

                child: GoogleMaps(
                  key: _mapKey,
                  sliderValue: sliderValue,
                  currentPosition: _currentPosition,
                  isInGame: false,

                  polylineCoordinates: [],
                ),
              ),
            ),
          ),

          SizedBox(height: 20),

          Slider(
            label: "Radius in Km",
            max: 10,
            min: 1,
            value: sliderValue,
            onChanged: (value) {
              setState(() {
                sliderValue = value;
                sliderValue.toInt();
              });
            },
          ),

          Text(
            "The radius is ${sliderValue.toInt()}  km",
            style: Constants.text,
          ),
          SizedBox(height: 10),
          playGameButton(context),
          SizedBox(height: 20),
          OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder:
                (context) => Positioned(
                  top: kToolbarHeight * 2.2,
                  left: kToolbarHeight,

                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: MediaQuery.sizeOf(context).height * 0.4,
                      width: MediaQuery.sizeOf(context).width * 0.75,
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        // ‹– ersätter ListView.builder›
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: kBottomNavigationBarHeight/10),
                          Text(
                            "The radius is ${value10.toInt()}  km",
                            style: Constants.text,
                            textAlign: TextAlign.center,
                            
                          ),
                         
                          Slider(
                            label: "Radius in Km",
                            max: 10,
                            min: 1,
                            value: value10,
                            onChanged: (value) {
                              setState(() {
                                value10 = value;
                                value10.toInt();
                              });
                            },
                          ),
                          
                          // ───── Titelfältet ─────
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),

                            child: Text(
                              'Choose a friend to duel',
                              style: Constants.text.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Divider(color: Colors.white),

                          Expanded(
                            child: ListView.builder(
                              itemCount: friendList.length,
                              physics: NeverScrollableScrollPhysics(),

                              itemBuilder: (context, index) {
                                return ListTile(
                                  leading: const Icon(Icons.person, size: 40),
                                  title: Text(
                                    friendList[index].toString(),
                                    style: Constants.text,
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => Duelpage(
                                                friendName:
                                                    friendList[index]
                                                        .toString(),
                                                headers: idToken,
                                              ),
                                        ),
                                      );
                                      await duelFriend(
                                        friendList[index].toString(),
                                      );
                                    },
                                    child: Text("Duel", style: Constants.text),
                                    style: ElevatedButton.styleFrom(
                                      elevation: 50,
                                      shadowColor: Colors.black,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                await getFriendsList();
                _overlayController.toggle();
              },
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.4,
                child: Center(
                  child: Text("Duel a Friend", style: Constants.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SizedBox playGameButton(BuildContext context) {
    return SizedBox(
      height: 70,
      width: MediaQuery.of(context).size.width * 0.6,
      child: ElevatedButton(
        onPressed: () async {
          await sendLocation();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                return StartGame(
                  sliderValue: sliderValue,
                  currentPosition: actualPos,
                  polylineCoordinates: [],
                  gameRadius: sliderValue * 1000,
                  gameCenter: actualPos,
                  location: gamePosition,
                  idToken: idToken,
                );
              },
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 50,
          animationDuration: Duration(milliseconds: 200),
          backgroundColor: Colors.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
        child: Center(child: Text('Start Game', style: Constants.text40)),
      ),
    );
  }
}
