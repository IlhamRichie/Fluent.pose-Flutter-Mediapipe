import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DetectionController extends GetxController {
  late CameraController cameraController;
  late Interpreter interpreter;
  final RxBool isInitialized = false.obs;
  final RxBool isProcessing = false.obs;
  final RxString label = ''.obs;
  final RxDouble confidence = 0.0.obs;
  final RxInt cameraIndex = 0.obs;
  late List<CameraDescription> cameras;
  late List<String> labels;

  final int inputSize = 224;

  @override
  void onInit() async {
    super.onInit();
    await _loadModel();
    await _loadLabels();
    await _setupCameras();
  }

  Future<void> _loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/ilham_model.tflite');
      print('Model loaded successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to load model: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      labels = labelData.split('\n');
    } catch (e) {
      Get.snackbar('Error', 'Failed to load labels: $e');
    }
  }

  Future<void> _setupCameras() async {
    try {
      cameras = await availableCameras();
      await _initCamera();
    } catch (e) {
      Get.snackbar('Error', 'Failed to initialize camera');
    }
  }

  Future<void> _initCamera() async {
    cameraController = CameraController(
      cameras[cameraIndex.value],
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await cameraController.initialize();
      isInitialized.value = true;
      cameraController.startImageStream(_processCameraImage);
    } catch (e) {
      Get.snackbar('Error', 'Camera initialization failed');
    }
  }

  Future<void> switchCamera() async {
    if (isProcessing.value) return;
    isProcessing.value = true;

    await cameraController.dispose();
    cameraIndex.value = (cameraIndex.value + 1) % cameras.length;
    await _initCamera();

    isProcessing.value = false;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (isProcessing.value) return;
    isProcessing.value = true;

    try {
      final input = await _preprocessImage(image);
      final output = List.filled(2, 0.0).reshape([1, 2]);

      interpreter.run(input, output);

      final result = output[0];
      final maxIndex =
          result.indexWhere((e) => e == result.reduce((a, b) => a > b ? a : b));

      label.value = labels[maxIndex];
      confidence.value = result[maxIndex];
    } catch (e) {
      Get.log('Inference error: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(
      CameraImage image) async {
    final img.Image convertedImage = _convertCameraImage(image);
    final img.Image resizedImage =
        img.copyResize(convertedImage, width: inputSize, height: inputSize);

    return List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resizedImage.getPixel(x, y);
            final r = pixel.r / 255.0;
            final g = pixel.g / 255.0;
            final b = pixel.b / 255.0;
            return [r, g, b];
          },
        ),
      ),
    );
  }

  img.Image _convertCameraImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image imgImage = img.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uPlane.bytesPerPixel!;
        final int ypIndex = y * yPlane.bytesPerRow + x;

        final int yVal = yPlane.bytes[ypIndex];
        final int uVal = uPlane.bytes[uvIndex];
        final int vVal = vPlane.bytes[uvIndex];

        final int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
        final int g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
            .round()
            .clamp(0, 255);
        final int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

        imgImage.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return imgImage;
  }

  @override
  void onClose() {
    cameraController.dispose();
    interpreter.close();
    super.onClose();
  }
}
