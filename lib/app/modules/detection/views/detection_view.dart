import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pose_fluent/app/modules/detection/controllers/detection_controller.dart';

class DetectionView extends StatelessWidget {
  const DetectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DetectionController>(
      init: DetectionController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Klasifikasi Gerak',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              Obx(() => IconButton(
                    icon: const Icon(Icons.switch_camera),
                    onPressed: controller.isProcessing.value
                        ? null
                        : controller.switchCamera,
                  )),
            ],
          ),
          body: _buildBody(controller),
        );
      },
    );
  }

  Widget _buildBody(DetectionController controller) {
    return Obx(() {
      if (!controller.isInitialized.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        children: [
          CameraPreview(controller.cameraController),
          Positioned(
            top: 16,
            left: 16,
            child: Obx(() {
              if (controller.label.value.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${controller.label.value} (${(controller.confidence.value * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ),
        ],
      );
    });
  }
}
