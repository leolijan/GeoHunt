import 'package:client/notifiers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/navbar_widget.dart';
import '../views/play.dart';
import '../views/leaderboard.dart';
import '../views/friends.dart';
import '../views/settings.dart';
import 'package:client/widgets/constants.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key, required this.idToken, required this.points});
  final String? idToken;
  final int? points;
  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  int currentPageIndex = 0;
  String userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Guest';
  late String? idToken = widget.idToken;
  late int? points = widget.points;
  late Map<String, String> headers = {"Authorization": "Bearer $idToken"};
  late String? isUsed;
  

  Future<void> displayName() async {
    final String? name = FirebaseAuth.instance.currentUser!.displayName;
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/UpdateDisplayName?name=$name',
    );
    try {
      final response = await http.post(url, headers: headers);
      if (response.statusCode == 200) {
        isUsed = response.body;
      } else {
        print('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  @override
  void initState() {
    super.initState();
  }

  void updateUserName() {
    setState(() {
      userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Guest';
    });
  }

  late List<Widget> pages = [
    FriendsScreen(idToken: idToken),
    Play(headers: idToken),
    LeaderboardScreen(idToken: idToken),
    //const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 150,

        leading: FittedBox(
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 10, bottom: 3),
                child: FittedBox(
                  child: Container(
                    width: 50,
                    height: 50,
                    child: Image.asset('assets/images/Trophy.png', fit: BoxFit.contain,)),
                ),
              ),
              FittedBox(
                child: Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 0),
                  child: Text("$points ", style: Constants.text40),
                  
                ),
              ),
            ],
          ),
        ),

        title: Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: SizedBox(
            height: kToolbarHeight*1.13,
            child: Image.asset('assets/images/LoggaVit.png', fit: BoxFit.contain),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 10, bottom: 5),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.35,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(100, kToolbarHeight),
                ),

                onPressed:
                    () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute<ProfileScreen>(
                          builder: (context) => profile(),
                        ),
                      ),
                    },
                child: FittedBox(
                  child:
                Row (

                  children: [
                    FittedBox(
                      child: Text(
                        userName,
                        overflow: TextOverflow.ellipsis,
                        style: Constants.text,
                      ),
                    
                    ),
                    Icon(
                      Icons.person,
                      size: 35,
                      color: Colors.white,
                    ),
                  ]
                ) 
                )
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: selectedPageNotifier,
        builder: (context, selectedPage, child) {
          return pages.elementAt(selectedPage);
        },
      ),
      bottomNavigationBar: NavbarWidget(idToken: idToken),
    );
  }

  ProfileScreen profile() {
    return ProfileScreen(
      appBar: AppBar(
        title: Text('Profile', textAlign: TextAlign.center, style : Constants.text),
        backgroundColor: Colors.teal,
        actions: [
          
          Padding(
            padding: EdgeInsets.only(right: 20, bottom: 5),
            child: ElevatedButton(
                onPressed:
                    () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsScreen()),
                      ),
                    },
                child: Icon(Icons.settings),
              ),
            ),
        ],
      ),

      actions: [
        DisplayNameChangedAction((context, oldName, newName) {
          if (newName.length <= 10 && newName.length >= 3) {
            setState(() {
              displayName().then((_) {
                if (isUsed == "Used") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name already used')),
                  );
                  FirebaseAuth.instance.currentUser?.updateDisplayName(oldName);
                } else {
                  updateUserName();
                }
              });
            });
          } else {
            setState(() {
              FirebaseAuth.instance.currentUser?.updateDisplayName(oldName);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Name must be less than 10 characters and more than 3'),
              ),
            );
          }
        }),
        SignedOutAction((context) {
          Navigator.of(context).pop();
        }),

      ],
    );
  }
}
