import 'dart:convert';
import 'package:client/views/home.dart' show MainApp;
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:client/widgets/constants.dart';
import 'package:client/views/errorPage.dart';

class Login extends StatefulWidget {
  Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  Future<String?> getIdTokenOfUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
    
    }
    return await user?.getIdToken();
  }

  Future<Map<String, String>> createHeader() async {
    final idToken = await getIdTokenOfUser();
    if (idToken == null) {
      
    }

    // Prepare the header with the Bearer token
    final headers = {"Authorization": "Bearer $idToken"};
    return headers;
  }

  late final int? points;

  Future<void> displayName() async {
    //final String? name = FirebaseAuth.instance.currentUser!.displayName;
    // final url = Uri.parse(
    //   'http://${Constants.ipAddress}:8080/UpdateDisplayName?name=$name',
    // );
    try {
      final user = FirebaseAuth.instance.currentUser;
      final name = user?.displayName ?? "Unknown";

      final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/UpdateDisplayName?name=$name',
    );
      Map<String, String> headers = await createHeader();

      final response = await http.post(url, headers: headers);
      if (response.statusCode == 200) {
        // points = response.body as int?;
      } else {
        print('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      // Navigator.push(
      //     context,
      //     MaterialPageRoute(builder: (context) => ErrorPage()),
      //   );
      print('Exception: $e');
    }
  }

  Future<void> signIn() async {
    final url = Uri.parse('http://${Constants.ipAddress}:8080/Login?');

    try {
      Map<String, String> headers = await createHeader();

      final response = await http.post(url, headers: headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        points = decoded['Points'];
        // return points as int;
        // points = response.body as int?;
      } else {
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (context) => ErrorPage()),
        // );
      }
    } catch (e) {
      // Navigator.push(
      //     context,
      //     MaterialPageRoute(builder: (context) => ErrorPage()),
      //   );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            providers: [
              //Sign in via email and password
              EmailAuthProvider(),

              //Sign in via Google

              // Android
              // GoogleProvider(
              //   clientId:
              //       "444290227098-83qi3fh9lut7ni2hho4ea1tdb8a5m2oo.apps.googleusercontent.com")
              //       ,

              //IOS
              GoogleProvider(
                clientId:
                    "444290227098-vh0higrtr2q6qvsorsanupdqbl7vcdh7.apps.googleusercontent.com",
              ),
            ],
            headerBuilder: (context, constraints, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: MediaQuery.of(context).size.height * 0.1,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Center(
                          child: Text("Go back", style: Constants.text),
                        ),
                      ),
                    ),
                    SizedBox(width: 50),
                    FittedBox(
                      child: Image.asset(
                        'assets/images/LoggaText.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                ),
              );
            },

            subtitleBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child:
                    action == AuthAction.signIn
                        ? Text(
                          'Welcome to GeoHunt, please sign in!',
                          style: Constants.text,
                        )
                        : Text(
                          'Welcome to GeoHunt, please sign up!',
                          style: Constants.text,
                        ),
              );
            },
            footerBuilder: (context, action) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'By signing in, you agree to our terms and conditions.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
            sideBuilder: (context, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/LoggaText.png'),
                ),
              );
            },
          );
        }
        return FutureBuilder<List<dynamic>>(
          future: Future.wait([signIn(), getIdTokenOfUser(), displayName()]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData) {
              return const Center(child: Text("No token found"));
            }
            // final points = snapshot.data?[0] as int?;
            final idToken = snapshot.data?[1];

            return MainApp(idToken: idToken, points: points);
          },
        );
      },
    );
  }
}
