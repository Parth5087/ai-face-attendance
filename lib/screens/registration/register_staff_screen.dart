import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../services/attendance_service.dart';
import '../../utils/image_converter.dart';
import '../../core/responsive.dart';
import '../../widgets/biometric_viewfinder.dart';
import '../../widgets/face_id_ring_viewfinder.dart';
import '../../widgets/premium_back_button.dart';
import '../../widgets/premium_text_field.dart';
import '../../widgets/premium_dropdown.dart';
import 'views/mobile_register_view.dart';
import 'views/tablet_register_view.dart';

class RegisterStaffScreen extends StatefulWidget {
  const RegisterStaffScreen({super.key});

  /// Default starting mode:
  /// - `false`: Quick Blink (Standard single front face capture)
  /// - `true`: 360° Face ID (Apple Face ID radial continuous head scan)
  static const bool defaultTo360Mode = false;

  @override
  State<RegisterStaffScreen> createState() => _RegisterStaffScreenState();
}

class _RegisterStaffScreenState extends State<RegisterStaffScreen>
    with SingleTickerProviderStateMixin {
  AttendanceService get _attendanceService {
    try {
      return context.read<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
  }

  // Dynamic Mode Toggle: false = Quick Blink (Single), true = 360° Face ID
  bool _useMultiAngle = RegisterStaffScreen.defaultTo360Mode;

  void _setEnrollmentMode(bool multiAngle) {
    if (_useMultiAngle == multiAngle) return;
    HapticFeedback.selectionClick();
    debugPrint('[KIOSK_DEBUG] 🔄 Mode toggled to: ${multiAngle ? "360° Face ID" : "Quick Blink"}');
    setState(() {
      _useMultiAngle = multiAngle;
      _resetScan();
    });
  }

  // Camera Management
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isDisposed = false;
  bool _isSwitchingCamera = false;

  // Guidance & State
  String _guidanceMessage = 'Position your face inside the frame';
  Color _guidanceColor = AppColors.cyanAccent;
  bool _isFaceAligned = false;
  Face? _lastDetectedFace;

  // Mode 1: Quick Blink (Standard Single Front Mode)
  bool _eyesWereOpen = false;
  bool _livenessVerified = false;
  DateTime? _lastVerifiedTime;
  DateTime? _autoCaptureStartTime;

  // Mode 2: 360° Face ID Radial Ring State
  final Set<int> _completedTicks = {};
  static const int _totalTicks = 48;
  double _currentAngleRad = -pi / 2;
  bool _hasActivePointer = false;
  bool _hasFrontLook = false;
  bool _hasLeftTurn = false;
  bool _hasRightTurn = false;
  bool _isMultiAngleCompleted = false;

  // Throttle timer for unified debug logging
  DateTime? _lastLogTime;

  // Captured Face & Embeddings
  bool _isCapturing = false;
  bool _isSaving = false;
  img.Image? _capturedFaceCrop;
  Uint8List? _capturedFaceJpgBytes;
  final List<List<double>> _angleEmbeddings = [];

  // ⚡ Instant Stream Buffer & Best Quality Tracker
  CapturedFrame? _latestCapturedFrame;

  // 🔄 360° Mode Frontal Frame Cache (Preserves straight portrait)
  img.Image? _cachedFrontalCrop;
  Uint8List? _cachedFrontalJpgBytes;
  List<double>? _cachedFrontalEmbedding;
  double _bestFrontalScore = 0.0;

  bool get _isReadyToCapture =>
      (_useMultiAngle ? _isMultiAngleCompleted : (_livenessVerified && _isFaceAligned)) &&
      _lastDetectedFace != null;

  late AnimationController _pulseController;

  // Form Controllers
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
    'Human Resources',
    'Management'
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (!mounted || _isDisposed) return;
      if (_cameras.isEmpty) {
        _updateGuidance('No camera found on device', AppColors.roseError, aligned: false);
        return;
      }

      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[KIOSK_DEBUG] Camera init error: $e');
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
    );

    try {
      await controller.initialize();
      if (!mounted || _isDisposed) {
        await controller.dispose().catchError((_) {});
        return;
      }

      await controller.setFlashMode(FlashMode.off).catchError((_) {});

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
      });

      debugPrint(
        '[KIOSK_DEBUG] 🚀 Camera Initialized: ${camera.name} (${camera.lensDirection}) | '
        'SensorOrientation: ${camera.sensorOrientation}° | PreviewSize: ${controller.value.previewSize?.width}x${controller.value.previewSize?.height}',
      );

      _startImageStream();
    } catch (e) {
      debugPrint('[KIOSK_DEBUG] Camera setup error: $e');
    }
  }

  void _startImageStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isDisposed ||
        _capturedFaceCrop != null) {
      return;
    }
    if (_cameraController!.value.isStreamingImages) return;

    final attendanceService = _attendanceService;
    final faceDetector = attendanceService.faceDetectorService;

    try {
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isProcessingFrame || _isCapturing || _isDisposed) return;
        _isProcessingFrame = true;

        // 🛡️ Synchronously clone native camera planes into safe pure Dart memory!
        final safeFrame = CapturedFrame.fromCameraImage(image);
        _latestCapturedFrame = safeFrame;

        try {
          final isLandscape = mounted && MediaQuery.of(context).orientation == Orientation.landscape;
          final isTablet = mounted && context.isTablet;

          // Convert image with dynamic orientation compensation for horizontal/vertical tablets
          final inputImage = ImageConverter.toInputImage(
            cameraImage: image,
            camera: _cameras[_selectedCameraIndex],
            deviceOrientation: _cameraController?.value.deviceOrientation,
            screenOrientation: isLandscape ? Orientation.landscape : Orientation.portrait,
          );

          if (inputImage != null) {
            final faces = await faceDetector.processImage(inputImage);
            if (!mounted || _isDisposed) return;

            // 🔍 Unified Periodic Logging with [KIOSK_DEBUG] tag (throttled every 600ms)
            final now = DateTime.now();
            if (_lastLogTime == null || now.difference(_lastLogTime!).inMilliseconds > 600) {
              _lastLogTime = now;
              final orientStr = isLandscape ? 'LANDSCAPE' : 'PORTRAIT';
              final devStr = isTablet ? 'TABLET' : 'PHONE';

              if (faces.isEmpty) {
                debugPrint(
                  '[KIOSK_DEBUG] ⏳ Scanning... No face | Device: $devStr ($orientStr) | '
                  'CamSensor: ${_cameras[_selectedCameraIndex].sensorOrientation}° | Frame: ${image.width}x${image.height}',
                );
              } else if (faces.length > 1) {
                debugPrint('[KIOSK_DEBUG] ⚠️ Multiple faces in frame: ${faces.length}');
              } else {
                final face = faces.first;
                final ratio = ((face.boundingBox.width / image.width) * 100).toStringAsFixed(1);
                final yaw = face.headEulerAngleY?.toStringAsFixed(1) ?? '0.0';
                final pitch = face.headEulerAngleX?.toStringAsFixed(1) ?? '0.0';
                final roll = face.headEulerAngleZ?.toStringAsFixed(1) ?? '0.0';
                final lEye = face.leftEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A';
                final rEye = face.rightEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A';

                if (_useMultiAngle) {
                  debugPrint(
                    '[KIOSK_DEBUG] 🔄 [360_MODE] Device: $devStr ($orientStr) | FaceRatio: $ratio% | '
                    'Yaw: $yaw° | Pitch: $pitch° | Roll: $roll° | Ticks: ${_completedTicks.length}/$_totalTicks | Done: $_isMultiAngleCompleted',
                  );
                } else {
                  debugPrint(
                    '[KIOSK_DEBUG] ⚡ [BLINK_MODE] Device: $devStr ($orientStr) | FaceRatio: $ratio% | '
                    'Yaw: $yaw° | Pitch: $pitch° | Roll: $roll° | Eyes: [L:$lEye, R:$rEye] | Verified: $_livenessVerified | Msg: "$_guidanceMessage"',
                  );
                }
              }
            }

            final rotationAngle = ImageConverter.computeRotationCompensation(
              camera: _cameras[_selectedCameraIndex],
              deviceOrientation: _cameraController?.value.deviceOrientation,
              screenOrientation: isLandscape ? Orientation.landscape : Orientation.portrait,
            );
            final double actualWidth = (rotationAngle == 90 || rotationAngle == 270)
                ? image.height.toDouble()
                : image.width.toDouble();
            final double actualHeight = (rotationAngle == 90 || rotationAngle == 270)
                ? image.width.toDouble()
                : image.height.toDouble();

            if (_useMultiAngle) {
              _evaluateMultiAngle(
                faces,
                actualWidth,
                actualHeight,
                isTablet: isTablet,
                capturedFrame: safeFrame,
              );
            } else {
              _evaluateStandardFront(
                faces,
                actualWidth,
                actualHeight,
                isTablet: isTablet,
                capturedFrame: safeFrame,
              );
            }
          }
        } catch (e) {
          debugPrint('[KIOSK_DEBUG] ❌ Stream error: $e');
        } finally {
          _isProcessingFrame = false;
        }
      });
    } catch (e) {
      debugPrint('[KIOSK_DEBUG] ❌ Stream start error: $e');
    }
  }

  // =========================================================================
  // ⚡ MODE 1: QUICK BLINK (STANDARD SINGLE FRONT FACE MODE + AUTO-CAPTURE)
  // =========================================================================
  void _evaluateStandardFront(
    List<Face> faces,
    double imgWidth,
    double imgHeight, {
    required bool isTablet,
    CapturedFrame? capturedFrame,
  }) {
    if (_isCapturing || _capturedFaceCrop != null) return;

    if (faces.isEmpty) {
      _updateGuidance(
        'Position your face inside the frame',
        AppColors.cyanAccent,
        aligned: false,
      );
      _eyesWereOpen = false;
      _lastDetectedFace = null;
      _autoCaptureStartTime = null;

      if (_livenessVerified && _lastVerifiedTime != null) {
        if (DateTime.now().difference(_lastVerifiedTime!).inSeconds > 5) {
          _livenessVerified = false;
          _lastVerifiedTime = null;
        }
      }
      return;
    }

    if (faces.length > 1) {
      _updateGuidance(
        'Multiple faces detected! Only 1 person allowed in frame.',
        AppColors.amberWarning,
        aligned: false,
      );
      _eyesWereOpen = false;
      _lastDetectedFace = null;
      _autoCaptureStartTime = null;
      return;
    }

    final face = faces.first;
    _lastDetectedFace = face;

    final validation = _attendanceService.faceDetectorService.validateFaceGeometry(
      face: face,
      imageWidth: imgWidth,
      imageHeight: imgHeight,
      isTablet: isTablet,
    );

    if (!validation.isValid) {
      _updateGuidance(
        validation.message,
        (validation.isTooSmall || !validation.isCentered) ? AppColors.amberWarning : AppColors.roseError,
        aligned: false,
      );
      _eyesWereOpen = false;
      _livenessVerified = false;
      _autoCaptureStartTime = null;
      return;
    }

    // Active Eye Blink Verification
    if (!_livenessVerified) {
      if (validation.isEyesOpen) _eyesWereOpen = true;

      if (_eyesWereOpen && validation.isBlinking) {
        _livenessVerified = true;
        _lastVerifiedTime = DateTime.now();
        HapticFeedback.lightImpact();
        debugPrint('[KIOSK_DEBUG] 🎯 Blink detected! Waiting for eyes to reopen for auto-capture...');
        _updateGuidance(
          'Real human verified! Hold still to capture... 📸',
          AppColors.emeraldGreen,
          aligned: true,
        );
      } else {
        _updateGuidance(
          'Face aligned! Please blink naturally 😉',
          AppColors.amberWarning,
          aligned: true,
        );
      }
    } else {
      _lastVerifiedTime = DateTime.now();

      // ⚡ Smart Zero-Lag Auto-Capture: Instant capture once eyes are open again!
      if (validation.isEyesOpen && !_isCapturing && _capturedFaceCrop == null) {
        _autoCaptureStartTime ??= DateTime.now();
        final elapsedMs = DateTime.now().difference(_autoCaptureStartTime!).inMilliseconds;
        _updateGuidance(
          'Real human verified! Capturing photo... 📸',
          AppColors.emeraldGreen,
          aligned: true,
        );

        if (elapsedMs >= 150) {
          _autoCaptureStartTime = null;
          debugPrint('[KIOSK_DEBUG] ⚡ Zero-lag auto-capturing face from verified stream frame!');
          _captureFace(activeFace: face, capturedFrame: capturedFrame);
        }
      } else {
        _autoCaptureStartTime = null;
        _updateGuidance(
          'Real human verified! Hold still with eyes open... 📸',
          AppColors.emeraldGreen,
          aligned: true,
        );
      }
    }
  }

  // =========================================================================
  // 🔄 MODE 2: 360° FACE ID (APPLE FACE ID CONTINUOUS CIRCULAR RING + AUTO-CAPTURE)
  // =========================================================================
  void _evaluateMultiAngle(
    List<Face> faces,
    double imgWidth,
    double imgHeight, {
    required bool isTablet,
    CapturedFrame? capturedFrame,
  }) {
    if (_isCapturing || _isMultiAngleCompleted) return;

    if (faces.isEmpty || faces.length > 1) {
      _updateGuidance(
        faces.isEmpty ? 'Position face inside circular ring' : 'Only 1 person allowed in frame',
        AppColors.cyanAccent,
        aligned: false,
      );
      _hasActivePointer = false;
      return;
    }

    final face = faces.first;
    _lastDetectedFace = face;

    final faceRatio = face.boundingBox.width / imgWidth;
    final minRatio = isTablet ? 0.12 : 0.16;

    if (faceRatio < minRatio) {
      _updateGuidance('Move closer to the camera', AppColors.amberWarning, aligned: false);
      return;
    }
    if (faceRatio > 0.88) {
      _updateGuidance('Move slightly back from camera', AppColors.amberWarning, aligned: false);
      return;
    }

    // 🛡️ Centering Guard
    final double centerX = face.boundingBox.center.dx / imgWidth;
    final double centerY = face.boundingBox.center.dy / imgHeight;
    if (centerX < 0.22 || centerX > 0.78 || centerY < 0.18 || centerY > 0.82) {
      _updateGuidance('Position face inside circular ring', AppColors.cyanAccent, aligned: false);
      _hasActivePointer = false;
      return;
    }

    final yaw = face.headEulerAngleY ?? 0.0;
    final pitch = face.headEulerAngleX ?? 0.0;
    final effectivePitch = isTablet ? (pitch - 11.5) : pitch;
    final dist = sqrt(yaw * yaw + effectivePitch * effectivePitch);

    bool newTicksAdded = false;

    // Center Look
    if (dist < 7.5 || (yaw.abs() <= 6.5 && (pitch >= -4.0 && pitch <= 22.0))) {
      _hasFrontLook = true;
      _hasActivePointer = false;
      for (final idx in [46, 47, 0, 1, 2]) {
        if (_completedTicks.add(idx)) newTicksAdded = true;
      }

      // Continuously evaluate and cache the sharpest dead-center frontal portrait!
      if (capturedFrame != null) {
        _evaluateAndCacheFrontalPortrait(face, capturedFrame, dist);
      }
    } else {
      // Dynamic Head Rotation Tracking around 360° Circle
      final angle = atan2(-effectivePitch, yaw);
      _currentAngleRad = angle;
      _hasActivePointer = true;

      var norm = (angle + (pi / 2)) % (2 * pi);
      if (norm < 0) norm += 2 * pi;
      final centerTick = ((norm / (2 * pi)) * _totalTicks).round() % _totalTicks;

      // Fill current tick & adjacent ticks
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

    // Dynamic Guidance based on missing head directions
    if (!_isMultiAngleCompleted) {
      if (!_hasFrontLook) {
        _updateGuidance('Look straight at the center to begin', AppColors.cyanAccent, aligned: true);
      } else if (!_hasLeftTurn) {
        _updateGuidance('Slowly turn your head to the left ⬅️', AppColors.cyanAccent, aligned: true);
      } else if (!_hasRightTurn) {
        _updateGuidance('Slowly turn your head to the right ➡️', AppColors.cyanAccent, aligned: true);
      } else {
        _updateGuidance('Rotate head smoothly to fill remaining ring ticks', AppColors.cyanAccent, aligned: true);
      }
    }

    // Completion Check: either 38+ ticks or all 3 cardinal directions completed
    if (!_isMultiAngleCompleted &&
        (_completedTicks.length >= 38 || (_hasFrontLook && _hasLeftTurn && _hasRightTurn))) {
      for (int i = 0; i < _totalTicks; i++) {
        _completedTicks.add(i);
      }
      _isMultiAngleCompleted = true;
      _hasActivePointer = false;
      HapticFeedback.mediumImpact();
      debugPrint('[KIOSK_DEBUG] 🎯 360° Scan Completed! Auto-capturing face profile...');
      _updateGuidance(
        '360° Scan Complete! Profile ready... 📸',
        AppColors.emeraldGreen,
        aligned: true,
      );
      setState(() {});

      // ⚡ Zero-lag auto-capture using cached frontal portrait!
      _captureFace(activeFace: face, capturedFrame: capturedFrame);
    }
  }

  /// 📸 Continuously scores & keeps the SHARPEST, dead-center, eyes-open frontal portrait
  void _evaluateAndCacheFrontalPortrait(Face face, CapturedFrame frame, double dist) {
    try {
      final lEye = face.leftEyeOpenProbability ?? 0.8;
      final rEye = face.rightEyeOpenProbability ?? 0.8;

      if (lEye < 0.60 || rEye < 0.60) return;

      final double score = (1.0 - (dist / 8.0).clamp(0.0, 1.0)) * 0.6 + (((lEye + rEye) / 2.0).clamp(0.0, 1.0)) * 0.4;
      if (score <= _bestFrontalScore && _cachedFrontalCrop != null) return;

      final camera = _cameras[_selectedCameraIndex];
      final isLandscape = mounted && MediaQuery.of(context).orientation == Orientation.landscape;
      final streamImg = ImageConverter.convertCapturedFrame(
        frame: frame,
        camera: camera,
        deviceOrientation: _cameraController?.value.deviceOrientation,
        screenOrientation: isLandscape ? Orientation.landscape : Orientation.portrait,
      );
      if (streamImg != null) {
        var crop = ImageConverter.cropFaceFromDecoded(
          originalImage: streamImg,
          boundingBox: face.boundingBox,
          marginFactor: 0.32,
        );
        if (crop != null) {
          if (camera.lensDirection == CameraLensDirection.front) {
            crop = img.flipHorizontal(crop);
          }
          final emb = _attendanceService.mlService.predict(crop);
          if (emb != null) {
            _bestFrontalScore = score;
            _cachedFrontalCrop = crop;
            _cachedFrontalJpgBytes = Uint8List.fromList(img.encodeJpg(crop, quality: 90));
            _cachedFrontalEmbedding = emb;
            debugPrint(
              '[KIOSK_DEBUG] 📸 360° Frontal portrait refined! Score: ${(score * 100).toStringAsFixed(1)}% | '
              'Yaw: ${(face.headEulerAngleY ?? 0.0).toStringAsFixed(1)}° | Pitch: ${(face.headEulerAngleX ?? 0.0).toStringAsFixed(1)}°',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[KIOSK_DEBUG] ⚠️ Frontal cache evaluation error: $e');
    }
  }

  // =========================================================================
  // 📸 ZERO-SHUTTER-LAG INSTANT CAPTURE & EMBEDDING
  // =========================================================================
  Future<void> _captureFace({Face? activeFace, CapturedFrame? capturedFrame}) async {
    if (_isCapturing || _capturedFaceCrop != null) return;
    _isCapturing = true;
    _autoCaptureStartTime = null;

    final attendanceService = _attendanceService;
    final camera = _cameras[_selectedCameraIndex];

    try {
      debugPrint('[KIOSK_DEBUG] 📸 Instant capturing high-quality portrait for face embedding...');

      // 🏆 Priority 1: Use cached straight frontal portrait if available from 360° scan
      if (_cachedFrontalCrop != null &&
          _cachedFrontalJpgBytes != null &&
          _cachedFrontalEmbedding != null) {
        debugPrint('[KIOSK_DEBUG] 🌟 Utilizing sharp cached frontal portrait from 360° scan!');
        _angleEmbeddings.clear();
        _angleEmbeddings.add(_cachedFrontalEmbedding!);

        setState(() {
          _capturedFaceCrop = _cachedFrontalCrop;
          _capturedFaceJpgBytes = _cachedFrontalJpgBytes;
        });

        HapticFeedback.heavyImpact();
        if (_cameraController != null && _cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream().catchError((_) {});
        }
        return;
      }

      // ⚡ Priority 2: Instant decode directly from safe native frame buffer
      final effectiveFrame = capturedFrame ?? _latestCapturedFrame;
      final targetFace = activeFace ?? _lastDetectedFace;

      if (effectiveFrame != null && targetFace != null) {
        final isLandscape = mounted && MediaQuery.of(context).orientation == Orientation.landscape;
        final decodedImage = ImageConverter.convertCapturedFrame(
          frame: effectiveFrame,
          camera: camera,
          deviceOrientation: _cameraController?.value.deviceOrientation,
          screenOrientation: isLandscape ? Orientation.landscape : Orientation.portrait,
        );

        if (decodedImage != null) {
          var cropped = ImageConverter.cropFaceFromDecoded(
            originalImage: decodedImage,
            boundingBox: targetFace.boundingBox,
            marginFactor: 0.32,
          );

          if (cropped != null) {
            if (camera.lensDirection == CameraLensDirection.front) {
              cropped = img.flipHorizontal(cropped);
            }

            final embedding = attendanceService.mlService.predict(cropped);
            if (embedding != null) {
              debugPrint('[KIOSK_DEBUG] 🎯 Instant stream frame decoded & embedded successfully!');
              final jpgBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));

              _angleEmbeddings.clear();
              _angleEmbeddings.add(embedding);

              setState(() {
                _capturedFaceCrop = cropped;
                _capturedFaceJpgBytes = jpgBytes;
              });

              HapticFeedback.heavyImpact();
              if (_cameraController != null && _cameraController!.value.isStreamingImages) {
                await _cameraController!.stopImageStream().catchError((_) {});
              }
              return;
            }
          }
        }
      }

      // 📸 Fallback: Flash photo capture
      debugPrint('[KIOSK_DEBUG] 📸 Fallback: Taking full-resolution shutter snapshot...');
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) throw Exception('Failed to decode shutter image');

      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await attendanceService.faceDetectorService.processImage(inputImage);

      if (faces.isEmpty) {
        throw Exception('No face detected in photo. Please retake.');
      }

      var cropped = ImageConverter.cropFaceFromDecoded(
        originalImage: decodedImage,
        boundingBox: faces.first.boundingBox,
        marginFactor: 0.32,
      );

      if (cropped == null) throw Exception('Failed to crop face');

      if (camera.lensDirection == CameraLensDirection.front) {
        cropped = img.flipHorizontal(cropped);
      }

      final embedding = attendanceService.mlService.predict(cropped);
      if (embedding == null) {
        throw Exception('Failed to generate facial embeddings');
      }

      final jpgBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
      _angleEmbeddings.clear();
      _angleEmbeddings.add(embedding);

      setState(() {
        _capturedFaceCrop = cropped;
        _capturedFaceJpgBytes = jpgBytes;
      });

      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('[KIOSK_DEBUG] ❌ Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.roseError,
          ),
        );
      }
      _resetScan();
      _startImageStream();
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _updateGuidance(String message, Color color, {required bool aligned}) {
    if (!mounted || _isDisposed) return;
    if (_guidanceMessage != message || _guidanceColor != color || _isFaceAligned != aligned) {
      setState(() {
        _guidanceMessage = message;
        _guidanceColor = color;
        _isFaceAligned = aligned;
      });
    }
  }

  void _resetScan() {
    setState(() {
      _capturedFaceCrop = null;
      _capturedFaceJpgBytes = null;
      _angleEmbeddings.clear();
      _isFaceAligned = false;
      _livenessVerified = false;
      _eyesWereOpen = false;
      _autoCaptureStartTime = null;
      _lastDetectedFace = null;
      _completedTicks.clear();
      _hasActivePointer = false;
      _hasFrontLook = false;
      _hasLeftTurn = false;
      _hasRightTurn = false;
      _isMultiAngleCompleted = false;
      _cachedFrontalCrop = null;
      _cachedFrontalJpgBytes = null;
      _cachedFrontalEmbedding = null;
      _bestFrontalScore = 0.0;
      _guidanceMessage = 'Position your face inside the frame';
      _guidanceColor = AppColors.cyanAccent;
    });

    _startImageStream();
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
      debugPrint('[KIOSK_DEBUG] Camera toggle error: $e');
    } finally {
      if (mounted) {
        _isSwitchingCamera = false;
      }
    }
  }

  Future<void> _submitStaffEnrollment() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both Name and Employee Code'),
          backgroundColor: AppColors.amberWarning,
        ),
      );
      return;
    }

    if (_capturedFaceCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture employee face first.'),
          backgroundColor: AppColors.amberWarning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    debugPrint('[KIOSK_DEBUG] 💾 Enrolling staff "$name" ($code) into storage...');

    try {
      final attendanceService = _attendanceService;
      final success = await attendanceService.registerStaff(
        name: name,
        employeeCode: code,
        role: _selectedRole,
        department: _selectedDepartment,
        faceImage: _capturedFaceCrop!,
        precomputedAngleEmbeddings: _angleEmbeddings,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          debugPrint('[KIOSK_DEBUG] 🎉 Staff "$name" registered successfully!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Employee "$name" enrolled successfully!'),
              backgroundColor: AppColors.emeraldGreen,
            ),
          );
          Navigator.pop(context);
        } else {
          debugPrint('[KIOSK_DEBUG] ❌ Failed to save biometric profile');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save biometric profile. Try again.'),
              backgroundColor: AppColors.roseError,
            ),
          );
          _startImageStream();
        }
      }
    } catch (e) {
      debugPrint('[KIOSK_DEBUG] ❌ Enrollment error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enrollment error: $e'),
            backgroundColor: AppColors.roseError,
          ),
        );
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
    if (oldController != null) {
      if (oldController.value.isStreamingImages) {
        oldController.stopImageStream().catchError((_) {});
      }
      oldController.dispose().catchError((e) {
        debugPrint('[KIOSK_DEBUG] Camera dispose error: $e');
      });
    }
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCaptured = _capturedFaceCrop != null && _capturedFaceJpgBytes != null;
    final bool isCamReady = !_isDisposed &&
        _isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    final isTablet = context.isTablet;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final horizontalPadding = isTablet ? 24.0 : 18.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              const PremiumBackButton(),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _useMultiAngle ? 'Face ID Enrollment (360°)' : 'Register Employee Face',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.bold,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.cyanAccent, size: 22),
                onPressed: _resetScan,
                tooltip: 'Re-scan Face',
              ),
              if (_cameras.length > 1 && !hasCaptured) ...[
                const SizedBox(width: 14),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.flip_camera_ios_outlined, color: AppColors.cyanAccent, size: 21),
                  onPressed: _toggleCamera,
                  tooltip: 'Switch Camera',
                ),
              ],
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: (isTablet && isLandscape)
            ? _buildTabletLandscapeLayout(hasCaptured, isCamReady)
            : _buildStandardLayout(hasCaptured, isCamReady, isTablet: isTablet),
      ),
    );
  }

  // =========================================================================
  // 📱 STANDARD VERTICAL LAYOUT (Mobile + Tablet Portrait)
  // =========================================================================
  Widget _buildStandardLayout(bool hasCaptured, bool isCamReady, {required bool isTablet}) {
    final bool canProceed = hasCaptured || _isReadyToCapture;

    return MobileRegisterView(
      hasCaptured: hasCaptured,
      isReadyToCapture: _isReadyToCapture,
      isTablet: isTablet,
      modeToggle: !hasCaptured ? _buildModeToggle(hasCaptured) : null,
      guidanceBanner: _buildGuidanceBanner(hasCaptured),
      viewportContent: hasCaptured
          ? _buildCapturedReviewView()
          : _buildLiveCameraView(isCamReady, isTablet: isTablet, isLandscape: false),
      actionButtons: _buildBottomActionButtons(canProceed, hasCaptured),
    );
  }

  // =========================================================================
  // 📟 TABLET LANDSCAPE SPLIT-SCREEN LAYOUT: 60% Camera : 40% Form
  // =========================================================================
  Widget _buildTabletLandscapeLayout(bool hasCaptured, bool isCamReady) {
    final bool canProceed = hasCaptured || _isReadyToCapture;

    return TabletRegisterView(
      hasCaptured: hasCaptured,
      isReadyToCapture: _isReadyToCapture,
      modeToggle: !hasCaptured ? _buildModeToggle(hasCaptured) : null,
      guidanceBanner: _buildGuidanceBanner(hasCaptured),
      viewportContent: hasCaptured
          ? _buildCapturedReviewView()
          : _buildLiveCameraView(isCamReady, isTablet: true, isLandscape: true),
      actionButtons: _buildBottomActionButtons(canProceed, hasCaptured, isTabletLandscape: true),
      formContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBiometricProfileHeader(),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Full Name
          PremiumTextField(
            controller: _nameController,
            label: 'FULL NAME',
            hintText: 'e.g. Rahul Patel',
            prefixIcon: Icons.person_outline_rounded,
            isRequired: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),

          // Employee Code
          PremiumTextField(
            controller: _codeController,
            label: 'EMPLOYEE CODE / ID',
            hintText: 'e.g. EMP-101',
            prefixIcon: Icons.badge_outlined,
            isRequired: true,
            badgeText: 'UNIQUE ID',
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),

          // Role
          PremiumDropdown<String>(
            label: 'ROLE / DESIGNATION',
            value: _selectedRole,
            items: _roles,
            itemLabel: (r) => r,
            prefixIcon: Icons.work_outline_rounded,
            isRequired: true,
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
          const SizedBox(height: 14),

          // Department
          PremiumDropdown<String>(
            label: 'DEPARTMENT',
            value: _selectedDepartment,
            items: _departments,
            itemLabel: (d) => d,
            prefixIcon: Icons.apartment_outlined,
            isRequired: true,
            onChanged: (val) {
              if (val != null) setState(() => _selectedDepartment = val);
            },
          ),
          const SizedBox(height: 22),

          // Save Button
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: hasCaptured ? AppColors.primaryGradient : null,
              color: hasCaptured ? null : AppColors.surfaceCardLight,
              borderRadius: BorderRadius.circular(14),
              boxShadow: hasCaptured
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: (_isSaving || !hasCaptured) ? null : _submitStaffEnrollment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasCaptured
                              ? Icons.how_to_reg_rounded
                              : Icons.photo_camera_outlined,
                          size: 20,
                          color: hasCaptured ? Colors.white : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasCaptured ? 'Save & Register Staff' : 'Capture Face Photo to Proceed',
                          style: TextStyle(
                            fontFamily: AppFonts.bold,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: hasCaptured ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🌟 SHARED UI WIDGETS
  // =========================================================================

  /// Smooth Sliding Pill Mode Switcher (Apple/iOS Segmented Style)
  Widget _buildModeToggle(bool hasCaptured) {
    return Container(
      height: 46,
      width: double.infinity,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Stack(
        children: [
          // 🌊 Smooth Sliding Indicator Pill
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: _useMultiAngle ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Two Interactive Labels
          Row(
            children: [
              // ⚡ Option 1: Quick Blink (Standard)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasCaptured ? null : () => _setEnrollmentMode(false),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: !_useMultiAngle ? Colors.white : AppColors.textSecondary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: !_useMultiAngle ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          const Text('Quick Blink'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 🔄 Option 2: 360° Face ID
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasCaptured ? null : () => _setEnrollmentMode(true),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _useMultiAngle ? Colors.white : AppColors.textSecondary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            size: 16,
                            color: _useMultiAngle ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          const Text('360° Face ID'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Perfectly Aligned & Centered Guidance Banner
  Widget _buildGuidanceBanner(bool hasCaptured) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _guidanceColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4.5),
            decoration: BoxDecoration(
              color: _guidanceColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasCaptured || _isReadyToCapture
                  ? Icons.check_circle_rounded
                  : (_isFaceAligned ? Icons.visibility_rounded : Icons.info_outline_rounded),
              color: _guidanceColor,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              hasCaptured ? 'Face enrolled! Proceed to staff details' : _guidanceMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.bold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _guidanceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Live Camera Viewport with orientation-aware aspect ratio & scaled viewfinders
  Widget _buildLiveCameraView(bool isCamReady, {required bool isTablet, required bool isLandscape}) {
    if (!isCamReady) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.cyanAccent),
      );
    }

    final previewSize = _cameraController!.value.previewSize;
    final double rawW = (previewSize?.width ?? 1280).toDouble();
    final double rawH = (previewSize?.height ?? 720).toDouble();

    // In landscape orientation (horizontal tablet), use raw width > height.
    // In portrait orientation (phones / vertical tablet), use swapped height > width.
    final double previewW = isLandscape ? rawW : rawH;
    final double previewH = isLandscape ? rawH : rawW;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera Preview Feed
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: previewW,
              height: previewH,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),

        // Viewfinder HUD Presentation
        if (_useMultiAngle) ...[
          // Apple Face ID 360° Circular Radial Ring (Scales on Tablet)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final ringSize = isTablet ? 360.0 : 280.0;
              return CustomPaint(
                size: Size(ringSize, ringSize),
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
          if (_isMultiAngleCompleted)
            Positioned(
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.emeraldGreen, width: 1.5),
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.emeraldGreen, size: 16),
                    SizedBox(width: 6),
                    Text(
                      '360° Profile Complete',
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        color: AppColors.emeraldGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ] else ...[
          // Quick Blink Biometric Oval HUD (Scales on Tablet)
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
                    customWidth: isTablet ? 330.0 : null,
                    customHeight: isTablet ? 420.0 : null,
                  ),
                );
              },
            ),
          ),
          if (_isReadyToCapture)
            Positioned(
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.emeraldGreen, width: 1.5),
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.emeraldGreen, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Real Human Verified',
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        color: AppColors.emeraldGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// Captured Face Photo Review View
  Widget _buildCapturedReviewView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.surface,
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.emeraldGreen, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _useMultiAngle ? '360° Biometric Profile' : 'Quick Blink Profile Ready',
                        style: const TextStyle(
                          fontFamily: AppFonts.bold,
                          color: AppColors.emeraldGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 135,
                      height: 135,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.emeraldGreen, width: 3.0),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldGreen.withValues(alpha: 0.30),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: Image.memory(
                          _capturedFaceJpgBytes!,
                          fit: BoxFit.cover,
                          width: 125,
                          height: 125,
                        ),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.emeraldGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text(
                  'Face Enrolled Successfully',
                  style: TextStyle(
                    fontFamily: AppFonts.bold,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.30)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, color: AppColors.emeraldGreen, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'Quality: Excellent',
                            style: TextStyle(
                              fontFamily: AppFonts.bold,
                              fontSize: 11,
                              color: AppColors.emeraldGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: AppColors.cyanAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.30)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hd_outlined, color: AppColors.cyanAccent, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'High Definition',
                            style: TextStyle(
                              fontFamily: AppFonts.bold,
                              fontSize: 11,
                              color: AppColors.cyanAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom Shutter & Action Buttons
  Widget _buildBottomActionButtons(bool canProceed, bool hasCaptured, {bool isTabletLandscape = false}) {
    // 📟 Tablet Landscape Mode: Form is ALREADY open on the right pane!
    if (isTabletLandscape) {
      if (hasCaptured) {
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _resetScan,
            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.cyanAccent),
            label: const Text(
              'Retake Face Photo',
              style: TextStyle(
                fontFamily: AppFonts.bold,
                color: AppColors.cyanAccent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.cyanAccent, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      } else {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: canProceed ? () => _captureFace() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed ? AppColors.primary : AppColors.surfaceCardLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: canProceed ? 2 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isReadyToCapture
                      ? Icons.camera_alt_rounded
                      : (_useMultiAngle ? Icons.radar_rounded : Icons.face_rounded),
                  color: canProceed ? Colors.white : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _useMultiAngle
                      ? (_isMultiAngleCompleted ? 'Face Verified (Auto-Capturing)' : 'Rotate Head 360° to Complete')
                      : (_isReadyToCapture
                          ? 'Face Verified (Auto-Capturing)'
                          : (_livenessVerified ? 'Look Directly at Camera' : 'Blink Eyes to Auto-Capture')),
                  style: TextStyle(
                    fontFamily: AppFonts.bold,
                    color: canProceed ? Colors.white : AppColors.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 📱 Mobile / Tablet Portrait Mode: Open details sheet when proceed button clicked
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: canProceed
                ? (hasCaptured
                    ? () => _showDetailsSheet(_capturedFaceCrop!)
                    : () => _captureFace())
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed ? AppColors.primary : AppColors.surfaceCardLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: canProceed ? 2 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasCaptured
                      ? Icons.arrow_forward_rounded
                      : (_isReadyToCapture
                          ? Icons.camera_alt_rounded
                          : (_useMultiAngle ? Icons.radar_rounded : Icons.face_rounded)),
                  color: canProceed ? Colors.white : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  hasCaptured
                      ? 'Continue to Staff Details'
                      : (_useMultiAngle
                          ? (_isMultiAngleCompleted ? 'Face Verified (Auto-Capturing)' : 'Rotate Head 360° to Complete')
                          : (_isReadyToCapture
                              ? 'Face Verified (Auto-Capturing)'
                              : (_livenessVerified ? 'Look Directly at Camera' : 'Blink Eyes to Auto-Capture'))),
                  style: TextStyle(
                    fontFamily: AppFonts.bold,
                    color: canProceed ? Colors.white : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasCaptured) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _resetScan,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.cyanAccent),
              label: const Text(
                'Retake Photo',
                style: TextStyle(
                  fontFamily: AppFonts.bold,
                  color: AppColors.cyanAccent,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.cyanAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Profile Summary Card in Header
  Widget _buildBiometricProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.emeraldGreen.withValues(alpha: 0.30),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.emeraldGreen, width: 2),
            ),
            padding: const EdgeInsets.all(2.0),
            child: ClipOval(
              child: _capturedFaceJpgBytes != null
                  ? Image.memory(_capturedFaceJpgBytes!, fit: BoxFit.cover)
                  : const Icon(Icons.person, color: AppColors.cyanAccent, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Biometric Profile',
                  style: TextStyle(
                    fontFamily: AppFonts.bold,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _useMultiAngle
                      ? '360° Face ID profile enrolled successfully'
                      : 'Face profile enrolled successfully',
                  style: const TextStyle(
                    fontFamily: AppFonts.medium,
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Staff Details Modal Bottom Sheet (Mobile & Tablet Portrait Mode)
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
            final double bottomSpacing = max(keyboardHeight, systemNavHeight) + 14.0;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * 0.90,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 18,
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
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Biometric Profile Header Card
                      _buildBiometricProfileHeader(),
                      const SizedBox(height: 16),

                      // Full Name Field
                      PremiumTextField(
                        controller: _nameController,
                        label: 'FULL NAME',
                        hintText: 'e.g. Rahul Patel',
                        prefixIcon: Icons.person_outline_rounded,
                        isRequired: true,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),

                      // Employee Code Field
                      PremiumTextField(
                        controller: _codeController,
                        label: 'EMPLOYEE CODE / ID',
                        hintText: 'e.g. EMP-101',
                        prefixIcon: Icons.badge_outlined,
                        isRequired: true,
                        badgeText: 'UNIQUE ID',
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 14),

                      // Role Dropdown
                      PremiumDropdown<String>(
                        label: 'ROLE / DESIGNATION',
                        value: _selectedRole,
                        items: _roles,
                        itemLabel: (r) => r,
                        prefixIcon: Icons.work_outline_rounded,
                        isRequired: true,
                        onChanged: (val) {
                          if (val != null) setSheetState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Department Dropdown
                      PremiumDropdown<String>(
                        label: 'DEPARTMENT',
                        value: _selectedDepartment,
                        items: _departments,
                        itemLabel: (d) => d,
                        prefixIcon: Icons.apartment_outlined,
                        isRequired: true,
                        onChanged: (val) {
                          if (val != null) setSheetState(() => _selectedDepartment = val);
                        },
                      ),
                      const SizedBox(height: 22),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _submitStaffEnrollment();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.how_to_reg_rounded, size: 20, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Save & Register Staff',
                                style: TextStyle(
                                  fontFamily: AppFonts.bold,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
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
  }
}
