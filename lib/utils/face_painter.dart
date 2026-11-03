import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final bool isFrontCamera;
  final bool isBlinkDetected;

  FacePainter({
    required this.faces,
    required this.imageSize,
    this.isFrontCamera = true,
    this.isBlinkDetected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Inner rectangle and corner brackets removed for a clean Apple FaceID look.
    // The central glowing Oval Viewfinder now handles all visual feedback.
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.isBlinkDetected != isBlinkDetected;
  }
}
