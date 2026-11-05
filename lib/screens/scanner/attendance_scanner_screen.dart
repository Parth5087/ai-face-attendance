import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/attendance_record.dart';
import '../../services/attendance_service.dart';
import '../../utils/image_converter.dart';
import '../../core/responsive.dart';
import '../../widgets/attendance_success_dialog.dart';
import '../../widgets/attendance_unrecognized_dialog.dart';
import '../../widgets/premium_confirmation_dialog.dart';
import 'views/mobile_scanner_view.dart';
import 'views/tablet_scanner_view.dart';

class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({super.key});

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AttendanceService get _attendanceService {
    try {
      return context.read<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
  }

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isVerifying = false;
  bool _isDisposed = false;
  bool _isSwitchingCamera = false;

  // Liveness & Blink state
  bool _eyesWereOpen = false;
  bool _blinkDetected = false;
  DateTime? _lastBlinkTime;

  String _statusText = 'Looking for employee face...';
  Color _statusColor = AppColors.cyanAccent;
  String _checkType = 'IN';

  late AnimationController _scannerAnimController;
  late Animation<double> _scannerAnimation;
  Timer? _kioskClockTimer;
  DateTime _currentKioskTime = DateTime.now();

  AttendanceRecord? _lastPunchResult;
  bool _lastPunchIsAlreadyCheckedIn = false;
  bool _lastPunchIsAlreadyCheckedOut = false;
  bool _lastPunchNoCheckIn = false;
  String? _lastPunchCandidateName;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔒 Lock orientation dynamically: Portrait for Mobile, Landscape for Tablet Kiosk
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.isTablet) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });

    // Smart local-time preset: morning -> CHECK-IN, afternoon/evening -> CHECK-OUT
    final currentHour = DateTime.now().hour;
    _checkType = currentHour >= 13 ? 'OUT' : 'IN';
    _statusText = _checkType == 'IN' ? 'Looking for employee face...' : 'Ready for Check-Out...';
    _statusColor = _checkType == 'IN' ? AppColors.cyanAccent : const Color(0xFFF59E0B);

    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerAnimController, curve: Curves.easeInOut),
    );

    _kioskClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentKioskTime = DateTime.now();
        });
      }
    });

    if (!_attendanceService.isReady) {
      _attendanceService.initialize().catchError((e) {
        debugPrint('[SCANNER] AttendanceService init error: $e');
      });
    }

    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isShowingDialog && ModalRoute.of(context)?.isCurrent == true) {
        _initCamera();
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (!mounted || _isDisposed) return;
      if (_cameras.isEmpty) {
        setState(() => _statusText = 'No camera found on device');
        return;
      }

      // Default to front camera
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _setupCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      if (!mounted || _isDisposed) return;
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

        // Explicitly turn off flash to prevent iOS native Retina Screen Flash
        await controller.setFlashMode(FlashMode.off).catchError((_) {});

        setState(() {
          _cameraController = controller;
          _isCameraInitialized = true;
        });

        _startImageStream();
        return;
      } catch (e) {
        debugPrint('Camera setup attempt $attempt error: $e');
        await controller.dispose().catchError((_) {});
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }
  }

  void _startImageStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isDisposed) {
      return;
    }
    if (_cameraController!.value.isStreamingImages) return;

    final attendanceService = _attendanceService;
    final faceDetector = attendanceService.faceDetectorService;

    try {
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isProcessingFrame ||
            _isVerifying ||
            _isShowingDialog ||
            _lastPunchResult != null ||
            _isDisposed) {
          return;
        }
        _isProcessingFrame = true;

        // 🛡️ Synchronously clone native camera planes into pure Dart memory buffer
        final safeFrame = CapturedFrame.fromCameraImage(image);

        try {
          final isLandscape = mounted && MediaQuery.of(context).orientation == Orientation.landscape;
          final isTabletDevice = mounted && context.isTablet;

          final inputImage = ImageConverter.toInputImage(
            cameraImage: image,
            camera: _cameras[_selectedCameraIndex],
            deviceOrientation: _cameraController?.value.deviceOrientation,
            screenOrientation: isLandscape ? Orientation.landscape : Orientation.portrait,
          );

          if (inputImage != null) {
            final faces = await faceDetector.processImage(inputImage);
            if (!mounted || _isDisposed) return;

            if (faces.isEmpty) {
              _updateStatus('Looking for employee face...', AppColors.cyanAccent);
              _blinkDetected = false;
              _eyesWereOpen = false;
            } else if (faces.length > 1) {
              _updateStatus(
                'Multiple faces detected. Please scan one by one.',
                AppColors.amberWarning,
              );
              _blinkDetected = false;
              _eyesWereOpen = false;
            } else {
              final face = faces.first;
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

              // 1. Geometry & Angle Evaluation
              final validation = faceDetector.validateFaceGeometry(
                face: face,
                imageWidth: actualWidth,
                imageHeight: actualHeight,
                isTablet: isTabletDevice,
              );

              if (!validation.isValid) {
                _updateStatus(
                  validation.message,
                  (validation.isTooSmall || !validation.isCentered) ? AppColors.amberWarning : AppColors.roseError,
                );
                _blinkDetected = false;
                _eyesWereOpen = false;
                return;
              }

              // 2. Active Blink / Liveness Verification inside Guide
              if (!_blinkDetected) {
                if (validation.isEyesOpen) {
                  _eyesWereOpen = true;
                  _updateStatus(
                    'Face aligned! Please blink naturally 😉',
                    AppColors.amberWarning,
                  );
                }

                if (_eyesWereOpen && validation.isBlinking) {
                  _blinkDetected = true;
                  _lastBlinkTime = DateTime.now();
                  _updateStatus('Blink verified! Hold still with eyes open... 📸', AppColors.emeraldGreen);
                  HapticFeedback.lightImpact();

                  debugPrint(
                    '[SCANNER_DEBUG] 🎯 Live blink verified! '
                    'Size=${(validation.faceRatio * 100).toInt()}% | '
                    'Yaw=${validation.yaw?.toStringAsFixed(1)}° | '
                    'Pitch=${validation.pitch?.toStringAsFixed(1)}°',
                  );
                }
              } else {
                // Blink verified! Wait for eyes open for crisp snapshot
                if (_lastBlinkTime != null &&
                    DateTime.now().difference(_lastBlinkTime!).inSeconds > 4) {
                  // Timed out, reset
                  _blinkDetected = false;
                  _eyesWereOpen = false;
                } else if (validation.isEyesOpen && !_isVerifying) {
                  _updateStatus('Matching face profile...', AppColors.emeraldGreen);
                  await _verifyAndPunch(face: face, frame: safeFrame);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Frame processing error: $e');
        } finally {
          _isProcessingFrame = false;
        }
      });
    } catch (e) {
      debugPrint('Stream start error: $e');
    }
  }

  Future<void> _verifyAndPunch({
    required Face face,
    required CapturedFrame frame,
  }) async {
    if (_isVerifying || _isShowingDialog || _lastPunchResult != null) return;
    _isVerifying = true;

    final attendanceService = _attendanceService;

    try {
      img.Image? cropped;

      // 1. Convert fast stream frame
      final camera = _cameras[_selectedCameraIndex];
      final isLandscape = mounted && MediaQuery.of(context).orientation == Orientation.landscape;

      final streamImage = ImageConverter.convertCapturedFrame(
        frame: frame,
        camera: camera,
        deviceOrientation: _cameraController?.value.deviceOrientation,
        screenOrientation: isLandscape ? Orientation.landscape : Orientation.portrait,
      );

      if (streamImage != null) {
        debugPrint(
          '[SCANNER_DEBUG] ⚡ Converted stream frame directly (${streamImage.width}x${streamImage.height}) - ZERO SHUTTER SOUND',
        );
        cropped = ImageConverter.cropFaceFromDecoded(
          originalImage: streamImage,
          boundingBox: face.boundingBox,
          marginFactor: 0.32,
        );
      }

      // 2. Fallback to takePicture if frame conversion failed
      if (cropped == null) {
        debugPrint('[SCANNER_DEBUG] 🔄 Fallback: capturing photo...');
        await _cameraController?.stopImageStream();
        await _cameraController?.setFlashMode(FlashMode.off).catchError((_) {});

        final xFile = await _cameraController?.takePicture();
        if (xFile != null) {
          final fullImage = await ImageConverter.decodeOrientedImage(xFile);
          if (fullImage != null) {
            final photoInput = InputImage.fromFilePath(xFile.path);
            final photoFaces = await attendanceService.faceDetectorService.processImage(photoInput);
            final activeFaceBox = photoFaces.isNotEmpty
                ? photoFaces.first.boundingBox
                : face.boundingBox;

            // Anti-Spoofing Check
            attendanceService.antiSpoofingService.checkLiveness(
              fullImage: fullImage,
              faceX: activeFaceBox.left.toInt(),
              faceY: activeFaceBox.top.toInt(),
              faceWidth: activeFaceBox.width.toInt(),
              faceHeight: activeFaceBox.height.toInt(),
            );

            cropped = ImageConverter.cropFaceFromDecoded(
              originalImage: fullImage,
              boundingBox: activeFaceBox,
              marginFactor: 0.32,
            );
          }
        }
      }

      if (cropped != null) {
        if (!mounted) return;

        // Front camera horizontal flip
        if (camera.lensDirection == CameraLensDirection.front) {
          cropped = img.flipHorizontal(cropped);
        }

        final punchResult = await attendanceService.punchAttendance(
          faceImage: cropped,
          checkType: _checkType,
        );

        if (!mounted) return;

        if (punchResult.isSuccess && punchResult.record != null) {
          debugPrint(
            '[SCANNER_DEBUG] ✅ SUCCESS! $_checkType recorded for "${punchResult.record!.employeeName}" '
            '(${punchResult.record!.employeeCode})',
          );
          HapticFeedback.heavyImpact();

          if (context.isTablet) {
            setState(() {
              _lastPunchResult = punchResult.record;
              _lastPunchIsAlreadyCheckedIn = false;
              _lastPunchIsAlreadyCheckedOut = false;
              _lastPunchNoCheckIn = false;
              _lastPunchCandidateName = null;
              _statusText = 'Verified: ${punchResult.record!.employeeName}';
              _statusColor = AppColors.emeraldGreen;
            });
            _scheduleClearKioskResult();
          } else {
            _showSuccessDialog(punchResult.record!, isAlreadyCheckedIn: false);
          }
        } else if (punchResult.isAlreadyCheckedIn && punchResult.record != null) {
          debugPrint(
            '[SCANNER_DEBUG] ℹ️ Already checked in today: "${punchResult.record!.employeeName}"',
          );
          HapticFeedback.mediumImpact();

          if (context.isTablet) {
            setState(() {
              _lastPunchResult = punchResult.record;
              _lastPunchIsAlreadyCheckedIn = true;
              _lastPunchIsAlreadyCheckedOut = false;
              _lastPunchNoCheckIn = false;
              _lastPunchCandidateName = null;
              _statusText = 'Already Checked-in: ${punchResult.record!.employeeName}';
              _statusColor = AppColors.cyanAccent;
            });
            _scheduleClearKioskResult();
          } else {
            _showSuccessDialog(punchResult.record!, isAlreadyCheckedIn: true);
          }
        } else if (punchResult.isAlreadyCheckedOut && punchResult.record != null) {
          debugPrint(
            '[SCANNER_DEBUG] ℹ️ Already checked out today: "${punchResult.record!.employeeName}"',
          );
          HapticFeedback.mediumImpact();

          if (context.isTablet) {
            setState(() {
              _lastPunchResult = punchResult.record;
              _lastPunchIsAlreadyCheckedIn = false;
              _lastPunchIsAlreadyCheckedOut = true;
              _lastPunchNoCheckIn = false;
              _lastPunchCandidateName = null;
              _statusText = 'Already Checked-out: ${punchResult.record!.employeeName}';
              _statusColor = const Color(0xFFEA580C);
            });
            _scheduleClearKioskResult();
          } else {
            _showSuccessDialog(punchResult.record!, isAlreadyCheckedIn: true);
          }
        } else if (punchResult.isNoCheckInFound) {
          debugPrint(
            '[SCANNER_DEBUG] ⚠️ Check-Out rejected: No check-in found today for "${punchResult.user?.name}"',
          );
          HapticFeedback.vibrate();

          setState(() {
            _lastPunchResult = null;
            _lastPunchIsAlreadyCheckedIn = false;
            _lastPunchIsAlreadyCheckedOut = false;
            _lastPunchNoCheckIn = true;
            _lastPunchCandidateName = punchResult.user?.name;
            _statusText = 'Check-in required first!';
            _statusColor = AppColors.amberWarning;
          });
          _scheduleClearKioskResult();
        } else if (punchResult.isCooldown) {
          debugPrint('[SCANNER_DEBUG] ⏳ Cooldown active, skipping UI popup');
        } else {
          debugPrint(
            '[SCANNER_DEBUG] ❌ Unrecognized face. Confidence: ${((punchResult.confidenceScore) * 100).toStringAsFixed(1)}%',
          );
          _showUnrecognizedDialog(
            closestSimilarity: punchResult.confidenceScore,
            closestCandidateName: punchResult.user?.name,
          );
        }
      }
    } catch (e) {
      debugPrint('[SCANNER_DEBUG] Verification error: $e');
    } finally {
      _isVerifying = false;
    }
  }

  void _scheduleClearKioskResult() {
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && !_isDisposed) {
        setState(() {
          _lastPunchResult = null;
          _lastPunchIsAlreadyCheckedIn = false;
          _lastPunchIsAlreadyCheckedOut = false;
          _lastPunchNoCheckIn = false;
          _lastPunchCandidateName = null;
          _blinkDetected = false;
          _eyesWereOpen = false;
          _statusText = _checkType == 'IN'
              ? 'Looking for employee face...'
              : 'Ready for Check-Out...';
          _statusColor = _checkType == 'IN' ? AppColors.cyanAccent : const Color(0xFFF59E0B);
        });
      }
    });
  }

  void _showSuccessDialog(AttendanceRecord record, {required bool isAlreadyCheckedIn}) {
    _isShowingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        return AttendanceSuccessDialog(
          record: record,
          isAlreadyCheckedIn: isAlreadyCheckedIn,
          onDismiss: () {
            if (Navigator.canPop(ctx)) {
              Navigator.pop(ctx);
            }
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isShowingDialog = false;
          _blinkDetected = false;
          _eyesWereOpen = false;
          _statusText = _checkType == 'IN'
              ? 'Looking for employee face...'
              : 'Ready for Check-Out...';
          _statusColor = _checkType == 'IN' ? AppColors.cyanAccent : const Color(0xFFF59E0B);
        });
        _startImageStream();
      }
    });
  }

  void _showUnrecognizedDialog({
    double? closestSimilarity,
    String? closestCandidateName,
  }) {
    _isShowingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        return AttendanceUnrecognizedDialog(
          closestSimilarity: closestSimilarity,
          closestCandidateName: closestCandidateName,
          onDismiss: () {
            if (Navigator.canPop(ctx)) {
              Navigator.pop(ctx);
            }
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isShowingDialog = false;
          _blinkDetected = false;
          _eyesWereOpen = false;
          _statusText = _checkType == 'IN'
              ? 'Looking for employee face...'
              : 'Ready for Check-Out...';
          _statusColor = _checkType == 'IN' ? AppColors.cyanAccent : const Color(0xFFF59E0B);
        });
        _startImageStream();
      }
    });
  }

  void _updateStatus(String text, Color color) {
    if (!mounted || _isShowingDialog || _lastPunchResult != null) return;
    if (_statusText != text || _statusColor != color) {
      setState(() {
        _statusText = text;
        _statusColor = color;
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
      await _setupCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Camera switch error: $e');
    } finally {
      if (mounted) {
        _isSwitchingCamera = false;
      }
    }
  }

  void _disposeCamera() {
    _isCameraInitialized = false;
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream().catchError((_) {});
      }
      controller.dispose().catchError((_) {});
    }
  }

  void _onSwitchCheckType(String newType) {
    if (_checkType != newType) {
      setState(() {
        _checkType = newType;
        _statusText = _checkType == 'IN'
            ? 'Looking for employee face...'
            : 'Ready for Check-Out...';
        _statusColor = _checkType == 'IN' ? AppColors.cyanAccent : const Color(0xFFF59E0B);
        _lastPunchResult = null;
        _lastPunchIsAlreadyCheckedIn = false;
        _lastPunchIsAlreadyCheckedOut = false;
        _lastPunchNoCheckIn = false;
        _lastPunchCandidateName = null;
        _blinkDetected = false;
        _eyesWereOpen = false;
      });
    }
  }

  Future<void> _handleExit(BuildContext context) async {
    final confirmed = await PremiumConfirmationDialog.show(
      context: context,
      title: 'Exit Attendance Kiosk?',
      message: 'Are you sure you want to exit the attendance terminal and return to the Dashboard?',
      confirmText: 'Exit to Dashboard',
      cancelText: 'Resume Attendance',
      icon: Icons.exit_to_app_rounded,
      iconColor: AppColors.roseError,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      await AttendanceService.instance.setKioskModeActive(false);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _kioskClockTimer?.cancel();
    _scannerAnimController.dispose();
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCamReady = !_isDisposed &&
        _isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    final isTablet = context.isTablet;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleExit(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: isTablet
            ? TabletScannerView(
                cameraController: _cameraController,
                isCamReady: isCamReady,
                scannerAnimation: _scannerAnimation,
                currentKioskTime: _currentKioskTime,
                checkType: _checkType,
                isVerifying: _isVerifying,
                lastPunchResult: _lastPunchResult,
                lastPunchIsAlreadyCheckedIn: _lastPunchIsAlreadyCheckedIn,
                lastPunchIsAlreadyCheckedOut: _lastPunchIsAlreadyCheckedOut,
                lastPunchNoCheckIn: _lastPunchNoCheckIn,
                lastPunchCandidateName: _lastPunchCandidateName,
                blinkDetected: _blinkDetected,
                statusColor: _statusColor,
                statusText: _statusText,
                attendanceService: _attendanceService,
                canSwitchCamera: _cameras.length > 1,
                onExit: () => _handleExit(context),
                onToggleCamera: _toggleCamera,
                onSwitchCheckType: _onSwitchCheckType,
              )
            : MobileScannerView(
                cameraController: _cameraController,
                isCamReady: isCamReady,
                scannerAnimation: _scannerAnimation,
                checkType: _checkType,
                isVerifying: _isVerifying,
                lastPunchResult: _lastPunchResult,
                lastPunchIsAlreadyCheckedIn: _lastPunchIsAlreadyCheckedIn,
                lastPunchIsAlreadyCheckedOut: _lastPunchIsAlreadyCheckedOut,
                lastPunchNoCheckIn: _lastPunchNoCheckIn,
                lastPunchCandidateName: _lastPunchCandidateName,
                blinkDetected: _blinkDetected,
                statusColor: _statusColor,
                statusText: _statusText,
                attendanceService: _attendanceService,
                canSwitchCamera: _cameras.length > 1,
                onExit: () => _handleExit(context),
                onToggleCamera: _toggleCamera,
                onSwitchCheckType: _onSwitchCheckType,
              ),
      ),
    );
  }
}
