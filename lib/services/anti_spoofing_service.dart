import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class AntiSpoofResult {
  final bool isReal;
  final double realScore;
  final double fakeScore;
  final int predictedClass; // 0: Spoof (Print/Paper), 1: Real Face, 2: Spoof (Screen/Replay)

  AntiSpoofResult({
    required this.isReal,
    required this.realScore,
    required this.fakeScore,
    required this.predictedClass,
  });

  @override
  String toString() {
    return 'AntiSpoofResult(isReal: $isReal, realScore: ${(realScore * 100).toStringAsFixed(1)}%, '
        'fakeScore: ${(fakeScore * 100).toStringAsFixed(1)}%, class: $predictedClass)';
  }
}

class AntiSpoofingService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  static const int inputSize = 80;
  static const double scaleFactor = 2.7;

  bool get isModelLoaded => _isModelLoaded;

  Future<void> initialize() async {
    if (_isModelLoaded) return;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/spoof_model_scale_2_7.tflite',
        options: options,
      );
      _interpreter?.allocateTensors();
      _isModelLoaded = true;
      debugPrint('[SPOOF_LOG] ✅ MiniVision Silent Anti-Spoofing model (Scale 2.7) loaded successfully');
    } catch (e) {
      debugPrint('[SPOOF_LOG] ⚠️ Error loading spoof model: $e. Falling back to active liveness only.');
    }
  }

  /// Run Silent Anti-Spoofing on an image with a given face bounding box
  AntiSpoofResult? checkLiveness({
    required img.Image fullImage,
    required int faceX,
    required int faceY,
    required int faceWidth,
    required int faceHeight,
  }) {
    if (!_isModelLoaded || _interpreter == null) {
      debugPrint('[SPOOF_LOG] Model not ready yet');
      return null;
    }

    try {
      // 1. Calculate expanded 2.7x crop box centered around face
      final centerX = faceX + faceWidth / 2.0;
      final centerY = faceY + faceHeight / 2.0;
      final cropWidth = (faceWidth * scaleFactor).round();
      final cropHeight = (faceHeight * scaleFactor).round();

      int cropX = (centerX - cropWidth / 2.0).round();
      int cropY = (centerY - cropHeight / 2.0).round();

      // Clamp to image boundaries
      cropX = max(0, min(cropX, fullImage.width - 1));
      cropY = max(0, min(cropY, fullImage.height - 1));
      final actualWidth = min(cropWidth, fullImage.width - cropX);
      final actualHeight = min(cropHeight, fullImage.height - cropY);

      if (actualWidth <= 0 || actualHeight <= 0) {
        debugPrint('[SPOOF_LOG] Invalid crop dimensions');
        return null;
      }

      // 2. Crop 2.7x region
      final cropped = img.copyCrop(
        fullImage,
        x: cropX,
        y: cropY,
        width: actualWidth,
        height: actualHeight,
      );

      // 3. Resize to 80x80
      final resized = img.copyResize(
        cropped,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      // 4. Preprocess to [1, 80, 80, 3] in BGR format (MiniVision was trained on OpenCV BGR)
      final input = List.generate(
        1,
        (_) => List.generate(
          inputSize,
          (y) => List.generate(
            inputSize,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.b / 255.0,
                pixel.g / 255.0,
                pixel.r / 255.0,
              ];
            },
          ),
        ),
      );

      // 5. Output tensor [1, 3]
      final output = List.generate(
        1,
        (_) => List<double>.filled(3, 0.0),
      );

      // 6. Run inference
      _interpreter!.run(input, output);
      final logits = output[0];

      // 7. Softmax
      final probs = _softmax(logits);
      final p0 = probs[0]; // Spoof (Printed Photo / Paper)
      final p1 = probs[1]; // Real Human Face
      final p2 = probs[2]; // Spoof (Screen Replay / Phone screen)

      final predictedClass = _argmax(probs);
      final isReal = predictedClass == 1 && p1 >= 0.55;
      final realScore = p1;
      final fakeScore = p0 + p2;

      debugPrint(
        '[SPOOF_LOG] 🔍 Inference: Class $predictedClass | Real: ${(realScore * 100).toStringAsFixed(1)}% | '
        'Fake: ${(fakeScore * 100).toStringAsFixed(1)}% | Result: ${isReal ? "✅ REAL HUMAN" : "❌ FAKE / SPOOF DETECTED"}',
      );

      return AntiSpoofResult(
        isReal: isReal,
        realScore: realScore,
        fakeScore: fakeScore,
        predictedClass: predictedClass,
      );
    } catch (e) {
      debugPrint('[SPOOF_LOG] Inference error: $e');
      return null;
    }
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final expVals = logits.map((val) => exp(val - maxLogit)).toList();
    final sumExp = expVals.reduce((a, b) => a + b);
    if (sumExp == 0) return logits;
    return expVals.map((val) => val / sumExp).toList();
  }

  int _argmax(List<double> list) {
    int maxIdx = 0;
    double maxVal = list[0];
    for (int i = 1; i < list.length; i++) {
      if (list[i] > maxVal) {
        maxVal = list[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}
