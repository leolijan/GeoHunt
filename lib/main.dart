import 'package:client/views/errorPage.dart';
import 'package:client/widgets/constants.dart';
import 'package:flutter/material.dart';
import 'package:client/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/login.dart';


void main() async {
  //G.O.A.T.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return ErrorPage(); // visa din egen error-sida
  };

  // Ensure that firebase services are initialized before using them
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Starts the application
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
          
        ),
      ),
      home: PreLogin(),
    ),
  );
}

class PreLogin extends StatelessWidget {
  const PreLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 10),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Image.asset("assets/images/LoggaText.png")),
            ),
            SafeArea(
              child: ElevatedButton(
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(Size(200, 50)), 
                  backgroundColor: WidgetStateProperty.all(Colors.teal.shade500),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return Login();
                      },
                    ),
                  );
                },
                child: Center(
                  child: Text(
                    'Get started',
                    style: Constants.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
