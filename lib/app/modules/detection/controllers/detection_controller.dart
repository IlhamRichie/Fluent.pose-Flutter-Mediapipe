import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionController extends GetxController {
  late CameraController cameraController;
  late Interpreter interpreter;
  late PoseDetector poseDetector;

  final RxBool isInitialized = false.obs;
  final RxBool isProcessing = false.obs;
  final RxInt cameraIndex = 0.obs;
  final RxList<Pose> detectedPoses = <Pose>[].obs;
  final RxString predictionLabel = 'Menunggu deteksi...'.obs;
  final RxDouble confidence = 0.0.obs;

  late List<CameraDescription> cameras;
  final List<String> labels = ['Gerak', 'Tidak Gerak'];

  @override
  void onInit() async {
    super.onInit();
    await initializeSystem();
  }

  Future<void> initializeSystem() async {
    try {
      await _loadModel();
      await _initializePoseDetector();
      await _initializeCamera();
    } catch (e) {
      Get.snackbar('Error', 'Initialization failed: ${e.toString()}');
    }
  }

  Future<void> _loadModel() async {
    interpreter = await Interpreter.fromAsset('assets/ilham_model.tflite');
  }

  Future<void> _initializePoseDetector() async {
    poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    cameraController = CameraController(
      cameras[cameraIndex.value],
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await cameraController.initialize();
    isInitialized.value = true;
    cameraController.startImageStream(_processCameraImage);
  }

  Future<void> switchCamera() async {
    if (isProcessing.value) return;
    isProcessing.value = true;

    await cameraController.stopImageStream();
    await cameraController.dispose();

    cameraIndex.value = (cameraIndex.value + 1) % cameras.length;
    await _initializeCamera();

    isProcessing.value = false;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (isProcessing.value) return;
    isProcessing.value = true;

    try {
      final inputImage = _convertCameraImage(image);
      final poses = await poseDetector.processImage(inputImage);
      detectedPoses.assignAll(poses);

      if (poses.isNotEmpty) {
        await _runModelInference(poses.first);
      }
    } catch (e) {
      Get.log('Processing error: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  InputImage _convertCameraImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _getRotation(cameraController.description.sensorOrientation),
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow, // Ambil dari plane pertama
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }

  InputImageRotation _getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _runModelInference(Pose pose) async {
    final features = _extractPoseFeatures(pose);
    final output = List.filled(labels.length, 0.0).reshape([1, labels.length]);

    interpreter.run([features], output);

    final maxConfidence = output[0].reduce((a, b) => a > b ? a : b);
    final predictedIndex = output[0].indexOf(maxConfidence);

    confidence.value = maxConfidence;
    predictionLabel.value =
        '${labels[predictedIndex]} (${(maxConfidence * 100).toStringAsFixed(1)}%)';
  }

  List<double> _extractPoseFeatures(Pose pose) {
    return pose.landmarks.values
        .expand((landmark) => [landmark.x, landmark.y, landmark.z])
        .toList();
  }

  @override
  void onClose() {
    cameraController.dispose();
    poseDetector.close();
    interpreter.close();
    super.onClose();
  }
}
