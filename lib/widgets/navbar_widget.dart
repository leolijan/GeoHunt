import 'package:client/notifiers.dart';
import 'package:client/widgets/constants.dart';
import 'package:flutter/material.dart';

class NavbarWidget extends StatefulWidget {
  const NavbarWidget({super.key, required this.idToken});
  final String? idToken;
  @override
  State<NavbarWidget> createState() => _NavbarWidgetState();
}

class _NavbarWidgetState extends State<NavbarWidget> {
  late String? idToken = widget.idToken;
  late final List<Map<String, dynamic>> players;
  late Map<String, String> headers = {"Authorization": "Bearer $idToken"};

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedPageNotifier,
      builder: (context, selectedPage, child) {
        return NavigationBar(
          labelTextStyle: WidgetStateProperty.all<TextStyle>(Constants.text),

          destinations: [
            NavigationDestination(icon: Icon(Icons.people), label: 'Friends'),
            NavigationDestination(icon: Icon(Icons.play_arrow), label: 'Play'),
            NavigationDestination(
              icon: Icon(Icons.leaderboard),
              label: 'Leaderboard',
            ),
          ],
          onDestinationSelected: (int value) async {
            selectedPageNotifier.value = value;
          },

          selectedIndex: selectedPage,
        );
      },
    );
  }
}
