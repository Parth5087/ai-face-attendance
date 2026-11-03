import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class ImageConverter {
  /// Converts a [CameraImage] to [InputImage] for Google ML Kit
  static InputImage? toInputImage({
    required CameraImage cameraImage,
    required CameraDescription camera,
  }) {
    try {
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation;

      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        var rotationCompensation = _orientations[DeviceOrientation.portraitUp];
        if (rotationCompensation == null) return null;
        if (camera.lensDirection == CameraLensDirection.front) {
          // Front camera on Android
          rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
        } else {
          // Back camera on Android
          rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }

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

  /// Converts a [CameraImage] directly to an upright [img.Image] without shutter sound
  static img.Image? convertCameraImage({
    required CameraImage cameraImage,
    required CameraDescription camera,
  }) {
    try {
      if (Platform.isIOS) {
        final plane = cameraImage.planes[0];
        final bytes = plane.bytes;
        final width = cameraImage.width;
        final height = cameraImage.height;
        final bytesPerRow = plane.bytesPerRow;

        final img.Image converted = img.Image(width: width, height: height);
        for (int y = 0; y < height; y++) {
          final rowStart = y * bytesPerRow;
          for (int x = 0; x < width; x++) {
            final offset = rowStart + (x * 4);
            final b = bytes[offset];
            final g = bytes[offset + 1];
            final r = bytes[offset + 2];
            final a = bytes[offset + 3];
            converted.setPixelRgba(x, y, r, g, b, a);
          }
        }

        // On iOS portrait, raw camera stream frame is landscape (width > height).
        // Rotate it 90 degrees clockwise to make it upright portrait (height > width).
        img.Image upright = converted;
        if (converted.width > converted.height) {
          final int angle = camera.sensorOrientation != 0 ? camera.sensorOrientation : 90;
          upright = img.copyRotate(converted, angle: angle);
        }

        // For front camera, mirror horizontally to match natural selfie orientation
        if (camera.lensDirection == CameraLensDirection.front) {
          upright = img.flipHorizontal(upright);
        }

        return upright;
      } else {
        // Android YUV420 / NV21
        return _convertYuv420ToImage(cameraImage, camera);
      }
    } catch (e) {
      debugPrint('[IMAGE_CONVERTER] Stream conversion failed: $e');
      return null;
    }
  }

  static img.Image? _convertYuv420ToImage(CameraImage image, CameraDescription camera) {
    try {
      final width = image.width;
      final height = image.height;
      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final hasVPlane = image.planes.length > 2;
      final vPlane = hasVPlane ? image.planes[2].bytes : null;

      final yRowStride = image.planes[0].bytesPerRow;
      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      final yLen = yPlane.length;
      final uLen = uPlane.length;
      final vLen = vPlane?.length ?? 0;

      final img.Image converted = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        final pY = y * yRowStride;
        final uvRow = (y >> 1) * uvRowStride;
        for (int x = 0; x < width; x++) {
          final uvIndex = uvRow + (x >> 1) * uvPixelStride;

          final yp = (pY + x < yLen) ? yPlane[pY + x] : 0;
          final up = (uvIndex < uLen) ? uPlane[uvIndex] : 128;
          final vp = hasVPlane
              ? (uvIndex < vLen ? vPlane![uvIndex] : 128)
              : (uvIndex + 1 < uLen ? uPlane[uvIndex + 1] : 128);

          final r = (yp + 1.402 * (vp - 128)).toInt().clamp(0, 255);
          final g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).toInt().clamp(0, 255);
          final b = (yp + 1.772 * (up - 128)).toInt().clamp(0, 255);

          converted.setPixelRgb(x, y, r, g, b);
        }
      }

      if (camera.sensorOrientation == 90) {
        return img.copyRotate(converted, angle: 90);
      } else if (camera.sensorOrientation == 180) {
        return img.copyRotate(converted, angle: 180);
      } else if (camera.sensorOrientation == 270) {
        return img.copyRotate(converted, angle: 270);
      }
      return converted;
    } catch (e) {
      debugPrint('[IMAGE_CONVERTER] Android YUV conversion error: $e');
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

  /// Crops face with a 15% margin from an already decoded [img.Image]
  static img.Image? cropFaceFromDecoded({
    required img.Image originalImage,
    required Rect boundingBox,
  }) {
    try {
      final marginX = (boundingBox.width * 0.15).toInt();
      final marginY = (boundingBox.height * 0.15).toInt();

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
  }) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Fix orientation if needed
      originalImage = img.bakeOrientation(originalImage);

      // Add a slight margin around the bounding box (15%) for better feature capture
      final marginX = (boundingBox.width * 0.15).toInt();
      final marginY = (boundingBox.height * 0.15).toInt();

      int x = (boundingBox.left - marginX).toInt().clamp(0, originalImage.width - 1);
      int y = (boundingBox.top - marginY).toInt().clamp(0, originalImage.height - 1);
      int w = (boundingBox.width + 2 * marginX).toInt().clamp(1, originalImage.width - x);
      int h = (boundingBox.height + 2 * marginY).toInt().clamp(1, originalImage.height - y);

      final croppedFace = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      return croppedFace;
    } catch (e) {
      debugPrint('Error cropping face from file: $e');
      return null;
    }
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
}
