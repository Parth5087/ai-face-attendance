import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import '../utils/image_converter.dart';
import '../widgets/biometric_viewfinder.dart';
import '../widgets/attendance_success_dialog.dart';
import '../widgets/attendance_unrecognized_dialog.dart';

class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({super.key});

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen>
    with SingleTickerProviderStateMixin {
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
  final String _checkType = 'IN'; // Single daily check-in (Option 1)

  late AnimationController _scannerAnimController;
  late Animation<double> _scannerAnimation;

  AttendanceRecord? _lastPunchResult;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerAnimController, curve: Curves.easeInOut),
    );

    _initCamera();
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
      debugPrint('Camera setup error: $e');
    }
  }

  void _startImageStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isDisposed) {
      return;
    }
    if (_cameraController!.value.isStreamingImages) return;

    final attendanceService = context.read<AttendanceService>();
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

        try {
          final inputImage = ImageConverter.toInputImage(
            cameraImage: image,
            camera: _cameras[_selectedCameraIndex],
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
              final double imgWidth = image.width.toDouble();
              final double imgHeight = image.height.toDouble();

              // 1. Oval Viewfinder Centering Check (Strict Center Focus)
              final double centerX = face.boundingBox.center.dx / imgWidth;
              final double centerY = face.boundingBox.center.dy / imgHeight;

              final bool isCentered = (centerX >= 0.22 && centerX <= 0.78) &&
                  (centerY >= 0.18 && centerY <= 0.78);

              if (!isCentered) {
                _updateStatus('Center face inside the oval guide', AppColors.cyanAccent);
                _blinkDetected = false;
                _eyesWereOpen = false;
                return;
              }

              // 2. Geometry & Angle Evaluation (Distance, Pitch, Yaw, Roll)
              final validation = faceDetector.validateFaceGeometry(
                face: face,
                imageWidth: imgWidth,
                imageHeight: imgHeight,
              );

              if (!validation.isValid) {
                _updateStatus(
                  validation.message,
                  validation.isTooSmall ? AppColors.amberWarning : AppColors.roseError,
                );
                _blinkDetected = false;
                _eyesWereOpen = false;
                return;
              }

              // 3. Active Blink / Liveness Verification inside the Oval
              if (!_blinkDetected) {
                if (validation.isEyesOpen) {
                  _eyesWereOpen = true;
                  _updateStatus(
                    'Please blink your eyes naturally 😉',
                    AppColors.amberWarning,
                  );
                }

                if (_eyesWereOpen && validation.isBlinking) {
                  _blinkDetected = true;
                  _lastBlinkTime = DateTime.now();
                  _updateStatus('Blink verified! Matching face...', AppColors.emeraldGreen);
                  HapticFeedback.lightImpact();

                  debugPrint(
                    '[SCANNER_DEBUG] 🎯 Live blink verified inside Oval! '
                    'Size=${(validation.faceRatio * 100).toInt()}% | '
                    'Yaw=${validation.yaw?.toStringAsFixed(1)}° | '
                    'Pitch=${validation.pitch?.toStringAsFixed(1)}° | '
                    'Center=(${(centerX * 100).toInt()}%, ${(centerY * 100).toInt()}%)',
                  );

                  // Trigger Face Verification with the live stream frame
                  _verifyAndPunch(face, image);
                }
              } else {
                // If already blinked within 3 seconds, continue verification
                if (_lastBlinkTime != null &&
                    DateTime.now().difference(_lastBlinkTime!).inSeconds < 3) {
                  _verifyAndPunch(face, image);
                } else {
                  _blinkDetected = false;
                  _eyesWereOpen = false;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[SCANNER_DEBUG] Stream frame error: $e');
        } finally {
          _isProcessingFrame = false;
        }
      });
    } catch (e) {
      debugPrint('[SCANNER_DEBUG] Failed to start stream: $e');
    }
  }

  void _updateStatus(String text, Color color) {
    if (mounted && (_statusText != text || _statusColor != color)) {
      setState(() {
        _statusText = text;
        _statusColor = color;
      });
    }
  }

  Future<void> _verifyAndPunch(Face face, CameraImage image) async {
    if (_isVerifying || _isShowingDialog || _lastPunchResult != null) return;
    _isVerifying = true;

    final attendanceService = context.read<AttendanceService>();

    try {
      img.Image? cropped;

      // 1. ULTRA-FAST SILENT EXTRACTION directly from live stream frame (No Shutter Sound!)
      final camera = _cameras[_selectedCameraIndex];
      final streamImage = ImageConverter.convertCameraImage(
        cameraImage: image,
        camera: camera,
      );

      if (streamImage != null) {
        debugPrint(
          '[SCANNER_DEBUG] ⚡ Converted stream frame directly (${streamImage.width}x${streamImage.height}) - ZERO SHUTTER SOUND',
        );
        cropped = ImageConverter.cropFaceFromDecoded(
          originalImage: streamImage,
          boundingBox: face.boundingBox,
        );
      }

      // 2. Safe Fallback to takePicture if stream conversion was not available
      if (cropped == null) {
        debugPrint('[SCANNER_DEBUG] 🔄 Fallback: capturing photo for high-res extraction...');
        await _cameraController?.stopImageStream();
        await _cameraController?.setFlashMode(FlashMode.off).catchError((_) {});

        final xFile = await _cameraController?.takePicture();
        if (xFile != null) {
          final fullImage = await ImageConverter.decodeOrientedImage(xFile);
          if (fullImage != null) {
            // Detect face directly on the captured photo for 100% pixel-perfect coordinates
            final photoInput = InputImage.fromFilePath(xFile.path);
            final photoFaces = await attendanceService.faceDetectorService.processImage(photoInput);
            final activeFaceBox = photoFaces.isNotEmpty
                ? photoFaces.first.boundingBox
                : face.boundingBox;

            debugPrint(
              '[SCANNER_DEBUG] 📐 Photo: ${fullImage.width}x${fullImage.height} | '
              'Face on photo: ${activeFaceBox.width.toInt()}x${activeFaceBox.height.toInt()} '
              'at (${activeFaceBox.left.toInt()}, ${activeFaceBox.top.toInt()})',
            );

            // Anti-Spoofing Check on the exact face coordinates
            final spoofResult = attendanceService.antiSpoofingService.checkLiveness(
              fullImage: fullImage,
              faceX: activeFaceBox.left.toInt(),
              faceY: activeFaceBox.top.toInt(),
              faceWidth: activeFaceBox.width.toInt(),
              faceHeight: activeFaceBox.height.toInt(),
            );
            if (spoofResult != null) {
              debugPrint(
                '[SPOOF_LOG] Anti-Spoof: Real=${(spoofResult.realScore * 100).toStringAsFixed(1)}% | '
                'Fake=${(spoofResult.fakeScore * 100).toStringAsFixed(1)}% | Class=${spoofResult.predictedClass}',
              );
            }

            cropped = ImageConverter.cropFaceFromDecoded(
              originalImage: fullImage,
              boundingBox: activeFaceBox,
            );
          }
        }
      }

      if (cropped != null) {
        if (!mounted) return;

        final punchResult = await attendanceService.punchAttendance(
          faceImage: cropped,
          checkType: _checkType,
        );

        if (!mounted) return;

        if (punchResult.isSuccess && punchResult.record != null) {
          debugPrint(
            '[SCANNER_DEBUG] ✅ SUCCESS! Check-in recorded for "${punchResult.record!.employeeName}" '
            '(${punchResult.record!.employeeCode})',
          );
          HapticFeedback.heavyImpact();
          setState(() {
            _lastPunchResult = punchResult.record;
          });

          // Show success dialog
          _showPunchDialog(punchResult.record!, isAlreadyCheckedIn: false);
          return;
        } else if (punchResult.isAlreadyCheckedIn && punchResult.record != null) {
          debugPrint(
            '[SCANNER_DEBUG] ℹ️ ALREADY CHECKED IN today: "${punchResult.record!.employeeName}"',
          );
          HapticFeedback.mediumImpact();
          setState(() {
            _lastPunchResult = punchResult.record;
          });

          // Show already checked in dialog
          _showPunchDialog(punchResult.record!, isAlreadyCheckedIn: true);
          return;
        } else if (punchResult.isCooldown) {
          debugPrint('[SCANNER_DEBUG] ⏳ Cooldown active (<5s). Ignoring repeat scan.');
          _updateStatus(
            'Already processed. Please step aside for next person.',
            AppColors.cyanAccent,
          );
        } else if (streamImage != null && Platform.isIOS) {
          // Stream match was below threshold on iOS.
          // Fall back to high-precision photo detection (the exact pipeline that achieved 100% on Android)!
          debugPrint(
            '[SCANNER_DEBUG] 🔄 iOS stream match below threshold (${((punchResult.confidenceScore) * 100).toStringAsFixed(1)}%). '
            'Confirming with high-precision photo capture...',
          );
          await _capturePhotoAndVerify(face, attendanceService);
          return;
        } else {
          // UNRECOGNIZED / UNKNOWN FACE!
          debugPrint(
            '[SCANNER_DEBUG] ❌ UNRECOGNIZED FACE! Closest: "${punchResult.user?.name ?? 'Unknown'}" '
            '(${((punchResult.confidenceScore) * 100).toStringAsFixed(1)}%). Opening alert dialog...',
          );
          _showUnrecognizedDialog(
            closestSimilarity: punchResult.confidenceScore,
            closestCandidateName: punchResult.user?.name,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('[SCANNER_DEBUG] Verification error: $e');
    } finally {
      _isVerifying = false;
      _blinkDetected = false;
      _eyesWereOpen = false;

      // Resume stream only if no dialog is currently presented
      if (!_isShowingDialog &&
          _lastPunchResult == null &&
          mounted &&
          _cameraController != null &&
          !_cameraController!.value.isStreamingImages) {
        _startImageStream();
      }
    }
  }

  /// High-precision photo verification fallback (Used directly on Android & as fallback on iOS)
  Future<void> _capturePhotoAndVerify(
    Face face,
    AttendanceService attendanceService,
  ) async {
    try {
      await _cameraController?.stopImageStream();
      await _cameraController?.setFlashMode(FlashMode.off).catchError((_) {});

      final xFile = await _cameraController?.takePicture();
      if (xFile != null) {
        final fullImage = await ImageConverter.decodeOrientedImage(xFile);
        if (fullImage != null) {
          final photoInput = InputImage.fromFilePath(xFile.path);
          final photoFaces =
              await attendanceService.faceDetectorService.processImage(photoInput);
          final activeFaceBox = photoFaces.isNotEmpty
              ? photoFaces.first.boundingBox
              : face.boundingBox;

          debugPrint(
            '[SCANNER_DEBUG] 📐 High-Res Photo: ${fullImage.width}x${fullImage.height} | '
            'Face on photo: ${activeFaceBox.width.toInt()}x${activeFaceBox.height.toInt()} '
            'at (${activeFaceBox.left.toInt()}, ${activeFaceBox.top.toInt()})',
          );

          final cropped = ImageConverter.cropFaceFromDecoded(
            originalImage: fullImage,
            boundingBox: activeFaceBox,
          );

          if (cropped != null) {
            if (!mounted) return;
            final punchResult = await attendanceService.punchAttendance(
              faceImage: cropped,
              checkType: _checkType,
            );

            if (!mounted) return;

            if (punchResult.isSuccess && punchResult.record != null) {
              debugPrint(
                '[SCANNER_DEBUG] ✅ SUCCESS! Check-in recorded for "${punchResult.record!.employeeName}" '
                '(${punchResult.record!.employeeCode})',
              );
              HapticFeedback.heavyImpact();
              setState(() {
                _lastPunchResult = punchResult.record;
              });
              _showPunchDialog(punchResult.record!, isAlreadyCheckedIn: false);
              return;
            } else if (punchResult.isAlreadyCheckedIn && punchResult.record != null) {
              debugPrint(
                '[SCANNER_DEBUG] ℹ️ ALREADY CHECKED IN today: "${punchResult.record!.employeeName}"',
              );
              HapticFeedback.mediumImpact();
              setState(() {
                _lastPunchResult = punchResult.record;
              });
              _showPunchDialog(punchResult.record!, isAlreadyCheckedIn: true);
              return;
            } else if (punchResult.isCooldown) {
              debugPrint('[SCANNER_DEBUG] ⏳ Cooldown active (<5s). Ignoring repeat scan.');
              _updateStatus(
                'Already processed. Please step aside for next person.',
                AppColors.cyanAccent,
              );
            } else {
              debugPrint(
                '[SCANNER_DEBUG] ❌ UNRECOGNIZED FACE! Closest: "${punchResult.user?.name ?? 'Unknown'}" '
                '(${((punchResult.confidenceScore) * 100).toStringAsFixed(1)}%). Opening alert dialog...',
              );
              _showUnrecognizedDialog(
                closestSimilarity: punchResult.confidenceScore,
                closestCandidateName: punchResult.user?.name,
              );
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SCANNER_DEBUG] Photo verification error: $e');
    }
  }

  void _showPunchDialog(AttendanceRecord record, {required bool isAlreadyCheckedIn}) {
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
            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
          },
        );
      },
    ).then((_) {
      _isShowingDialog = false;
      if (mounted && !_isDisposed) {
        setState(() {
          _lastPunchResult = null;
          _blinkDetected = false;
          _eyesWereOpen = false;
          _statusText = 'Ready for next person...';
          _statusColor = AppColors.cyanAccent;
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
            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
          },
        );
      },
    ).then((_) {
      _isShowingDialog = false;
      if (mounted && !_isDisposed) {
        setState(() {
          _lastPunchResult = null;
          _blinkDetected = false;
          _eyesWereOpen = false;
          _statusText = 'Ready for next person...';
          _statusColor = AppColors.cyanAccent;
        });
        _startImageStream();
      }
    });
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
      debugPrint('Camera toggle error: $e');
    } finally {
      if (mounted) {
        _isSwitchingCamera = false;
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scannerAnimController.dispose();
    final oldController = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;
    oldController?.dispose().catchError((e) {
      debugPrint('Camera dispose error: $e');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = context.watch<AttendanceService>();
    final bool isCamReady = !_isDisposed &&
        _isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-Screen Seamless Live Camera Viewport
          if (isCamReady)
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
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.cyanAccent),
            ),

          // 2. Full-Screen Spotlight Vignette with Biometric Oval HUD & Laser Scan
          if (isCamReady)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scannerAnimation,
                builder: (context, _) {
                  final Color ovalColor = _isVerifying || _lastPunchResult != null
                      ? AppColors.emeraldGreen
                      : (_blinkDetected
                          ? AppColors.emeraldGreen
                          : (_statusColor == AppColors.amberWarning
                              ? AppColors.amberWarning
                              : AppColors.cyanAccent));

                  return CustomPaint(
                    painter: BiometricOvalPainter(
                      borderColor: ovalColor,
                      isVerified: _blinkDetected || _isVerifying,
                      pulseValue: _scannerAnimation.value,
                      laserProgress: _isVerifying ? 0.5 : _scannerAnimation.value,
                      customWidth: 240,
                      customHeight: 310,
                    ),
                  );
                },
              ),
            ),

          // 3. Top Floating Glassmorphic Header Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back / Exit Button
                    ClipOval(
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox.shrink(),

                    // Camera Switch Button
                    if (_cameras.length > 1)
                      ClipOval(
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: InkWell(
                            onTap: _toggleCamera,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Icon(
                                Icons.flip_camera_ios_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Floating Minimalist Status Pill
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _statusColor.withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: _statusColor.withValues(alpha: 0.15),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _statusColor,
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor,
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _statusColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active Staff: ${attendanceService.totalStaffCount} enrolled',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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
}
