import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'friends.dart';

import '../widgets/constants.dart';

class FriendDetailsScreen extends StatefulWidget {
  final String? friendName;
  final int? trophies;
  final bool isFriend;
  final String? idToken;
  

  FriendDetailsScreen({
    super.key,
    required this.friendName,
    required this.trophies,
    required this.isFriend,
    required this.idToken,
    
  });

  @override
  State<FriendDetailsScreen> createState() => _FriendDetailsScreenState();
}

class _FriendDetailsScreenState extends State<FriendDetailsScreen> {
  
  late Map<String, String> headers = {"Authorization": "Bearer ${widget.idToken}"};

  Future<void> removeFriend() async {
    final url = Uri.parse(
      'http://${Constants.ipAddress}:8080/RemoveFriend?name=${widget.friendName}',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(.5),
              theme.colorScheme.primaryContainer,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      widget.friendName != null && widget.friendName!.isNotEmpty
                          ? widget.friendName![0].toUpperCase()
                          : '?',
                      
                       style: theme.textTheme.headlineMedium!
                          .copyWith(color: Colors.white),
                   
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.friendName ?? '',
                    style: Constants.text40,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/Trophy.png',
                        width: 32,
                        height: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.trophies} trophies',
                        style: Constants.text
                      ),
                    ],
                  ),
                  if (widget.isFriend) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        
                        icon: Icon(Icons.person_remove, size: 35),
                        label: Text('Remove Friend', style: Constants.text),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          await removeFriend();
                          if (mounted) Navigator.of(context).pop(true);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
