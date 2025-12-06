import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Constants {
  static const String ipAddress = "localhost";
  static TextStyle text20 = GoogleFonts.bangers(
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                const Shadow(offset: Offset(2, 2), color: Colors.black54),
              ],
            );
  static TextStyle text = GoogleFonts.bangers(
              fontSize: 25,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                const Shadow(offset: Offset(2, 2), color: Colors.black54),
              ],
            );
  static TextStyle text40 = GoogleFonts.bangers(
              fontSize: 40,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                const Shadow(offset: Offset(2, 2), color: Colors.black54),
              ],
            );
  static TextStyle text60 = GoogleFonts.bangers(
              fontSize: 60,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                const Shadow(offset: Offset(2, 2), color: Colors.black54),
              ],
            );
}