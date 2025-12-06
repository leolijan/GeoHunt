import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart'
    show DisplayNameChangedAction, ProfileScreen, SignedOutAction;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Example state variables for toggle settings.
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;
  String userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Guest';

  void updateUserName() {
    setState(() {
      userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Guest';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          
          // Notification Preferences
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text("Notifications"),
            value: notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                notificationsEnabled = value;
              });
            },
          ),
          const Divider(),

          // Map & Location Settings
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text("Map & Location Settings"),
            subtitle: const Text("Configure map options and radius"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to a screen where the user can adjust location settings.
              // Navigator.push(context, MaterialPageRoute(builder: (context) => MapSettingsScreen()));
            },
          ),
          const Divider(),

          // Appearance & Theme Options
          SwitchListTile(
            secondary: const Icon(Icons.brightness_6),
            title: const Text("Dark Mode"),
            value: darkModeEnabled,
            onChanged: (bool value) {
              setState(() {
                darkModeEnabled = value;
                // Add your theme changing logic here if necessary.
              });
            },
          ),
          const Divider(),

          // Privacy & Security
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Privacy & Security"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to a privacy & security details screen.
              // Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyScreen()));
            },
          ),
          const Divider(),

          // Support & Feedback
          ListTile(
            leading: const Icon(Icons.support),
            title: const Text("Support & Feedback"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to support or feedback page.
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SupportScreen()));
            },
          ),
          const Divider(),
        ],
      ),
    );
  }

  ProfileScreen profile() {
    return ProfileScreen(
      appBar: AppBar(
        title: Text('Profile', textAlign: TextAlign.center,),
        backgroundColor: Colors.teal,
      ),
      actions: [
        DisplayNameChangedAction((context, oldName, newName) {
          if (newName.length <= 20) {
            updateUserName();
          } else {
            setState(() {
              FirebaseAuth.instance.currentUser?.updateDisplayName(oldName);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Name must be less than 20 characters'),
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
