import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pose_fluent/app/modules/detection/controllers/detection_controller.dart';
import 'package:pose_fluent/app/modules/detection/views/pose_painter_view.dart'; // Make sure this path is correct

class DetectionView extends GetView<DetectionController> {
  const DetectionView({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller if not already (though GetX usually handles this with Get.put)
    // Get.put(DetectionController()); // Ensure controller is available

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildBody(), // Changed to _buildBody for clarity
      floatingActionButton: _buildConfidenceFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildActionBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'Pose Detection',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.white, // Ensure text is visible on dark appbar
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.black87,
      elevation: 0,
      actions: [_buildCameraSwitchButton()],
      iconTheme: const IconThemeData(color: Colors.white), // For back button if any
    );
  }

  Widget _buildCameraSwitchButton() {
    return Obx(
      () => IconButton(
        icon: Icon(
          Icons.switch_camera,
          color: controller.isProcessing || !controller.isInitialized ? Colors.grey : Colors.white,
        ),
        onPressed: (controller.isProcessing || !controller.isInitialized) ? null : controller.switchCamera,
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (!controller.isInitialized) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing camera and model...',
                style: GoogleFonts.montserrat(color: Colors.white70),
              ),
            ],
          ),
        );
      }
      if (!controller.cameraController.value.isInitialized) {
        return Center(
          child: Text(
            'Camera not available or failed to initialize.',
            style: GoogleFonts.montserrat(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Center( // Center the CameraPreview
            child: AspectRatio( // Maintain aspect ratio
              aspectRatio: controller.cameraController.value.aspectRatio,
              child: CameraPreview(controller.cameraController),
            ),
          ),
          _buildPoseOverlay(),
          _buildPredictionLabel(),
        ],
      );
    });
  }

  Widget _buildPoseOverlay() {
    return Obx(() {
      // THIS IS THE FIX: Access a reactive property of detectedPoses
      // to ensure Obx rebuilds when detectedPoses changes.
      final _ = controller.detectedPoses.length; 

      // Only paint if there are poses to avoid unnecessary paints
      if (controller.detectedPoses.isNotEmpty) {
        return CustomPaint(
          painter: PosePainter(
            controller.detectedPoses,
            // Pass camera preview size for accurate coordinate mapping if needed by painter
            // This assumes PosePainter can take previewSize. If not, adjust PosePainter.
            // previewSize: Size(
            //   controller.cameraController.value.previewSize?.height ?? Get.width, // MLKit uses landscape
            //   controller.cameraController.value.previewSize?.width ?? Get.height,
            // ),
            // imageRotation: controller.cameraController.description.sensorOrientation,
          ),
          child: Container(), // Important to have a child for CustomPaint
        );
      }
      return const SizedBox.shrink(); // Return an empty widget if no poses
    });
  }

  Widget _buildPredictionLabel() {
    return Obx(
      () => Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 20), // Adjusted margin
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjusted padding
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            controller.predictionLabel,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 20, // Slightly smaller for better fit
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceFab() {
    return Obx(
      () => controller.isInitialized // Only show FAB if initialized
          ? FloatingActionButton.extended(
              onPressed: null, // Not interactive, just display
              backgroundColor: _getConfidenceColor(controller.confidence),
              label: Text(
                '${(controller.confidence * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              icon: Icon(
                _getConfidenceIcon(controller.confidence),
                color: Colors.white,
              ),
            )
          : const SizedBox.shrink(), // Hide if not initialized
    );
  }

  Widget _buildActionBar() {
    return Obx(
      () => Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade800,
              width: 0.5, // Thinner border
            ),
          ),
        ),
        child: Center(
          child: Text(
            controller.currentAction,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green.shade700;
    if (confidence > 0.4) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  IconData _getConfidenceIcon(double confidence) {
    if (confidence > 0.7) return Icons.check_circle_outline;
    if (confidence > 0.4) return Icons.warning_amber_outlined;
    return Icons.error_outline;
  }
}