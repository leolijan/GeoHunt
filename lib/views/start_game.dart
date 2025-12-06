import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';
import 'package:client/views/home.dart';
import 'package:client/widgets/constants.dart';
import 'package:client/widgets/google_maps.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'result.dart';

class StartGame extends StatefulWidget {
  final double gameRadius; // Radien som skickas med (i meter)
  final LatLng gameCenter; // Cirkeln center
  const StartGame({
    super.key,
    required this.gameRadius,
    required this.gameCenter,
    required this.location,
    required this.polylineCoordinates,
    required this.sliderValue,
    required this.currentPosition,
    required this.idToken,
  });
  final double sliderValue;
  final LatLng currentPosition; // Default position
  final List<LatLng> polylineCoordinates;
  final String? idToken;
  final LatLng location;

  @override
  State<StartGame> createState() => _StartGameState();
}

class _StartGameState extends State<StartGame> {
  final stopWatch = Stopwatch();
  late Timer _timer; // Timer to trigger periodic updates.
  bool isRunning = false;
  late LatLng currentPosition = widget.currentPosition;
  late double sliderValue = widget.sliderValue;
  late double sliderValue2 = 0;
  late List<LatLng> polylineCoordinates = widget.polylineCoordinates;
  late String? idToken = widget.idToken;
  late LatLng location = widget.location;
  late double rotation = Random().nextDouble() * 360;
  late int zoom = 100;
  late int radius =
      500; //TODO: maybe change this value to a lower one. Shouldn't need to be this high because the server checks that it is a valid location.
  late int hintInt = 0;

  late final String distanceApart;
  late final int points;
  late final int totalPoints;
  late Map<String, String> headers = {"Authorization": "Bearer $idToken"};
  int pressedAmount = 0;
  late double circleRadius;
  late LatLng circleCenter;
  late double circleRadius2;
  late LatLng circleCenter2;
  late bool showDistanceApart = false;
  late bool showDirection = false;
  late bool showCircle = false;

  late bool showCircle2 = false;
  late bool distanceHint = false;
  late LatLng positionPicture;
  late int? hintDistanceApart;
  final GlobalKey<GoogleMapsState> _mapKey = GlobalKey<GoogleMapsState>();

  @override
  void initState() {
    super.initState();
    stopWatch.start();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Triggers a rebuild.
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Clean up the timer to avoid memory leaks.
    super.dispose();
  }

  Future<void> guessButtonFunc() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/GuessLocation?lat=${position.latitude}&lon=${position.longitude}',
    );

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        distanceApart = decodedJson['Distance'];
        points = decodedJson['Points'];
        totalPoints = decodedJson['TotalPoints'];
        positionPicture = LatLng(
          decodedJson['Latitude'],
          decodedJson['Longitude'],
        );
      } else {
        print('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  Future<void> giveUpFunc() async {
    final url = Uri.parse('http://${Constants.ipAddress}:8080/GiveUp');

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);
        points = decodedJson['Points'];
      } else {
        print('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  getPicture() {
    return SizedBox.expand(
      child: Image.network(
        'https://maps.googleapis.com/maps/api/streetview?size=${width}x${height}&location=${location.latitude},${location.longitude}&fov=$zoom&heading=$rotation&pitch=0&radius=$radius&key=AIzaSyDj3hkMFFJMA1I1W8C-MhJZhnzm4ChshiY',
        fit: BoxFit.fill,
      ),
    );
  }

  Future<void> getHint() async {
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/GetHint?lat=${currentPosition.latitude}&lon=${currentPosition.longitude}',
    );

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decodedJson = jsonDecode(response.body);

        String hintType = decodedJson['Type'];

        if (hintType == "Circle1") {
          circleRadius = (decodedJson['Rad'] as num).toDouble();
          circleCenter = LatLng(decodedJson['Lat'], decodedJson['Lon']);

          _mapKey.currentState?.addCircle(
            center: circleCenter,
            radius: circleRadius * 1000,
            strokeColor: Colors.green,
            fillColor: Colors.green.withOpacity(0.3),
          );

          setState(() {
            mapOn = true;
            showCircle = true;
          });
        } else if (hintType == "Distance") {
          hintDistanceApart = decodedJson['Distance'];
        } else if (hintType == "Circle2") {
          circleRadius2 = (decodedJson['Rad'] as num).toDouble();
          circleCenter2 = LatLng(decodedJson['Lat'], decodedJson['Lon']);

          _mapKey.currentState?.addCircle(
            center: circleCenter2,
            radius: circleRadius2 * 1000,
            strokeColor: Colors.red,
            strokeWidth: 2,
            fillColor: Colors.red.withOpacity(0.3),
          );

          setState(() {
            mapOn = true;
            showCircle2 = true;
          });
        } else if (response.statusCode == 409) {}
      } else {
        print('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  late bool guessed = false;
  late bool yesOrNo = false;
  yesOrNow() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Are you sure?", style : Constants.text),
          content: Text("Do you want to give up?", style : Constants.text),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text("No", style : Constants.text20),
            ),
            TextButton(
              onPressed: () {
                yesOrNo = true;
                Navigator.of(context).pop(true);
              },
              child: Text("Yes", style : Constants.text20),
            ),
          ],
        );
      },
    );
  }

  guessedOrNot() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Are you sure?", style : Constants.text),
          content: Text("Do you want to Guess the Location?", style : Constants.text),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text("No", style : Constants.text),
            ),
            TextButton(
              onPressed: () {
                guessed = true;
                Navigator.of(context).pop(true);
              },
              child: Text("Yes", style : Constants.text),
            ),
          ],
        );
      },
    );
  }

  hintInfo() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "For each hint you use, the points you receive will decrease!",
            style: Constants.text,
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }

  //TODO: lägg till knappar för att stänga
  hintDistance() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            distanceHint
                ? "When you used this hint you were $hintDistanceApart meter away from the location"
                : "You are $hintDistanceApart meters away from the location",
            style: Constants.text,
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }

  hintCircle() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "You have received a hint on the map, go check it out!",
            style: Constants.text,
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }

  final _overlayController = OverlayPortalController();
  late int width;
  late int height;
  bool mapOn = false;
  bool toToggle = true;

  @override
  Widget build(BuildContext context) {
    width = (MediaQuery.of(context).size.width).round();
    height =
        mapOn
            ? (MediaQuery.of(context).size.height * 0.385).round()
            : (MediaQuery.of(context).size.height).round();
    int timeElapsed = stopWatch.elapsed.inSeconds;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 100,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.teal,
        title:
            (timeElapsed % 2 == 0)
                ? Text("Time Elapsed: $timeElapsed", style: Constants.text)
                : Text("Time Elapsed: $timeElapsed", style: Constants.text),
      ),

      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                getPicture(),
                Positioned(
                  top: 2,
                  left: 5,
                  child: ElevatedButton(
                    onPressed: () async {
                      await yesOrNow();
                      yesOrNo
                          ? (giveUpFunc().then(
                            (_) => Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return MainApp(
                                    idToken: idToken,
                                    points: points,
                                  );
                                },
                              ),
                              (route) {
                                return false;
                              },
                            ),
                          ))
                          : null;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Center(
                      child: Text("Give up", style: Constants.text),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black38,
                        ),
                        icon: Icon(Icons.arrow_back),
                        iconSize: 50,
                        onPressed: () {
                          setState(() {
                            rotation = rotation - 60;
                          });
                        },
                      ),
                      IconButton(
                        onPressed: () => {mapOn = !mapOn},
                        icon: mapOn ? Icon(Icons.close) : Icon(Icons.map),
                        iconSize: mapOn ? 50 : 80,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black38,
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black38,
                        ),
                        icon: Icon(Icons.arrow_forward),
                        iconSize: 50,
                        onPressed: () {
                          setState(() {
                            rotation = rotation + 60;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          mapOn
              ? Expanded(
                child: GoogleMaps(
                  key: _mapKey,
                  sliderValue: sliderValue,
                  currentPosition: currentPosition,
                  gamePosition: currentPosition,
                  circle:
                      showCircle
                          ? Circle(
                            circleId: CircleId('dynamic_1'),
                            center: circleCenter,
                            radius: circleRadius * 1000,
                            strokeColor: Colors.green,
                            strokeWidth: 2,
                            fillColor: Colors.green.withOpacity(0.3),
                          )
                          : null,
                  circle2:
                      showCircle2
                          ? Circle(
                            circleId: CircleId('dynamic_2'),
                            center: circleCenter2,
                            radius: circleRadius2 * 1000,
                            strokeColor: Colors.red,
                            strokeWidth: 2,
                            fillColor: Colors.red.withOpacity(0.3),
                          )
                          : null,

                  isInGame: true,
                  polylineCoordinates: polylineCoordinates,
                ),
              )
              : SizedBox(),
          Container(
            padding: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: Colors.teal.shade600),
            height: MediaQuery.of(context).size.height * 0.15,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      elevation: 50,
                      alignment: Alignment.bottomCenter,
                    ),
                    onPressed: () async {
                      await guessedOrNot();
                      guessed
                          ? (guessButtonFunc().then(
                            (_) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return Result(
                                    stopWatch: stopWatch,
                                    idToken: idToken,
                                    distanceApart: distanceApart,
                                    points: points,
                                    totalPoints: totalPoints,
                                    polylineCoordinates: polylineCoordinates,
                                    isInGame: false,
                                    currentPosition: currentPosition,
                                    sliderValue: sliderValue,
                                    positionPicture: positionPicture,
                                  );
                                },
                              ),
                            ),
                          ))
                          : null;
                    },
                    child: Center(
                      child: Text("Guess", style: Constants.text60),
                    ),
                  ),

                  OverlayPortal(
                    controller: _overlayController,
                    overlayChildBuilder:
                        (context) => Center(
                          child: Material(
                            elevation: 8,

                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 250,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                    
                                     IconButton(
                                          
                                          onPressed: () {
                                            hintInfo();
                                          },
                                          icon: Icon(Icons.info),
                                          iconSize: MediaQuery.of(context).size.width*0.09,
                                        ),
                                      
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            'Hints',
                                            style: Constants.text,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      
                                      IconButton(
                                        style : ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.black)),
                                        onPressed: () {

                                            _overlayController.toggle();
                                            toToggle = !toToggle;
                                          },
                                          icon: Icon(Icons.close),
                                          
                                          iconSize: MediaQuery.of(context).size.width*0.05,
                                          
                                        ),
                                      
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Hint 1
                                  if (pressedAmount == 0)
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (pressedAmount < 1) {
                                          await getHint();
                                          setState(() => pressedAmount = 1);
                                          hintCircle();
                                        }
                                      },
                                      child: Text(
                                        "Show Hint 1",
                                        style: Constants.text,
                                      ),
                                    ),

                                  // Hint 2
                                  if (pressedAmount >= 1)
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (!distanceHint) {
                                          await getHint();
                                          setState(() => pressedAmount = 2);

                                          await hintDistance();
                                          distanceHint = true;
                                        } else {
                                          hintDistance();
                                        }
                                      },
                                      child: Text(
                                        "Show Hint 2",
                                        style: Constants.text,
                                      ),
                                    ),

                                  // Hint 3
                                  if (pressedAmount == 2)
                                    ElevatedButton(
                                      onPressed: () async {
                                        await getHint();
                                        if (pressedAmount < 3) {
                                          setState(() => pressedAmount = 3);
                                          hintCircle();
                                        }
                                      },
                                      child: Text(
                                        "Show Hint 3",
                                        style: Constants.text,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _overlayController.toggle();
                        toToggle = !toToggle;
                      },
                      label: Text(""),
                      icon:
                          toToggle
                              ? Icon(
                                Icons.lightbulb,
                                color: Colors.yellow,
                                size: 90,
                              )
                              : Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 90,
                              ),

                      style: IconButton.styleFrom(backgroundColor: Colors.teal),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
