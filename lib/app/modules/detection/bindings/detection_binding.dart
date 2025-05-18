import 'package:get/get.dart';
import 'package:pose_fluent/app/modules/detection/controllers/detection_controller.dart';

class DetectionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DetectionController>(
      () => DetectionController(),
      fenix: true, // Allows recreation when needed
    );
  }
}