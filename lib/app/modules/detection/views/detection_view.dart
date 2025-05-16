import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/detection_controller.dart';

class DetectionView extends GetView<DetectionController> {
  const DetectionView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DetectionView'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'DetectionView is working',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
