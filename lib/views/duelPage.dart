import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/constants.dart';

class Duelpage extends StatefulWidget {
  Duelpage({super.key, required this.friendName, required this.headers});

  final String friendName;
  final String? headers;

  @override
  State<Duelpage> createState() => _DuelpageState();
}

class _DuelpageState extends State<Duelpage> {
  late final String _friendName = widget.friendName;
  late String? idToken = widget.headers;


 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          children: [
            SizedBox(height: kBottomNavigationBarHeight * 3),
            Text(
              "Waiting for $_friendName to answer...",
              style: Constants.text,
            ),

            ElevatedButton(
              onPressed: () {
                //cancelDuel()
              },
              child: Center(child: Text("Cancel Duel")),
            ),
            
          ],
        ),
      ),
    );
  }
}
