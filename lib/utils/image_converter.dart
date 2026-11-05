import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

enum FrameFormatType {
  nv21,
  yuv420,
  bgra8888,
}

/// Safe, immutable copy of camera stream planes in pure Dart memory
class CapturedFrame {
  final int width;
  final int height;
  final FrameFormatType formatType;
  final Uint8List singleBuffer;
  final int bytesPerRow;

  // Tri-plane YUV420 fields
  final Uint8List? yPlane;
  final Uint8List? uPlane;
  final Uint8List? vPlane;
  final int yRowStride;
  final int uRowStride;
  final int vRowStride;
  final int uPixelStride;
  final int vPixelStride;

  CapturedFrame({
    required this.width,
    required this.height,
    required this.formatType,
    required this.singleBuffer,
    required this.bytesPerRow,
    this.yPlane,
    this.uPlane,
    this.vPlane,
    this.yRowStride = 0,
    this.uRowStride = 0,
    this.vRowStride = 0,
    this.uPixelStride = 1,
    this.vPixelStride = 1,
  });

  factory CapturedFrame.fromCameraImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    // 1. iOS / BGRA8888
    if (Platform.isIOS || image.format.group == ImageFormatGroup.bgra8888) {
      return CapturedFrame(
        width: width,
        height: height,
        formatType: FrameFormatType.bgra8888,
        singleBuffer: Uint8List.fromList(image.planes[0].bytes),
        bytesPerRow: image.planes[0].bytesPerRow,
      );
    }

    // 2. Android Single-Plane NV21 (CameraX NV21 stream format contains full Y + VU in planes[0])
    if (image.planes.length == 1 ||
        image.format.group == ImageFormatGroup.nv21 ||
        (image.planes.isNotEmpty && image.planes[0].bytes.length >= width * height * 3 ~/ 2)) {
      return CapturedFrame(
        width: width,
        height: height,
        formatType: FrameFormatType.nv21,
        singleBuffer: Uint8List.fromList(image.planes[0].bytes),
        bytesPerRow: image.planes[0].bytesPerRow,
      );
    }

    // 3. Android Tri-Plane YUV_420_888
    return CapturedFrame(
      width: width,
      height: height,
      formatType: FrameFormatType.yuv420,
      singleBuffer: Uint8List(0),
      bytesPerRow: image.planes[0].bytesPerRow,
      yPlane: Uint8List.fromList(image.planes[0].bytes),
      uPlane: image.planes.length > 1 ? Uint8List.fromList(image.planes[1].bytes) : Uint8List(0),
      vPlane: image.planes.length > 2 ? Uint8List.fromList(image.planes[2].bytes) : Uint8List(0),
      yRowStride: image.planes[0].bytesPerRow,
      uRowStride: image.planes.length > 1 ? image.planes[1].bytesPerRow : image.planes[0].bytesPerRow ~/ 2,
      vRowStride: image.planes.length > 2 ? image.planes[2].bytesPerRow : image.planes[0].bytesPerRow ~/ 2,
      uPixelStride: image.planes.length > 1 ? (image.planes[1].bytesPerPixel ?? 1) : 1,
      vPixelStride: image.planes.length > 2 ? (image.planes[2].bytesPerPixel ?? 1) : 1,
    );
  }
}

class ImageConverter {
  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Computes sensor rotation compensation for Google ML Kit and bitmap orientation
  static int computeRotationCompensation({
    required CameraDescription camera,
    DeviceOrientation? deviceOrientation,
    Orientation? screenOrientation,
  }) {
    if (Platform.isIOS) {
      // 🍎 iOS AVFoundation natively rotates the video stream pixel buffer (AVCaptureVideoOrientation)
      // to match the active UI orientation. Therefore, the raw buffer delivered to Flutter
      // is ALREADY upright (0° compensation). Rotating by sensorOrientation (90°) on iOS
      // causes the image to turn sideways.
      return 0;
    }

    // 🤖 Android:
    // Android camera sensors stream raw landscape frames (width > height) regardless of UI orientation.
    // We must compensate using sensor orientation and device orientation:
    DeviceOrientation effectiveOrientation;
    if (deviceOrientation != null) {
      effectiveOrientation = deviceOrientation;
    } else if (screenOrientation == Orientation.landscape) {
      effectiveOrientation = DeviceOrientation.landscapeLeft;
    } else {
      effectiveOrientation = DeviceOrientation.portraitUp;
    }

    var rotationCompensation = _orientations[effectiveOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (camera.sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (camera.sensorOrientation - rotationCompensation + 360) % 360;
    }
    return rotationCompensation;
  }

  /// Converts a [CameraImage] to [InputImage] for Google ML Kit with dynamic orientation compensation
  static InputImage? toInputImage({
    required CameraImage cameraImage,
    required CameraDescription camera,
    DeviceOrientation? deviceOrientation,
    Orientation? screenOrientation,
  }) {
    try {
      final rotationAngle = computeRotationCompensation(
        camera: camera,
        deviceOrientation: deviceOrientation,
        screenOrientation: screenOrientation,
      );
      final rotation = InputImageRotationValue.fromRawValue(rotationAngle);
      if (rotation == null) return null;

      // Format determination
      final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
      if (format == null) return null;

      // Android usually has 3 planes (Y, U, V); concatenate them if necessary
      if (cameraImage.planes.isEmpty) return null;

      final allBytes = WriteBuffer();
      for (final plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  /// Converts a safely cloned [CapturedFrame] directly to an upright [img.Image] with true RGB color preservation
  static img.Image? convertCapturedFrame({
    required CapturedFrame frame,
    required CameraDescription camera,
    DeviceOrientation? deviceOrientation,
    Orientation? screenOrientation,
  }) {
    try {
      final rotationAngle = computeRotationCompensation(
        camera: camera,
        deviceOrientation: deviceOrientation,
        screenOrientation: screenOrientation,
      );

      final int width = frame.width;
      final int height = frame.height;
      final img.Image converted = img.Image(width: width, height: height);

      if (frame.formatType == FrameFormatType.bgra8888) {
        // iOS BGRA8888
        final bytes = frame.singleBuffer;
        final int bLen = bytes.length;
        final int bytesPerRow = frame.bytesPerRow > 0 ? frame.bytesPerRow : width * 4;

        for (int y = 0; y < height; y++) {
          final int rowStart = y * bytesPerRow;
          for (int x = 0; x < width; x++) {
            final int offset = rowStart + (x * 4);
            if (offset + 2 < bLen) {
              final int b = bytes[offset];
              final int g = bytes[offset + 1];
              final int r = bytes[offset + 2];
              converted.setPixelRgb(x, y, r, g, b);
            }
          }
        }
      } else if (frame.formatType == FrameFormatType.nv21) {
        // Android Single-Plane NV21 (Y followed by interleaved VU)
        final nv21 = frame.singleBuffer;
        final int nvLen = nv21.length;
        final int frameSize = width * height;

        for (int y = 0; y < height; y++) {
          final int yRow = y * width;
          final int uvRow = frameSize + (y >> 1) * width;
          for (int x = 0; x < width; x++) {
            final int yIdx = yRow + x;
            final int yp = (yIdx < nvLen) ? nv21[yIdx] : 0;

            final int uvIndex = uvRow + (x & ~1);
            int vp = 128;
            int up = 128;
            if (uvIndex + 1 < nvLen) {
              vp = nv21[uvIndex];     // V at even offset
              up = nv21[uvIndex + 1]; // U at odd offset
            }

            final int r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
            final int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round().clamp(0, 255);
            final int b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);

            converted.setPixelRgb(x, y, r, g, b);
          }
        }
      } else {
        // Tri-Plane YUV_420_888
        final yPlane = frame.yPlane ?? Uint8List(0);
        final uPlane = frame.uPlane ?? Uint8List(0);
        final vPlane = frame.vPlane ?? Uint8List(0);
        final int yLen = yPlane.length;
        final int uLen = uPlane.length;
        final int vLen = vPlane.length;

        final int yRowStride = frame.yRowStride > 0 ? frame.yRowStride : width;
        final int uRowStride = frame.uRowStride > 0 ? frame.uRowStride : width ~/ 2;
        final int vRowStride = frame.vRowStride > 0 ? frame.vRowStride : width ~/ 2;
        final int uPixelStride = frame.uPixelStride;
        final int vPixelStride = frame.vPixelStride;

        for (int y = 0; y < height; y++) {
          final int pY = y * yRowStride;
          final int pU = (y >> 1) * uRowStride;
          final int pV = (y >> 1) * vRowStride;
          for (int x = 0; x < width; x++) {
            final int yIdx = pY + x;
            final int yp = (yIdx < yLen) ? yPlane[yIdx] : 0;

            final int uIdx = pU + (x >> 1) * uPixelStride;
            final int vIdx = pV + (x >> 1) * vPixelStride;

            final int up = (uIdx < uLen) ? uPlane[uIdx] : 128;
            final int vp = (vIdx < vLen) ? vPlane[vIdx] : 128;

            final int r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
            final int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round().clamp(0, 255);
            final int b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);

            converted.setPixelRgb(x, y, r, g, b);
          }
        }
      }

      // 🛡️ Safety Guard: If buffer is ALREADY portrait (height >= width),
      // rotating by 90° or 270° would turn it into landscape (sideways)!
      if (height >= width && (rotationAngle == 90 || rotationAngle == 270)) {
        return converted;
      }

      if (rotationAngle == 90) {
        return img.copyRotate(converted, angle: 90);
      } else if (rotationAngle == 180) {
        return img.copyRotate(converted, angle: 180);
      } else if (rotationAngle == 270) {
        return img.copyRotate(converted, angle: 270);
      }
      return converted;
    } catch (e) {
      debugPrint('[KIOSK_DEBUG] ❌ Frame conversion error: $e');
      return null;
    }
  }

  /// Converts a [CameraImage] directly to an upright [img.Image] with dynamic orientation compensation
  static img.Image? convertCameraImage({
    required CameraImage cameraImage,
    required CameraDescription camera,
    DeviceOrientation? deviceOrientation,
    Orientation? screenOrientation,
  }) {
    try {
      final safeFrame = CapturedFrame.fromCameraImage(cameraImage);
      return convertCapturedFrame(
        frame: safeFrame,
        camera: camera,
        deviceOrientation: deviceOrientation,
        screenOrientation: screenOrientation,
      );
    } catch (e) {
      debugPrint('[KIOSK_DEBUG] ❌ Stream conversion failed: $e');
      return null;
    }
  }

  /// Decodes and bakes orientation for an [XFile] image
  static Future<img.Image?> decodeOrientedImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;
      return img.bakeOrientation(originalImage);
    } catch (e) {
      debugPrint('Error decoding image: $e');
      return null;
    }
  }

  /// Crops face with a configurable margin (defaults to 32% for studio portrait) from an already decoded [img.Image]
  static img.Image? cropFaceFromDecoded({
    required img.Image originalImage,
    required Rect boundingBox,
    double marginFactor = 0.32,
  }) {
    try {
      final marginX = (boundingBox.width * marginFactor).toInt();
      final marginY = (boundingBox.height * marginFactor).toInt();

      int x = (boundingBox.left - marginX).toInt().clamp(0, originalImage.width - 1);
      int y = (boundingBox.top - marginY).toInt().clamp(0, originalImage.height - 1);
      int w = (boundingBox.width + 2 * marginX).toInt().clamp(1, originalImage.width - x);
      int h = (boundingBox.height + 2 * marginY).toInt().clamp(1, originalImage.height - y);

      return img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: w,
        height: h,
      );
    } catch (e) {
      debugPrint('Error cropping face from decoded image: $e');
      return null;
    }
  }

  /// Converts a captured [XFile] to an [img.Image] and crops the detected [Face]
  static Future<img.Image?> cropFaceFromXFile({
    required XFile file,
    required Rect boundingBox,
    bool isFrontCamera = true,
    double marginFactor = 0.32,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Fix orientation if needed
      originalImage = img.bakeOrientation(originalImage);

      return cropFaceFromDecoded(
        originalImage: originalImage,
        boundingBox: boundingBox,
        marginFactor: marginFactor,
      );
    } catch (e) {
      debugPrint('Error cropping face from file: $e');
      return null;
    }
  }
}
