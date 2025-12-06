import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/constants.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.idToken});
  final String? idToken;
  // final List<String> name;
  // final List<int> pointsOfleaderBoard;
  // final int len;
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // Sample data for players
  late String? idToken = widget.idToken;
  late Map<String, String> headers = {"Authorization": "Bearer $idToken"};

  @override
  initState() {
    super.initState();
    updateLeaderboard();
   
  }

  disposeState() {
    super.dispose();
  }

  List<String> names = [];
  List<int> points = [];
  List<String> top       = List<String>.filled(3, '');
  List<int>    topPoints = List<int>.filled(3, 0);  

  // Function to update the leaderboard via REST API
  Future<void> updateLeaderboard() async {
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/UpdateLeaderboard',
    );
    try {
      // Ändra URL:en till din servers endpoint för leaderboard.

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        names = List<String>.from(decoded['Names']);
        points = List<int>.from(decoded['Points']);
        setState(() {
          int topCount = names.length >= 3 ? 3 : names.length;
          top = names.sublist(0, topCount);
          topPoints = points.sublist(0, topCount);

          names = names.sublist(topCount);
          points = points.sublist(topCount);
        });
        // fillTopNames();
        // fillTopPoints();
      } else {
        print('Servern svarade med statuskod: ${response.statusCode}');
      }
    } catch (e) {
      print('HTTP-fel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 5,
          ),
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                right: 5,
                top: 10,
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () {
                    updateLeaderboard();
                  },
                  icon: Icon(Icons.refresh),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                    flex: 1,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 10), 
                            Image.asset("assets/images/Silver.png"),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.4,
                            child: Text(
                              '${top[1]} ${topPoints[1]}',
                              style: Constants.text,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    flex: 1,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [Image.asset("assets/images/Gold.png")],
                        ),
                        Positioned(
                          top: 50,
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.3,
                            child: Text(
                              '${top[0]} ${topPoints[0]}',
                              style: Constants.text,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    flex: 1,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 10),
                            Image.asset("assets/images/Bronze.png"),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.3,
                            child: Text(
                              '${top[2]} ${topPoints[2]}',
                              style: Constants.text,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          Expanded(
            child:
                names.isEmpty
                    ? Text('No players yet')
                    : ListView.builder(
                      itemCount: names.length,
                      itemBuilder: (context, index) {
                        final nameOfPlayers = names[index];
                        return ListTile(
                          leading: Text('${index + 4}.', style: Constants.text),
                          title: Text(
                            nameOfPlayers.toString(),
                            style: Constants.text,
                          ),
                          trailing: Text(
                            points[index].toString(),
                            style: Constants.text,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
