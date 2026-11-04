import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../services/attendance_service.dart';
import '../utils/image_converter.dart';
import '../widgets/face_id_ring_viewfinder.dart';
import '../widgets/biometric_viewfinder.dart';
import '../widgets/premium_back_button.dart';

class RegisterStaffScreen extends StatefulWidget {
  const RegisterStaffScreen({super.key});

  /// ⚙️ CONFIGURATION FLAG:
  /// - `false`: Standard Front Camera Mode with Active Blink Verification (Fast & Recommended).
  /// - `true`: Apple Face ID 360° Circular Continuous Head Scan.
  static const bool enableMultiAngleFaceId = false;

  @override
  State<RegisterStaffScreen> createState() => _RegisterStaffScreenState();
}

class _RegisterStaffScreenState extends State<RegisterStaffScreen>
    with SingleTickerProviderStateMixin {
  // Mode flag: Dynamic toggle (false: Quick Blink, true: 360° Face ID)
  bool _useMultiAngle = RegisterStaffScreen.enableMultiAngleFaceId;

  void _setEnrollmentMode(bool multiAngle) {
    if (_useMultiAngle == multiAngle) return;
    HapticFeedback.selectionClick();
    setState(() {
      _useMultiAngle = multiAngle;
      _resetScan();
    });
  }

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isDisposed = false;
  bool _isSwitchingCamera = false;

  String _guidanceMessage = 'Position your face inside the frame';
  Color _guidanceColor = AppColors.cyanAccent;
  bool _isFaceAligned = false;

  // Liveness & Blink State (Standard Front Mode)
  bool _eyesWereOpen = false;
  bool _livenessVerified = false;
  DateTime? _lastVerifiedTime;
  DateTime? _lastLogTime;
  Face? _lastDetectedFace;

  // Multi-Angle Circular State (Reserved for Multi-Angle Mode)
  final Set<int> _completedTicks = {};
  static const int _totalTicks = 48;
  double _currentAngleRad = -pi / 2;
  bool _hasActivePointer = false;
  bool _hasFrontLook = false;
  bool _hasLeftTurn = false;
  bool _hasRightTurn = false;
  bool _isMultiAngleCompleted = false;

  bool _isCapturing = false;
  img.Image? _capturedFaceCrop;
  Uint8List? _capturedFaceJpgBytes;
  final List<List<double>> _angleEmbeddings = [];

  AttendanceService get _attendanceService {
    try {
      return context.read<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
  }

  /// Dynamic readiness check: Real human verified AND currently aligned inside guide.
  bool get _isReadyToCapture =>
      (_livenessVerified || _isMultiAngleCompleted) &&
      _isFaceAligned &&
      _lastDetectedFace != null;

  late AnimationController _pulseController;

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String _selectedRole = 'Office Staff';
  String _selectedDepartment = 'Operations';

  final List<String> _roles = [
    'Office Staff',
    'Delivery Boy',
    'Warehouse',
    'Manager',
    'Admin'
  ];

  final List<String> _departments = [
    'Operations',
    'Logistics',
    'Sales',
    'Customer Support',
    'IT / Admin'
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _guidanceMessage = 'No camera found on this device';
          _guidanceColor = AppColors.roseError;
        });
        return;
      }

      // Default to front camera for selfie enrollment
      _selectedCameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[ENROLLMENT] Camera init error: $e');
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await controller.initialize();
      if (!mounted || _isDisposed) {
        await controller.dispose().catchError((_) {});
        return;
      }

      // Explicitly turn off flash to prevent iOS native Retina Screen Flash
      await controller.setFlashMode(FlashMode.off).catchError((_) {});

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
      });

      _startImageStream();
    } catch (e) {
      debugPrint('[ENROLLMENT] Camera setup error: $e');
    }
  }

  void _startImageStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isDisposed) {
      return;
    }
    if (_cameraController!.value.isStreamingImages) return;

    final faceDetector = _attendanceService.faceDetectorService;

    try {
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isProcessingFrame || _isCapturing || _isDisposed) return;
        _isProcessingFrame = true;

        try {
          final inputImage = ImageConverter.toInputImage(
            cameraImage: image,
            camera: _cameras[_selectedCameraIndex],
          );

          if (inputImage != null) {
            final faces = await faceDetector.processImage(inputImage);

            if (mounted) {
              if (_useMultiAngle) {
                _evaluateMultiAngle(faces, image.width.toDouble(), image.height.toDouble());
              } else {
                _evaluateStandardFront(faces, image.width.toDouble(), image.height.toDouble());
              }
            }
          }
        } catch (e) {
          debugPrint('[ENROLLMENT] Stream error: $e');
        } finally {
          _isProcessingFrame = false;
        }
      });
    } catch (e) {
      debugPrint('[ENROLLMENT] startImageStream error: $e');
    }
  }

  // ==========================================
  // STANDARD FRONT CAMERA MODE EVALUATION
  // ==========================================
  void _evaluateStandardFront(List<Face> faces, double imgWidth, double imgHeight) {
    if (_isCapturing || _capturedFaceCrop != null) return;

    if (faces.isEmpty) {
      _updateGuidance(
        'Position your face inside the frame',
        AppColors.cyanAccent,
        aligned: false,
      );
      _eyesWereOpen = false;
      _lastDetectedFace = null;

      // Security timeout: If face leaves camera for > 6 seconds, reset verification
      if (_livenessVerified && _lastVerifiedTime != null) {
        if (DateTime.now().difference(_lastVerifiedTime!).inSeconds > 6) {
          debugPrint('[ENROLLMENT_LOG] ⏳ Face absent for >6s. Resetting verification.');
          _livenessVerified = false;
          _lastVerifiedTime = null;
        }
      }
      return;
    }

    if (faces.length > 1) {
      _updateGuidance(
        'Multiple faces detected! Only 1 person allowed',
        AppColors.amberWarning,
        aligned: false,
      );
      _eyesWereOpen = false;
      _lastDetectedFace = null;
      return;
    }

    final face = faces.first;
    _lastDetectedFace = face;

    final faceDetector = _attendanceService.faceDetectorService;
    final validation = faceDetector.validateFaceGeometry(
      face: face,
      imageWidth: imgWidth,
      imageHeight: imgHeight,
    );

    final now = DateTime.now();

    // Periodic Log every 600ms
    if (_lastLogTime == null || now.difference(_lastLogTime!).inMilliseconds > 600) {
      _lastLogTime = now;
      final sizePercent = (validation.faceRatio * 100).toInt();
      final lEye = face.leftEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A';
      final rEye = face.rightEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A';
      final yawStr = validation.yaw?.toStringAsFixed(1) ?? '0.0';
      final pitchStr = validation.pitch?.toStringAsFixed(1) ?? '0.0';

      debugPrint(
        '[ENROLLMENT_LOG] [FRONT_MODE] FaceSize: $sizePercent% | Yaw: $yawStr° | Pitch: $pitchStr° | '
        'Eyes: [L:$lEye, R:$rEye] | Verified: $_livenessVerified | Msg: ${validation.message}',
      );
    }

    // Geometry check (Size, Pitch, Roll, Yaw)
    if (!validation.isValid) {
      _updateGuidance(
        validation.message,
        validation.isTooSmall ? AppColors.amberWarning : AppColors.roseError,
        aligned: false,
      );
      _eyesWereOpen = false;
      return;
    }

    // Active Blink Verification (Liveness)
    if (!_livenessVerified) {
      if (validation.isEyesOpen) _eyesWereOpen = true;

      if (_eyesWereOpen && validation.isBlinking) {
        _livenessVerified = true;
        _lastVerifiedTime = DateTime.now();
        HapticFeedback.mediumImpact();
        debugPrint('[ENROLLMENT_LOG] 🎯 LIVE BLINK DETECTED! Real human person verified.');

        _updateGuidance(
          'Ready to capture! Tap Capture Face 👇',
          AppColors.emeraldGreen,
          aligned: true,
        );
      } else {
        _updateGuidance(
          'Please blink your eyes naturally 😉',
          AppColors.cyanAccent,
          aligned: true,
        );
      }
    } else {
      // Verified and face is properly aligned right now
      _lastVerifiedTime = DateTime.now();
      _updateGuidance(
        'Ready to capture! Tap Capture Face 👇',
        AppColors.emeraldGreen,
        aligned: true,
      );
    }
  }

  // ==========================================
  // MULTI-ANGLE CIRCULAR MODE (OPTIONAL)
  // ==========================================
  void _evaluateMultiAngle(List<Face> faces, double imgWidth, double imgHeight) {
    if (_isCapturing || _isMultiAngleCompleted) return;
    if (faces.isEmpty || faces.length > 1) {
      _updateGuidance(
        faces.isEmpty ? 'Position face inside circular ring' : 'Only 1 person allowed',
        AppColors.cyanAccent,
        aligned: false,
      );
      _hasActivePointer = false;
      return;
    }

    final face = faces.first;
    _lastDetectedFace = face;
    final faceDetector = _attendanceService.faceDetectorService;
    final validation = faceDetector.validateFaceGeometry(
      face: face,
      imageWidth: imgWidth,
      imageHeight: imgHeight,
    );

    if (validation.isTooSmall) {
      _updateGuidance('Move closer to camera', AppColors.amberWarning, aligned: false);
      return;
    }

    if (!_livenessVerified) {
      if (validation.isEyesOpen) _eyesWereOpen = true;
      if (_eyesWereOpen && validation.isBlinking) {
        _livenessVerified = true;
        HapticFeedback.mediumImpact();
      } else {
        _updateGuidance('Blink eyes naturally 😉', AppColors.cyanAccent, aligned: true);
        return;
      }
    }

    final yaw = validation.yaw ?? 0.0;
    final pitch = validation.pitch ?? 0.0;
    final dist = sqrt(yaw * yaw + pitch * pitch);

    bool newTicksAdded = false;
    if (dist < 7.0) {
      _hasFrontLook = true;
      _hasActivePointer = false;
      for (final idx in [46, 47, 0, 1, 2]) {
        if (_completedTicks.add(idx)) newTicksAdded = true;
      }
    } else {
      final angle = atan2(-pitch, yaw);
      _currentAngleRad = angle;
      _hasActivePointer = true;

      var norm = (angle + (pi / 2)) % (2 * pi);
      if (norm < 0) norm += 2 * pi;
      final centerTick = ((norm / (2 * pi)) * _totalTicks).round() % _totalTicks;

      for (int offset = -2; offset <= 2; offset++) {
        final tickIdx = (centerTick + offset + _totalTicks) % _totalTicks;
        if (_completedTicks.add(tickIdx)) newTicksAdded = true;
      }
      if (yaw <= -11.0) _hasLeftTurn = true;
      if (yaw >= 11.0) _hasRightTurn = true;
    }

    if (newTicksAdded) {
      HapticFeedback.selectionClick();
      setState(() {});
    }

    if ((_completedTicks.length >= 38 || (_hasFrontLook && _hasLeftTurn && _hasRightTurn))) {
      for (int i = 0; i < _totalTicks; i++) {
        _completedTicks.add(i);
      }
      _isMultiAngleCompleted = true;
      _hasActivePointer = false;
      HapticFeedback.heavyImpact();
      _updateGuidance('360° Scan Complete! Tap Capture Face 👇', AppColors.emeraldGreen, aligned: true);
      setState(() {});
    }
  }

  // ==========================================
  // CAPTURE BUTTON ACTION
  // ==========================================
  Future<void> _captureFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (!_isReadyToCapture && _capturedFaceCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!_livenessVerified
              ? 'Please blink naturally to enable capture.'
              : 'Please look directly at the camera.'),
          backgroundColor: AppColors.amberWarning,
        ),
      );
      return;
    }

    final targetFace = _lastDetectedFace;
    if (targetFace == null && _capturedFaceCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position your face inside the frame and look directly at camera.'),
          backgroundColor: AppColors.amberWarning,
        ),
      );
      return;
    }

    if (_isCapturing) return;
    _isCapturing = true;

    try {
      debugPrint('[ENROLLMENT_LOG] 📸 Taking portrait for face embedding...');
      await _cameraController!.stopImageStream();
      await _cameraController!.setFlashMode(FlashMode.off).catchError((_) {});

      final xFile = await _cameraController!.takePicture();
      final fullImage = await ImageConverter.decodeOrientedImage(xFile);

      if (fullImage == null) {
        debugPrint('[ENROLLMENT_LOG] Failed to decode captured image.');
        _isCapturing = false;
        _startImageStream();
        return;
      }

      if (!mounted) return;
      final attendanceService = _attendanceService;

      // Detect face directly on the captured photo for pixel-perfect coordinates
      final photoInput = InputImage.fromFilePath(xFile.path);
      final photoFaces = await attendanceService.faceDetectorService.processImage(photoInput);
      final activeFaceBox = photoFaces.isNotEmpty
          ? photoFaces.first.boundingBox
          : (targetFace?.boundingBox ?? Rect.zero);

      debugPrint(
        '[ENROLLMENT_LOG] 📐 Photo: ${fullImage.width}x${fullImage.height} | '
        'Face Box: ${activeFaceBox.width.toInt()}x${activeFaceBox.height.toInt()} '
        'at (${activeFaceBox.left.toInt()}, ${activeFaceBox.top.toInt()})',
      );

      // Diagnostic Anti-Spoofing Check
      final spoofResult = attendanceService.antiSpoofingService.checkLiveness(
        fullImage: fullImage,
        faceX: activeFaceBox.left.toInt(),
        faceY: activeFaceBox.top.toInt(),
        faceWidth: activeFaceBox.width.toInt(),
        faceHeight: activeFaceBox.height.toInt(),
      );

      if (spoofResult != null) {
        debugPrint(
          '[SPOOF_LOG] Enrollment Spoof Check: Real=${(spoofResult.realScore * 100).toStringAsFixed(1)}% | '
          'Fake=${(spoofResult.fakeScore * 100).toStringAsFixed(1)}% | Class=${spoofResult.predictedClass}',
        );
      }

      // Crop face with exact coordinates
      final croppedFace = ImageConverter.cropFaceFromDecoded(
        originalImage: fullImage,
        boundingBox: activeFaceBox,
      );

      if (croppedFace == null) {
        debugPrint('[ENROLLMENT_LOG] Could not crop face.');
        _isCapturing = false;
        _startImageStream();
        return;
      }

      // Extract 192-float biometric embedding
      final embedding = attendanceService.mlService.predict(croppedFace);
      if (embedding == null) {
        debugPrint('[ENROLLMENT_LOG] Failed to extract face embedding.');
        _isCapturing = false;
        _startImageStream();
        return;
      }

      _capturedFaceCrop = croppedFace;
      _capturedFaceJpgBytes = Uint8List.fromList(img.encodeJpg(croppedFace));
      _angleEmbeddings.clear();
      _angleEmbeddings.add(embedding);

      debugPrint('[ENROLLMENT_LOG] ✅ Face enrolled! Biometric vector extracted.');
      HapticFeedback.heavyImpact();

      if (mounted) {
        setState(() {
          _guidanceMessage = 'Face captured! Enter staff details below';
          _guidanceColor = AppColors.emeraldGreen;
        });

        // On mobile, show modal bottom sheet. On tablet kiosk, right pane already contains the form!
        if (!context.isTablet) {
          await _showDetailsSheet(croppedFace);
        }
      }
    } catch (e) {
      debugPrint('[ENROLLMENT_LOG] Capture error: $e');
      _isCapturing = false;
      _startImageStream();
    } finally {
      _isCapturing = false;
    }
  }

  void _updateGuidance(String msg, Color color, {required bool aligned}) {
    if (_guidanceMessage != msg || _guidanceColor != color || _isFaceAligned != aligned) {
      setState(() {
        _guidanceMessage = msg;
        _guidanceColor = color;
        _isFaceAligned = aligned;
      });
    }
  }

  void _resetScan() {
    setState(() {
      _livenessVerified = false;
      _eyesWereOpen = false;
      _isFaceAligned = false;
      _lastDetectedFace = null;
      _lastVerifiedTime = null;
      _capturedFaceCrop = null;
      _capturedFaceJpgBytes = null;
      _angleEmbeddings.clear();
      _completedTicks.clear();
      _hasFrontLook = false;
      _hasLeftTurn = false;
      _hasRightTurn = false;
      _isMultiAngleCompleted = false;
      _guidanceMessage = _useMultiAngle
          ? 'Position face inside the circular ring'
          : 'Position your face inside the frame';
      _guidanceColor = AppColors.cyanAccent;
    });

    if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
      _startImageStream();
    }
  }

  Future<void> _submitStaffRegistration() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (_capturedFaceCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture employee face first.'),
          backgroundColor: AppColors.amberWarning,
        ),
      );
      return;
    }

    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both Name and Employee Code'),
          backgroundColor: AppColors.amberWarning,
        ),
      );
      return;
    }

    final attendanceService = _attendanceService;
    debugPrint('[ENROLLMENT_LOG] Saving employee "$name" ($code)...');
    final success = await attendanceService.registerStaff(
      name: name,
      employeeCode: code,
      role: _selectedRole,
      department: _selectedDepartment,
      faceImage: _capturedFaceCrop!,
      precomputedAngleEmbeddings: _angleEmbeddings,
    );

    if (mounted) {
      if (success) {
        debugPrint('[ENROLLMENT_LOG] 🎉 Employee "$name" enrolled successfully.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee "$name" enrolled successfully!'),
            backgroundColor: AppColors.emeraldGreen,
          ),
        );
        Navigator.pop(context); // Return to Dashboard
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save biometric profile. Try again.'),
            backgroundColor: AppColors.roseError,
          ),
        );
        _startImageStream();
      }
    }
  }

  Future<void> _showDetailsSheet(img.Image croppedFace) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final mediaQuery = MediaQuery.of(ctx);
            final double keyboardHeight = mediaQuery.viewInsets.bottom;
            final double systemNavHeight = mediaQuery.viewPadding.bottom;
            final double bottomSpacing = max(keyboardHeight, systemNavHeight) + 24.0;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * 0.90,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: bottomSpacing,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: AppColors.emeraldGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Staff Information',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Face Profile Ready',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Full Name Field
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'e.g. Rahul Patel',
                          prefixIcon: Icon(Icons.person_outline, color: AppColors.cyanAccent),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),

                      // Employee Code Field
                      TextField(
                        controller: _codeController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          labelText: 'Employee Code / ID',
                          hintText: 'e.g. EMP-101',
                          prefixIcon: Icon(Icons.badge_outlined, color: AppColors.cyanAccent),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 14),

                      // Role Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(Icons.work_outline, color: AppColors.cyanAccent),
                        ),
                        dropdownColor: AppColors.surfaceCard,
                        items: _roles.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(r, style: const TextStyle(color: AppColors.textPrimary)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Department Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDepartment,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          prefixIcon: Icon(Icons.business_outlined, color: AppColors.cyanAccent),
                        ),
                        dropdownColor: AppColors.surfaceCard,
                        items: _departments.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(d, style: const TextStyle(color: AppColors.textPrimary)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => _selectedDepartment = val);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _submitStaffRegistration();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save & Register Staff'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() {
        _guidanceMessage = 'Face captured! Tap Continue or Retake';
        _guidanceColor = AppColors.emeraldGreen;
      });
    }
  }

  void _toggleCamera() async {
    if (_cameras.length < 2 || _isSwitchingCamera) return;
    _isSwitchingCamera = true;

    setState(() {
      _isCameraInitialized = false;
    });

    final oldController = _cameraController;
    _cameraController = null;

    try {
      if (oldController != null) {
        if (oldController.value.isStreamingImages) {
          await oldController.stopImageStream().catchError((_) {});
        }
        await oldController.dispose().catchError((_) {});
      }

      if (!mounted || _isDisposed) return;

      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      _resetScan();
      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[ENROLLMENT] Camera toggle error: $e');
    } finally {
      if (mounted) {
        _isSwitchingCamera = false;
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pulseController.dispose();
    final oldController = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;
    oldController?.dispose().catchError((e) {
      debugPrint('[ENROLLMENT] Camera dispose error: $e');
    });
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCaptured = _capturedFaceCrop != null && _capturedFaceJpgBytes != null;
    final bool canProceed = hasCaptured || _isReadyToCapture;
    final bool isCamReady = !_isDisposed &&
        _isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    final bottomInset = context.bottomInset;
    final isTablet = context.isTablet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 28.0 : 20.0),
          child: Row(
            children: [
              const PremiumBackButton(),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _useMultiAngle ? 'Face ID Enrollment (360°)' : 'Register Employee Face',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _resetScan,
                tooltip: 'Re-scan Face',
              ),
              if (_cameras.length > 1 && !hasCaptured)
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios_outlined),
                  onPressed: _toggleCamera,
                  tooltip: 'Switch Camera',
                ),
            ],
          ),
        ),
      ),
      body: isTablet
          ? Row(
              children: [
                // 📟 Left Pane: Camera Stream with Biometric Viewfinder Guide & Capture Controls
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 10, bottomInset + 16),
                    child: Column(
                      children: [
                        if (!hasCaptured) _buildModeToggle(hasCaptured),
                        _buildGuidanceBanner(hasCaptured),
                        Expanded(
                          child: _buildCameraViewportContainer(
                            hasCaptured: hasCaptured,
                            isCamReady: isCamReady,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCaptureButton(canProceed, hasCaptured),
                      ],
                    ),
                  ),
                ),

                // 📟 Right Pane: Permanent Employee Information Form
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10, 4, 20, bottomInset + 16),
                    child: _buildTabletFormPane(hasCaptured),
                  ),
                ),
              ],
            )
          : SafeArea(
              bottom: true,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
                child: Column(
                  children: [
                    // Dynamic Mode Switcher (Quick Blink vs 360° Face ID)
                    if (!hasCaptured) _buildModeToggle(hasCaptured),

                    // Floating Modern Guidance Banner
                    _buildGuidanceBanner(hasCaptured),

                    // Center Viewport
                    Expanded(
                      child: _buildCameraViewportContainer(
                        hasCaptured: hasCaptured,
                        isCamReady: isCamReady,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom Action Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _buildCaptureButton(canProceed, hasCaptured),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModeToggle(bool hasCaptured) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141E30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cyanAccent.withValues(alpha: 0.20),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // ⚡ Option 1: Quick Blink (Standard)
          Expanded(
            child: GestureDetector(
              onTap: hasCaptured ? null : () => _setEnrollmentMode(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_useMultiAngle ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !_useMultiAngle
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: !_useMultiAngle ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Quick Blink',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: !_useMultiAngle ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔄 Option 2: 360° Face ID
          Expanded(
            child: GestureDetector(
              onTap: hasCaptured ? null : () => _setEnrollmentMode(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _useMultiAngle ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _useMultiAngle
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 16,
                      color: _useMultiAngle ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '360° Face ID',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _useMultiAngle ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceBanner(bool hasCaptured) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _guidanceColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _guidanceColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasCaptured || _isReadyToCapture
                  ? Icons.check_circle_rounded
                  : (_isFaceAligned ? Icons.visibility_rounded : Icons.info_outline_rounded),
              color: _guidanceColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasCaptured
                  ? 'Face captured! Enter staff details below'
                  : _guidanceMessage,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _guidanceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraViewportContainer({required bool hasCaptured, required bool isCamReady}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xFF0C101C),
        border: Border.all(
          color: _isReadyToCapture || hasCaptured
              ? AppColors.emeraldGreen
              : AppColors.borderLight,
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isReadyToCapture || hasCaptured
                ? AppColors.emeraldGreen.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29.8),
        child: hasCaptured
            ? _buildCapturedReviewView()
            : (isCamReady
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // Full camera preview inside viewport using FittedBox
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? 720,
                            height: _cameraController!.value.previewSize?.width ?? 1280,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),

                      // Viewfinder Presentation
                      if (_useMultiAngle) ...[
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: const Size(290, 290),
                              painter: FaceIdRingPainter(
                                completedTicks: _completedTicks,
                                totalTicks: _totalTicks,
                                currentAngleRad: _currentAngleRad,
                                hasActivePointer: _hasActivePointer,
                                isCompleted: _isMultiAngleCompleted,
                                pulseValue: _pulseController.value,
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final Color borderCol = _isReadyToCapture
                                  ? AppColors.emeraldGreen
                                  : (_isFaceAligned
                                      ? AppColors.cyanAccent
                                      : (_guidanceColor == AppColors.roseError
                                          ? AppColors.roseError
                                          : (_guidanceColor == AppColors.amberWarning
                                              ? AppColors.amberWarning
                                              : Colors.white.withValues(alpha: 0.4))));

                              return CustomPaint(
                                painter: BiometricOvalPainter(
                                  borderColor: borderCol,
                                  isVerified: _isReadyToCapture,
                                  pulseValue: _pulseController.value,
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Floating Real Human Verified Badge (Inside Live Oval)
                      if (_isReadyToCapture && !_useMultiAngle)
                        Positioned(
                          bottom: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0F1D).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.emeraldGreen),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emeraldGreen.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, color: AppColors.emeraldGreen, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Face Verified',
                                  style: TextStyle(
                                    color: AppColors.emeraldGreen,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppColors.cyanAccent),
                  )),
      ),
    );
  }

  Widget _buildCaptureButton(bool canProceed, bool hasCaptured) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: canProceed ? AppColors.successGradient : null,
            color: canProceed ? null : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: canProceed
                ? [
                    BoxShadow(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: canProceed
                  ? (hasCaptured
                      ? (context.isTablet
                          ? _submitStaffRegistration
                          : () => _showDetailsSheet(_capturedFaceCrop!))
                      : _captureFace)
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasCaptured
                        ? (context.isTablet ? Icons.save_rounded : Icons.arrow_forward_rounded)
                        : (_isReadyToCapture
                            ? Icons.camera_alt_rounded
                            : (_livenessVerified
                                ? Icons.face_retouching_natural_rounded
                                : Icons.remove_red_eye_rounded)),
                    color: canProceed ? Colors.white : AppColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hasCaptured
                        ? (context.isTablet ? 'Save & Register Staff' : 'Continue to Staff Details')
                        : (_isReadyToCapture
                            ? 'Capture Face'
                            : (_livenessVerified
                                ? 'Look Directly at Camera'
                                : 'Blink Eyes to Capture')),
                    style: TextStyle(
                      color: canProceed ? Colors.white : AppColors.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (hasCaptured) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _resetScan,
              icon: const Icon(Icons.refresh_rounded, size: 19, color: AppColors.cyanAccent),
              label: const Text(
                'Retake Photo',
                style: TextStyle(
                  color: AppColors.cyanAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent.withValues(alpha: 0.08),
                side: BorderSide(
                  color: AppColors.cyanAccent.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 📟 Tablet Kiosk Form Pane (Right Side)
  Widget _buildTabletFormPane(bool hasCaptured) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasCaptured ? AppColors.emeraldGreen : AppColors.cyanAccent)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasCaptured ? Icons.verified_user_rounded : Icons.badge_outlined,
                    color: hasCaptured ? AppColors.emeraldGreen : AppColors.cyanAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Staff Details Form',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      hasCaptured ? 'Face Profile Enrolled' : 'Awaiting Face Capture',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasCaptured ? AppColors.emeraldGreen : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Full Name Field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Rahul Patel',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.cyanAccent),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            // Employee Code Field
            TextField(
              controller: _codeController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Employee Code / ID',
                hintText: 'e.g. EMP-101',
                prefixIcon: Icon(Icons.badge_outlined, color: AppColors.cyanAccent),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 14),

            // Role Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.work_outline, color: AppColors.cyanAccent),
              ),
              dropdownColor: AppColors.surfaceCard,
              items: _roles.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r, style: const TextStyle(color: AppColors.textPrimary)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 14),

            // Department Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedDepartment,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Department',
                prefixIcon: Icon(Icons.business_outlined, color: AppColors.cyanAccent),
              ),
              dropdownColor: AppColors.surfaceCard,
              items: _departments.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(d, style: const TextStyle(color: AppColors.textPrimary)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDepartment = val);
              },
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: hasCaptured ? _submitStaffRegistration : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.surfaceCard,
                ),
                child: Text(
                  hasCaptured ? 'Save & Register Staff' : 'Capture Face to Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: hasCaptured ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🌟 Biometric Review Card (Presented when photo is captured)
  Widget _buildCapturedReviewView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF131D31), Color(0xFF0A0F1D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BiometricRadarBackgroundPainter(),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.emeraldGreen, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'Biometric Profile Ready',
                            style: TextStyle(
                              color: AppColors.emeraldGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Avatar with standard nested container
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.emeraldGreen,
                              width: 3.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emeraldGreen.withValues(alpha: 0.35),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: ClipOval(
                            child: Image.memory(
                              _capturedFaceJpgBytes!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              key: const ValueKey('enrolled_review_face'),
                              width: 138,
                              height: 138,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: AppColors.successGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0A0F1D), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emeraldGreen.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Face Enrolled Successfully',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildQualityChip(
                          icon: Icons.verified_user_rounded,
                          label: 'Quality: Excellent',
                          color: AppColors.emeraldGreen,
                        ),
                        const SizedBox(width: 10),
                        _buildQualityChip(
                          icon: Icons.hd_outlined,
                          label: 'High Quality',
                          color: AppColors.cyanAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
