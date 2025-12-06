import 'dart:convert';

import 'package:client/views/friendProfile.dart';
import 'package:client/widgets/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.idToken});
  final String? idToken;

  @override
  State<FriendsScreen> createState() => _FriendsScreen();
}

class _FriendsScreen extends State<FriendsScreen> {
  late String? nameOfFriend; //Det som skrivs in i textrutan
  late String? idToken = widget.idToken;
  late Map<String, String> headers = {"Authorization": "Bearer $idToken"};

  late List<String?> friendRequests = [];
  late List<int?> pointsListRequests = [];
  late List<String?> friendList = [];
  late List<int?> pointsList = [];
  final TextEditingController _controller = TextEditingController();

  final String name = FirebaseAuth.instance.currentUser!.uid; //User ID

  // Exempeldata – i praktiken kan detta vara en lista med objekt som innehåller både namn och trophies
  @override
  initState() {
    super.initState();
    getFriendRequests();
    getFriendsList();
  }

  Future<void> duelFriend(String displayName) async {
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/DuelFriend?name=${displayName}',
    );
    try {
      // Ändra URL:en till din servers endpoint för leaderboard.

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // Omvandlar JSON-svaret till en lista med objekt
        final decoded = json.decode(response.body);
        //TODO: snacka med backend grabbarna vad man ska kunan ha här?
      } else {
        // print('Servern svarade med statuskod: ${response.statusCode}');
      }
    } catch (e) {
      // print('HTTP-fel: $e');
    }
  }

  Future<String?> sendFriendRequest() async {
  
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/SendFriendRequest?name=$nameOfFriend',
    );
    try {
     

      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        print('Servern svarade med statuskod: ${response.statusCode}');
      }
    } catch (e) {
      print('HTTP-fel: $e');
    }
    return null;
  }

  Future<void> answerFriendRequest(String yesOrNo, String userName) async {
    String answer = yesOrNo;
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/AnswerFriendRequest?ans=$answer&name=$userName',
    );
    try {
    
      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
      } else {
        print('Servern svarade med statuskod: ${response.statusCode}');
      }
    } catch (e) {
      print('HTTP-fel: $e');
    }
  }

  Future<void> getFriendsList() async {
    final url = Uri.parse('http://${Constants.ipAddress}:8080/GetFriendList');
    try {
      

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // Omvandlar JSON-svaret till en lista med objekt
        final decoded = json.decode(response.body);
        setState(() {
          friendList = List<String?>.from(decoded['Friends']);
          pointsList = List<int?>.from(decoded['Points']);
        });
      } else {
        print('Servern svarade med statuskod: ${response.statusCode}');
      }
    } catch (e) {
      print('HTTP-fel: $e');
    }
  }

  Future<void> getFriendRequests() async {
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/GetFriendRequests',
    );
    try {
    
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // Omvandlar JSON-svaret till en lista med objekt
        setState(() {
          final decoded = json.decode(response.body);
          friendRequests = List<String>.from(decoded['FriendRequests']);
          pointsListRequests = List<int?>.from(decoded["Points"]);
        });
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
          const SizedBox(height: 20),
          searchBar(),
          const SizedBox(height: 20),
          Text(
            'Friend requests',
            style: Constants.text,
          ),
          const Divider(),
          (friendRequests.isEmpty)
              ? Column(
                children: [
                  Text(
                    "You have no friend request",
                    style: TextStyle(fontSize: 15),
                  ),
                  SizedBox(height: 30),
                ],
              )
              : Expanded(
                child: ListView.builder(
                  itemCount: friendRequests.length,
                  itemBuilder: (context, index) {
                    final friendRequest = friendRequests[index];
                    return ListTile(
                      leading: const Icon(Icons.person_add),
                      title: Text(friendRequest.toString(), style: Constants.text),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              await answerFriendRequest(
                                "accept",
                                friendRequest.toString(),
                              );
                              await getFriendsList();
                              setState(() {
                                friendRequests.clear();
                              });
                              await getFriendRequests();
                            },
                            icon: const Icon(Icons.check, color: Colors.green),
                          ),
                          IconButton(
                            onPressed: () async {
                              await answerFriendRequest(
                                "reject",
                                friendRequest.toString(),
                              );
                              await getFriendsList();
                              setState(() {
                                friendRequests.clear();
                              });
                              await getFriendRequests();
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      ),

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => FriendDetailsScreen(
                                  friendName: friendRequests[index],
                                  trophies: pointsListRequests[index],
                                  isFriend: false,
                                  idToken: idToken,
                                ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          const Divider(),
          Text(
            'Friends',
            style: Constants.text,
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: friendList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(friendList[index].toString(), style: Constants.text,),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => FriendDetailsScreen(
                              friendName: friendList[index],
                              trophies: pointsList[index] as int,
                              isFriend: true,
                              idToken: idToken,
                            ),
                      ),
                    ).then((_) async {
                      setState(() {
                        friendList = [];
                        pointsList = [];
                      });
                      await Future.delayed(Duration(milliseconds: 500));
                      await getFriendsList();
                    });
                  },
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      elevation: 50,
                      alignment: Alignment.bottomCenter,
                    ),
                    onPressed: () async {
                      await duelFriend(friendList[index].toString());
                    },
                    child: Text("Duel", style: Constants.text),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Row searchBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: (value) => nameOfFriend = value,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black,
              labelText: 'Enter username',
              labelStyle: Constants.text,
              border: const OutlineInputBorder(),
            ),
          ),
        ),

        const SizedBox(width: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: () async {
            String? found = await sendFriendRequest();
            _controller.clear();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(found!)));
          },
          child: Center(
            child: Text(
              'Add friend',
              style: Constants.text,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
