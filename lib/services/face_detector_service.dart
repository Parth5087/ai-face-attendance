import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum RegistrationAngle {
  front,
  left,
  right,
}

extension RegistrationAngleExtension on RegistrationAngle {
  String get label {
    switch (this) {
      case RegistrationAngle.front:
        return 'Front (Center)';
      case RegistrationAngle.left:
        return 'Left Angle';
      case RegistrationAngle.right:
        return 'Right Angle';
    }
  }

  String get guidance {
    switch (this) {
      case RegistrationAngle.front:
        return 'Look straight at camera & blink eyes 😉';
      case RegistrationAngle.left:
        return 'Turn head slightly to the left ⬅️ (~15°-25°)';
      case RegistrationAngle.right:
        return 'Turn head slightly to the right ➡️ (~15°-25°)';
    }
  }
}

class FaceValidationResult {
  final bool isValid;
  final String message;
  final bool isCentered;
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
    this.isCentered = true,
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
        minFaceSize: 0.10, // Relaxed from 0.15 for tablet kiosk distance
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
    bool isTablet = false,
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
    final isBothOpen = (leftEye != null && leftEye > 0.60) &&
        (rightEye != null && rightEye > 0.60);

    // Filter 0: Check if face is centered inside the guide frame (prevents corner/edge captures)
    final double centerX = face.boundingBox.center.dx / imageWidth;
    final double centerY = face.boundingBox.center.dy / imageHeight;
    final double minCenterX = isTablet ? 0.16 : 0.22;
    final double maxCenterX = isTablet ? 0.84 : 0.78;
    final double minCenterY = isTablet ? 0.12 : 0.18;
    final double maxCenterY = isTablet ? 0.88 : 0.82;
    if (centerX < minCenterX || centerX > maxCenterX || centerY < minCenterY || centerY > maxCenterY) {
      return FaceValidationResult(
        isValid: false,
        message: 'Center face inside the frame',
        isCentered: false,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    // Filter 1: Check minimum face size (Relaxed on tablet for desk/kiosk stand distance)
    final minRatio = isTablet ? 0.10 : 0.18;
    if (faceRatio < minRatio) {
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
    if (faceRatio > 0.88) {
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
    final maxYaw = isTablet ? 18.0 : 15.0;
    if (yaw != null && yaw.abs() > maxYaw) {
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
    final maxRoll = isTablet ? 22.0 : 16.0;
    if (roll != null && roll.abs() > maxRoll) {
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

    // Filter 5: Check vertical pitch (tablets on desk stands are tilted ~25°-30° upward)
    final maxPitch = isTablet ? 32.0 : 20.0;
    if (pitch != null && pitch.abs() > maxPitch) {
      return FaceValidationResult(
        isValid: false,
        message: 'Hold device at eye level',
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

  /// Specialized geometry & angle validation for multi-angle registration (Front, Left, Right)
  FaceValidationResult validateFaceForAngle({
    required Face face,
    required double imageWidth,
    required double imageHeight,
    required RegistrationAngle targetAngle,
  }) {
    final faceRatio = face.boundingBox.width / imageWidth;
    final yaw = face.headEulerAngleY; // Left/Right turn in degrees
    final pitch = face.headEulerAngleX; // Up/Down tilt in degrees
    final roll = face.headEulerAngleZ; // Slant in degrees

    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    final isBlinkingNow = (leftEye != null && leftEye < 0.25) || (rightEye != null && rightEye < 0.25);
    final isBothOpen = (leftEye != null && leftEye > 0.60) && (rightEye != null && rightEye > 0.60);

    // 1. Minimum Face Size
    if (faceRatio < 0.20) {
      return FaceValidationResult(
        isValid: false,
        message: 'Move closer to the camera',
        isTooSmall: true,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    // 2. Maximum Face Size
    if (faceRatio > 0.88) {
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

    // 3. Vertical Pitch (prevent looking at floor or ceiling)
    if (pitch != null && pitch.abs() > 22.0) {
      return FaceValidationResult(
        isValid: false,
        message: 'Hold device at eye level',
        isLookingAway: true,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    // 4. Slant (Roll)
    if (roll != null && roll.abs() > 20.0) {
      return FaceValidationResult(
        isValid: false,
        message: 'Keep head straight (do not slant)',
        isTilted: true,
        faceRatio: faceRatio,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        isBlinking: isBlinkingNow,
        isEyesOpen: isBothOpen,
      );
    }

    // 5. Yaw angle evaluation based on Target Angle
    switch (targetAngle) {
      case RegistrationAngle.front:
        if (yaw != null && yaw.abs() > 14.0) {
          return FaceValidationResult(
            isValid: false,
            message: 'Look straight at camera',
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
          message: 'Front angle aligned! Ready to capture',
          faceRatio: faceRatio,
          yaw: yaw,
          pitch: pitch,
          roll: roll,
          isBlinking: isBlinkingNow,
          isEyesOpen: isBothOpen,
        );

      case RegistrationAngle.left:
        // Ideal angle for side profile: 10° to 38°
        if (yaw == null || yaw.abs() < 8.0) {
          return FaceValidationResult(
            isValid: false,
            message: 'Turn head slightly to the left (←)',
            isLookingAway: false,
            faceRatio: faceRatio,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            isBlinking: isBlinkingNow,
            isEyesOpen: isBothOpen,
          );
        }
        if (yaw.abs() > 42.0) {
          return FaceValidationResult(
            isValid: false,
            message: 'Turned too far! Turn slightly back',
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
          message: 'Left angle aligned (${yaw.abs().toStringAsFixed(0)}°)! Ready to capture',
          faceRatio: faceRatio,
          yaw: yaw,
          pitch: pitch,
          roll: roll,
          isBlinking: isBlinkingNow,
          isEyesOpen: isBothOpen,
        );

      case RegistrationAngle.right:
        if (yaw == null || yaw.abs() < 8.0) {
          return FaceValidationResult(
            isValid: false,
            message: 'Turn head slightly to the right (→)',
            isLookingAway: false,
            faceRatio: faceRatio,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            isBlinking: isBlinkingNow,
            isEyesOpen: isBothOpen,
          );
        }
        if (yaw.abs() > 42.0) {
          return FaceValidationResult(
            isValid: false,
            message: 'Turned too far! Turn slightly back',
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
          message: 'Right angle aligned (${yaw.abs().toStringAsFixed(0)}°)! Ready to capture',
          faceRatio: faceRatio,
          yaw: yaw,
          pitch: pitch,
          roll: roll,
          isBlinking: isBlinkingNow,
          isEyesOpen: isBothOpen,
        );
    }
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
