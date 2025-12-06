import 'dart:convert';
import 'package:client/main.dart';
import 'package:client/views/home.dart' show MainApp;
import 'package:client/views/login.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:client/widgets/constants.dart';

class ErrorPage extends StatelessWidget {
  /// Called when the user taps **Try again**.
  ///
  /// Defaults to `Navigator.pop(context)` if omitted.
  final VoidCallback? onRetry;

  const ErrorPage({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connection failed',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "We couldn't reach the server. Please check your internet connection and try again.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed:
                      onRetry ??
                      () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => PreLogin()),
                        (Route<dynamic> route) => false,
                      ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                  style: ElevatedButton.styleFrom(
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
