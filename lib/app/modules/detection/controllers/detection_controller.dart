import 'dart:async';
import 'dart:ui'; // Required for Size
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'; // Required for WriteBuffer and kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionController extends GetxController {
  late CameraController _cameraController;
  late Interpreter _interpreter;
  late PoseDetector _poseDetector;

  final RxBool _isInitialized = false.obs;
  final RxBool _isProcessing = false.obs;
  final RxInt _cameraIndex = 0.obs;
  final RxList<Pose> _detectedPoses = <Pose>[].obs;
  
  // --- SESUAIKAN DENGAN KELAS MODEL ANDA ---
  final RxString _predictionLabel = 'Mendeteksi...'.obs;
  static const List<String> _labels = ['Gerak', 'Tidak Gerak']; // PASTIKAN URUTAN INI SESUAI OUTPUT MODEL
  // --- END SESUAIKAN ---

  final RxDouble _confidence = 0.0.obs;
  final RxString _currentAction = 'Belum ada aksi terdeteksi'.obs;

  bool get isInitialized => _isInitialized.value;
  bool get isProcessing => _isProcessing.value;
  List<Pose> get detectedPoses => _detectedPoses;
  String get predictionLabel => _predictionLabel.value;
  double get confidence => _confidence.value;
  String get currentAction => _currentAction.value;
  CameraController get cameraController => _cameraController;

  static const double _confidenceThreshold = 0.5; // Anda bisa sesuaikan threshold ini

  // --- JUMLAH FITUR YANG DIHARAPKAN MODEL ---
  // Jika model Anda menggunakan 33 landmark (x, y, z): 33 * 3 = 99
  // Jika model Anda menggunakan 33 landmark (x, y, z, visibility): 33 * 4 = 132
  // SESUAIKAN INI JIKA PERLU:
  static const int EXPECTED_FEATURE_LENGTH = 99; 
  static const bool USE_VISIBILITY_SCORE = false; // Set true jika model dilatih dengan visibility/likelihood
  // --- END SESUAIKAN ---


  @override
  void onInit() {
    super.onInit();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    Get.log('Memulai inisialisasi sistem...');
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _handleError('Tidak ada kamera tersedia', 'Daftar kamera kosong.');
        _isInitialized.value = false;
        return;
      }
      
      await Future.wait([
        _loadModel(),
        _initializePoseDetector(),
        _initializeCamera(cameras),
      ]);
      _isInitialized.value = true;
      Get.log('Sistem berhasil diinisialisasi.');
    } catch (e) {
      _handleError('Inisialisasi sistem gagal', e);
      _isInitialized.value = false;
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/ilham_model.tflite'); // Pastikan nama file benar
      // Log detail input/output tensor model jika memungkinkan (opsional, butuh info lebih lanjut dari interpreter)
      Get.log('Model TFLite berhasil dimuat.');
      Get.log('Input tensors: ${_interpreter.getInputTensors().map((t) => "Shape: ${t.shape.join(',')}, Type: ${t.type}").toList()}');
      Get.log('Output tensors: ${_interpreter.getOutputTensors().map((t) => "Shape: ${t.shape.join(',')}, Type: ${t.type}").toList()}');
    } catch (e) {
      throw Exception('Gagal memuat model TFLite: $e');
    }
  }

  Future<void> _initializePoseDetector() async {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream, // stream untuk deteksi berkelanjutan
        model: PoseDetectionModel.base, // atau .accurate jika performa perangkat memadai
      ),
    );
    Get.log('Pose detector (MLKit) berhasil diinisialisasi.');
  }

  Future<void> _initializeCamera(List<CameraDescription> cameras) async {
    try {
      if (_cameraIndex.value >= cameras.length) {
        _cameraIndex.value = 0;
      }

      _cameraController = CameraController(
        cameras[_cameraIndex.value],
        ResolutionPreset.medium, // Sesuaikan resolusi jika perlu
        imageFormatGroup: ImageFormatGroup.yuv420, // Umumnya didukung dan baik untuk ML
        enableAudio: false,
      );

      await _cameraController.initialize();
      Get.log('Kamera berhasil diinisialisasi: ${cameras[_cameraIndex.value].name}');

      if (_cameraController.value.isInitialized) {
        await _cameraController.startImageStream(_processCameraImage);
        Get.log('Image stream dari kamera dimulai.');
      } else {
        throw Exception('Controller kamera gagal diinisialisasi.');
      }
    } catch (e) {
      throw Exception('Inisialisasi kamera gagal: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_isProcessing.value) {
      Get.log('Tidak dapat mengganti kamera saat sedang memproses.');
      return;
    }
    if (!_isInitialized.value) {
       Get.log('Tidak dapat mengganti kamera, sistem belum diinisialisasi.');
       return;
    }

    _isProcessing.value = true;
    Get.log('Mengganti kamera...');

    try {
      await _cameraController.stopImageStream();
      Get.log('Image stream dihentikan untuk penggantian kamera.');
      
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _handleError('Tidak ada kamera tersedia untuk diganti.', '');
        _isProcessing.value = false;
        return;
      }
      _cameraIndex.value = (_cameraIndex.value + 1) % cameras.length;
      
      await _initializeCamera(cameras); 

    } catch (e) {
      _handleError('Gagal mengganti kamera', e);
    } finally {
      _isProcessing.value = false;
      Get.log('Proses penggantian kamera selesai.');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (kIsWeb) { // google_mlkit_pose_detection tidak mendukung web secara langsung dengan CameraImage
        _isProcessing.value = false;
        return;
    }
    // Jangan proses jika frame sebelumnya masih diproses, atau sistem belum siap, atau stream tidak aktif
    if (_isProcessing.value || !_isInitialized.value || !_cameraController.value.isStreamingImages) return;
    
    _isProcessing.value = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        Get.log("Gagal mengonversi CameraImage ke InputImage.", isError: true);
        _isProcessing.value = false;
        return;
      }
      
      final List<Pose> poses = await _poseDetector.processImage(inputImage); 
      
      if (poses.isNotEmpty) {
        _detectedPoses.assignAll(poses); // Update Obx di view
        // Get.log("Pose terdeteksi: ${poses.length}, landmark pertama: ${poses.first.landmarks.length}");
        await _analyzePose(poses.first); // Analisis pose pertama yang terdeteksi
      } else {
        _detectedPoses.clear(); // Kosongkan jika tidak ada pose
        // Update UI jika tidak ada pose
        // _predictionLabel.value = 'Tidak ada pose';
        // _confidence.value = 0.0;
        // _currentAction.value = 'Menunggu pose...';
      }
    } catch (e) {
      _handleError('Error saat memproses frame kamera', e);
    } finally {
      _isProcessing.value = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (image.planes.isEmpty) {
      Get.log("CameraImage tidak memiliki planes.", isError: true);
      return null;
    }

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final imageRotation = _getRotation(_cameraController.description.sensorOrientation);

    final InputImageFormat inputImageFormat;
    if (image.format.group == ImageFormatGroup.yuv420) {
        inputImageFormat = InputImageFormat.nv21;
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
        inputImageFormat = InputImageFormat.bgra8888;
    } else {
        Get.log("Format gambar tidak didukung: ${image.format.group}", isError: true);
        return null;
    }
    
    if (image.planes[0].bytesPerRow == 0 && image.format.group == ImageFormatGroup.yuv420) {
        Get.log("Peringatan: bytesPerRow untuk plane pertama adalah 0. Ini mungkin menyebabkan masalah.", isError: true);
    }

    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );
    
    // Get.log("InputImage dibuat: Size=${imageSize}, Rotation=${imageRotation}, Format=${inputImageFormat}, BytesPerRow=${image.planes[0].bytesPerRow}");
    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  InputImageRotation _getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0: return InputImageRotation.rotation0deg;
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:
        Get.log('Orientasi sensor tidak diketahui: $sensorOrientation, default ke 0deg');
        return InputImageRotation.rotation0deg;
    }
  }

  List<double> _extractPoseFeatures(Pose pose) {
    List<double> landmarkData = [];
    // Iterasi melalui semua tipe landmark yang mungkin (33 untuk model full body MediaPipe)
    for (PoseLandmarkType type in PoseLandmarkType.values) { 
        final landmark = pose.landmarks[type];
        if (landmark != null) {
            // Normalisasi sudah dilakukan oleh MLKit (output 0.0 - 1.0 relatif terhadap gambar)
            landmarkData.add(landmark.x);
            landmarkData.add(landmark.y);
            landmarkData.add(landmark.z); // Z juga dinormalisasi, bisa jadi penting
            if (USE_VISIBILITY_SCORE) {
              landmarkData.add(landmark.likelihood ?? 0.0); // Tambahkan jika model Anda menggunakannya
            }
        } else {
            // Jika landmark tidak terdeteksi, pad dengan 0.0
            // Ini penting agar panjang vektor fitur selalu konsisten
            landmarkData.add(0.0);
            landmarkData.add(0.0);
            landmarkData.add(0.0);
            if (USE_VISIBILITY_SCORE) {
              landmarkData.add(0.0);
            }
        }
    }
    // Get.log("Fitur diekstrak (jumlah: ${landmarkData.length}): $landmarkData"); // Untuk debug
    return landmarkData;
  }


  Future<void> _analyzePose(Pose pose) async {
    final features = _extractPoseFeatures(pose);

    if (features.length != EXPECTED_FEATURE_LENGTH) {
      Get.log("Kesalahan panjang fitur! Diharapkan: $EXPECTED_FEATURE_LENGTH, Didapat: ${features.length}", isError: true);
      _predictionLabel.value = 'Error Fitur';
      _confidence.value = 0.0;
      _currentAction.value = 'Error ekstraksi fitur';
      return;
    }

    // Bentuk input untuk TFLite. Umumnya [1, jumlah_fitur] untuk list yang diratakan.
    // Jika model Anda mengharapkan shape seperti [1, 33, 3] (misalnya, 1 batch, 33 landmark, 3 koordinat),
    // Anda perlu me-reshape 'features' di sini. Contoh:
    // final input = [List.generate(33, (i) => features.sublist(i * 3, (i * 3) + (USE_VISIBILITY_SCORE ? 4 : 3)))];
    // Untuk sekarang, kita asumsikan input diratakan:
    final input = [features]; 

    // Bentuk output: [1, jumlah_kelas]. Di sini jumlah_kelas adalah 2.
    final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);

    try {
      _interpreter.run(input, output);
      // Get.log("Output mentah TFLite: ${output[0]}"); // Untuk debug
    } catch (e) {
      _handleError("Error saat inferensi TFLite", e);
      _predictionLabel.value = 'Error Inferensi';
      _confidence.value = 0.0;
      return;
    }
    
    final List<double> confidences = output[0]; // output[0] akan menjadi [prob_kelas1, prob_kelas2]
    
    if (confidences.length != _labels.length) {
        Get.log("Kesalahan panjang output! Diharapkan: ${_labels.length}, Didapat: ${confidences.length}", isError: true);
        _predictionLabel.value = 'Error Output';
        _confidence.value = 0.0;
        return;
    }

    double maxConfidence = 0.0;
    int predictedIndex = -1;

    for (int i = 0; i < confidences.length; i++) {
      if (confidences[i] > maxConfidence) {
        maxConfidence = confidences[i];
        predictedIndex = i;
      }
    }
    
    // Get.log("Prediksi: Label='${_labels[predictedIndex]}', Confidence=${maxConfidence.toStringAsFixed(2)}");

    if (predictedIndex == -1) {
        _predictionLabel.value = 'Tidak ada prediksi';
        _confidence.value = 0.0;
        _currentAction.value = 'Deteksi tidak pasti';
        return;
    }
    
    _confidence.value = maxConfidence; // Selalu update confidence

    if (maxConfidence < _confidenceThreshold) {
      _predictionLabel.value = 'Kurang yakin'; // Atau _labels[predictedIndex]
      _currentAction.value = 'Deteksi kurang yakin (${_labels[predictedIndex]})';
    } else {
      _predictionLabel.value = _labels[predictedIndex]; // "Gerak" atau "Tidak Gerak"
      _currentAction.value = '${_labels[predictedIndex]} terdeteksi';
    }
  }

  void _handleError(String message, dynamic error) {
    Get.log('$message: $error', isError: true);
    if (Get.isSnackbarOpen ?? false) return; 
    Get.snackbar(
      'Error',
      '$message: ${error.toString()}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4), // Sedikit lebih lama untuk error
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    Get.log('DetectionController onClose dipanggil');
    _isInitialized.value = false;
    
    // Pastikan controller kamera sudah diinisialisasi sebelum mencoba menghentikan stream atau dispose
    if (_cameraController.value.isInitialized) {
      if (_cameraController.value.isStreamingImages) {
        _cameraController.stopImageStream().catchError((e) {
          Get.log('Error saat menghentikan image stream: $e', isError: true);
        });
      }
      _cameraController.dispose();
    }
    
    // _poseDetector dan _interpreter diinisialisasi dalam try-catch, jadi mungkin belum ada
    // Namun, jika ada, mereka harus ditutup.
    // Untuk Interpreter, tidak ada metode close() eksplisit di tflite_flutter versi baru,
    // instance akan di-handle oleh garbage collector.
    // Namun, PoseDetector memiliki close().
    _poseDetector.close();
    // _interpreter.close(); // Jika versi lama atau ada metode close()
    
    Get.log('Sumber daya dibersihkan.');
    super.onClose();
  }
}