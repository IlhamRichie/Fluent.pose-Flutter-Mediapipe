import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_fluent/app/modules/detection/controllers/detection_controller.dart';
import 'package:pose_fluent/app/modules/detection/views/pose_painter_view.dart';

class DetectionView extends GetView<DetectionController> {
  const DetectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Deteksi Pose',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Obx(() => IconButton(
                icon: Icon(
                  Icons.switch_camera,
                  color: controller.isProcessing.value ? Colors.grey : Colors.white,
                ),
                onPressed: controller.isProcessing.value ? null : controller.switchCamera,
              )),
        ],
      ),
      body: Obx(() {
        if (!controller.isInitialized.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          children: [
            CameraPreview(controller.cameraController),
            _buildPoseOverlay(),
            _buildPredictionLabel(),
          ],
        );
      }),
      floatingActionButton: Obx(() => FloatingActionButton(
            onPressed: null,
            backgroundColor: _getConfidenceColor(controller.confidence.value),
            child: Text(
              '${(controller.confidence.value * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white),
            ),
          )),
    );
  }

  Widget _buildPoseOverlay() {
    return Obx(() => CustomPaint(
          painter: PosePainter(controller.detectedPoses),
          child: Container(),
        ));
  }

  Widget _buildPredictionLabel() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Obx(() => Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black54,
            child: Text(
              controller.predictionLabel.value,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              textAlign: TextAlign.center,
            ),
          )),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.4) return Colors.orange;
    return Colors.red;
  }
}
