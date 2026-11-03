import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceValidationResult {
  final bool isValid;
  final String message;
  final bool isTooSmall;
  final bool isLookingAway;
  final bool isTilted;
  final bool isBlinking;
  final bool isEyesOpen;
  final double faceRatio;
  final double? yaw;
  final double? pitch;
  final double? roll;

  FaceValidationResult({
    required this.isValid,
    required this.message,
    this.isTooSmall = false,
    this.isLookingAway = false,
    this.isTilted = false,
    this.isBlinking = false,
    this.isEyesOpen = false,
    this.faceRatio = 0.0,
    this.yaw,
    this.pitch,
    this.roll,
  });
}

class FaceDetectorService {
  late FaceDetector _detector;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true, // For blink & eye probability
        enableTracking: true,
        minFaceSize: 0.15,
      ),
    );
    _isInitialized = true;
    debugPrint('[FACE_DETECTOR] Initialized with accurate mode & eye classification');
  }

  Future<List<Face>> processImage(InputImage inputImage) async {
    if (!_isInitialized) initialize();
    return await _detector.processImage(inputImage);
  }

  /// Evaluates face size, position, and pose angle
  FaceValidationResult validateFaceGeometry({
    required Face face,
    required double imageWidth,
    required double imageHeight,
  }) {
    // 1. Calculate size ratio (face width vs frame width)
    final faceRatio = face.boundingBox.width / imageWidth;

    final yaw = face.headEulerAngleY; // Left/right turn
    final pitch = face.headEulerAngleX; // Up/down tilt
    final roll = face.headEulerAngleZ; // Head slant

    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    final isBlinkingNow = (leftEye != null && leftEye < 0.25) ||
        (rightEye != null && rightEye < 0.25);
    final isBothOpen = (leftEye != null && leftEye > 0.65) &&
        (rightEye != null && rightEye > 0.65);

    // Filter 1: Check minimum face size (Must be at least 26% of frame width to avoid photos on other phones)
    if (faceRatio < 0.26) {
      return FaceValidationResult(
        isValid: false,
        message: 'Move closer to camera',
        isTooSmall: true,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    // Filter 2: Check if face is too close / overflowing frame
    if (faceRatio > 0.85) {
      return FaceValidationResult(
        isValid: false,
        message: 'Move slightly back',
        isTooSmall: false,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    // Filter 3: Check head rotation (looking left or right)
    if (yaw != null && yaw.abs() > 14.0) {
      return FaceValidationResult(
        isValid: false,
        message: 'Look straight at the camera',
        isLookingAway: true,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    // Filter 4: Check head tilt (roll / tilt)
    if (roll != null && roll.abs() > 14.0) {
      return FaceValidationResult(
        isValid: false,
        message: 'Keep head straight',
        isTilted: true,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    // Filter 5: Check vertical pitch (looking too high or too low)
    if (pitch != null && pitch.abs() > 18.0) {
      return FaceValidationResult(
        isValid: false,
        message: 'Hold phone at eye level',
        isLookingAway: true,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    return FaceValidationResult(
      isValid: true,
      message: 'Face position & angle perfect!',
      faceRatio: faceRatio,
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      isBlinking: isBlinkingNow,
      isEyesOpen: isBothOpen,
    );
  }

  bool isBlinking(Face face) {
    if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
      return face.leftEyeOpenProbability! < 0.25 || face.rightEyeOpenProbability! < 0.25;
    }
    return false;
  }

  bool isBothEyesOpen(Face face) {
    if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
      return face.leftEyeOpenProbability! > 0.65 && face.rightEyeOpenProbability! > 0.65;
    }
    return true;
  }

  void dispose() {
    if (_isInitialized) {
      _detector.close();
      _isInitialized = false;
    }
  }
}
