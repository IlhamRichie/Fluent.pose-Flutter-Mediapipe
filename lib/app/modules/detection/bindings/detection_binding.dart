import 'package:get/get.dart';
import '../controllers/detection_controller.dart';

class DetectionBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DetectionController>(
      () => DetectionController(),
      fenix: true,
    );
  }
}