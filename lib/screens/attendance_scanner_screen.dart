import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/responsive.dart';
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

  AttendanceService get _attendanceService {
    try {
      return context.read<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
  }

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

    final attendanceService = _attendanceService;

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
          // Fall back to high-precision photo detection
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

  /// High-precision photo verification fallback
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

  /// 📱 Tablet Kiosk Instant Punch Card
  /// Displays the freshly captured live punch photo avatar next to employee name, code, role, and punch time.
  Widget _buildInstantPunchCard(AttendanceRecord record) {
    final attendanceService = _attendanceService;
    final user = attendanceService.users
        .where((u) => u.id == record.employeeId)
        .firstOrNull;

    final Uint8List? avatarBytes = user?.avatarBytes;
    final Uint8List? punchBytes = record.punchImageBytes ?? avatarBytes;
    final isLate = record.status == 'LATE';
    final Color statusColor = isLate ? AppColors.amberWarning : AppColors.emeraldGreen;
    final timeStr = DateFormat('hh:mm:ss a').format(record.timestamp);
    final matchPercent = (record.confidenceScore * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF162544),
            Color(0xFF0F1A30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.emeraldGreen,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldGreen.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Freshly captured live punch photo avatar (Nested structure to avoid border cut-off)
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emeraldGreen, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: punchBytes != null
                      ? Image.memory(
                          punchBytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          key: ValueKey('kiosk_punch_${record.id}'),
                        )
                      : Container(
                          color: const Color(0xFF141E30),
                          child: Center(
                            child: Text(
                              record.employeeName.isNotEmpty
                                  ? record.employeeName.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emeraldGreen,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldGreen,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'LIVE SNAPSHOT',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'VERIFIED PUNCH',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.emeraldGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  record.employeeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCardLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.employeeCode,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$matchPercent% Match',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emeraldGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Camera Viewport with Biometric Oval HUD and Laser Overlay
  Widget _buildCameraViewport({required bool isCamReady, double customWidth = 240, double customHeight = 310}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview
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

        // Biometric Oval HUD with Laser
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
                    customWidth: customWidth,
                    customHeight: customHeight,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Top Floating Glassmorphic Header Bar (respecting top inset)
  Widget _buildTopBar(double topInset) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 12),
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
    );
  }

  /// Bottom Floating Status Pill (respecting bottom inset)
  Widget _buildStatusPill(double bottomInset, AttendanceService attendanceService) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF131D31).withValues(alpha: 0.92),
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
    );
  }

  /// 📟 Tablet Kiosk Mode Right Console Pane (40% Width)
  Widget _buildTabletRightConsole(AttendanceService attendanceService, double topInset, double bottomInset) {
    final todayRecords = attendanceService.todayRecords;
    final onTimeCount = todayRecords.where((r) => r.status != 'LATE').length;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1729),
        border: Border(
          left: BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, bottomInset + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Office Name & Terminal Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'AI ATTENDANCE KIOSK',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cyanAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'HQ Main Terminal • Active Sensor',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.emeraldGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.emeraldGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'ONLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Live Digital Clock Console Banner
          _KioskLiveClock(),

          const SizedBox(height: 14),

          // Today's Check-in / On-Time Counters
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141E30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TODAY CHECK-INS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${attendanceService.todayCheckInCount}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141E30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ON-TIME PUNCTUAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$onTimeCount',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.emeraldGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Section Header: Instant Punch Feed
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, size: 15, color: AppColors.cyanAccent),
              const SizedBox(width: 6),
              const Text(
                'LIVE PUNCH STREAM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '${todayRecords.length} Today',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Active Instant Punch Card or Recent Stream
          Expanded(
            child: _lastPunchResult != null
                ? Column(
                    children: [
                      _buildInstantPunchCard(_lastPunchResult!),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildRecentStreamList(todayRecords),
                      ),
                    ],
                  )
                : _buildRecentStreamList(todayRecords),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStreamList(List<AttendanceRecord> todayRecords) {
    if (todayRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanAccent.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.cyanAccent.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.face_retouching_natural_rounded,
                color: AppColors.cyanAccent,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Awaiting Staff Check-in',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Step in front of the camera and blink naturally to log attendance.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final reversed = todayRecords.reversed.toList();
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final record = reversed[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildInstantPunchCard(record),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = _attendanceService;
    final bool isCamReady = !_isDisposed &&
        _isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isTablet = context.isTablet;

    return Scaffold(
      backgroundColor: Colors.black,
      body: isTablet
          ? Row(
              children: [
                // 📟 Left Pane (60% Width): Front camera stream with biometric oval HUD
                Expanded(
                  flex: 6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCameraViewport(
                        isCamReady: isCamReady,
                        customWidth: 280,
                        customHeight: 360,
                      ),
                      _buildTopBar(topInset),
                      _buildStatusPill(bottomInset, attendanceService),
                    ],
                  ),
                ),

                // 📟 Right Pane (40% Width): Permanent live kiosk console
                Expanded(
                  flex: 4,
                  child: _buildTabletRightConsole(attendanceService, topInset, bottomInset),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // 📱 Mobile Mode (< 600px): Clean single-column centered layout
                _buildCameraViewport(isCamReady: isCamReady),
                _buildTopBar(topInset),
                _buildStatusPill(bottomInset, attendanceService),
              ],
            ),
    );
  }
}

/// 🕒 Self-updating live digital clock widget for Tablet Kiosk console
class _KioskLiveClock extends StatefulWidget {
  @override
  State<_KioskLiveClock> createState() => _KioskLiveClockState();
}

class _KioskLiveClockState extends State<_KioskLiveClock> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(_currentTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141E30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cyanAccent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppColors.cyanAccent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
