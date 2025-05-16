import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;

  PosePainter(this.poses);

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 6.0
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final pose in poses) {
      // Draw landmarks
      for (final landmark in pose.landmarks.values) {
        canvas.drawCircle(
          Offset(landmark.x * size.width, landmark.y * size.height),
          8,
          jointPaint..color = _getLandmarkColor(landmark.type),
        );
      }

      // Draw basic connections (bisa tambah lainnya)
      _drawConnection(canvas, size, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, linePaint);
      _drawConnection(canvas, size, pose, PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder, linePaint);
    }
  }

  void _drawConnection(Canvas canvas, Size size, Pose pose,
      PoseLandmarkType type1, PoseLandmarkType type2, Paint paint) {
    final landmark1 = pose.landmarks[type1];
    final landmark2 = pose.landmarks[type2];
    if (landmark1 != null && landmark2 != null) {
      canvas.drawLine(
        Offset(landmark1.x * size.width, landmark1.y * size.height),
        Offset(landmark2.x * size.width, landmark2.y * size.height),
        paint,
      );
    }
  }

  Color _getLandmarkColor(PoseLandmarkType type) {
    switch (type) {
      case PoseLandmarkType.nose:
        return Colors.red;
      case PoseLandmarkType.leftWrist:
      case PoseLandmarkType.rightWrist:
        return Colors.yellow;
      default:
        return Colors.blue;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
