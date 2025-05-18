import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;

  PosePainter(this.poses);

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.8)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.lightGreenAccent.withOpacity(0.9)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final pose in poses) {
      _drawConnections(canvas, size, pose, linePaint);
      _drawJoints(canvas, size, pose, jointPaint);
    }
  }

  void _drawJoints(Canvas canvas, Size canvasSize, Pose pose, Paint paint) {
    for (final landmark in pose.landmarks.values) {
      final Offset point = Offset(landmark.x * canvasSize.width, landmark.y * canvasSize.height);
      canvas.drawCircle(
        point,
        6, 
        paint..color = _getLandmarkColor(landmark.type).withOpacity(paint.color.opacity),
      );
    }
  }

  void _drawConnections(Canvas canvas, Size canvasSize, Pose pose, Paint paint) {
    final Map<PoseLandmarkType, PoseLandmark> landmarks = pose.landmarks;

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final PoseLandmark? lm1 = landmarks[type1];
      final PoseLandmark? lm2 = landmarks[type2];
      if (lm1 != null && lm2 != null) {
        final Offset p1 = Offset(lm1.x * canvasSize.width, lm1.y * canvasSize.height);
        final Offset p2 = Offset(lm2.x * canvasSize.width, lm2.y * canvasSize.height);
        canvas.drawLine(p1, p2, paint);
      }
    }

    // Body
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);

    // Arms
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    
    // Legs
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // Face (simplified) - CORRECTED LINES:
    if (landmarks.containsKey(PoseLandmarkType.leftMouth) && landmarks.containsKey(PoseLandmarkType.rightMouth)) {
        drawLine(PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth);
    }
  }


  Color _getLandmarkColor(PoseLandmarkType type) {
    switch (type) {
      case PoseLandmarkType.nose: return Colors.redAccent;
      case PoseLandmarkType.leftEyeInner:
      case PoseLandmarkType.leftEye:
      case PoseLandmarkType.leftEyeOuter:
      case PoseLandmarkType.rightEyeInner:
      case PoseLandmarkType.rightEye:
      case PoseLandmarkType.rightEyeOuter: return Colors.lightBlueAccent;
      case PoseLandmarkType.leftEar:
      case PoseLandmarkType.rightEar: return Colors.pinkAccent;
      // CORRECTED LINES:
      case PoseLandmarkType.leftMouth: 
      case PoseLandmarkType.rightMouth: return Colors.orangeAccent;

      case PoseLandmarkType.leftShoulder:
      case PoseLandmarkType.rightShoulder: return Colors.deepPurpleAccent;
      case PoseLandmarkType.leftHip:
      case PoseLandmarkType.rightHip: return Colors.indigoAccent;

      case PoseLandmarkType.leftElbow:
      case PoseLandmarkType.rightElbow: return Colors.cyanAccent;
      case PoseLandmarkType.leftWrist:
      case PoseLandmarkType.rightWrist: return Colors.yellowAccent;

      case PoseLandmarkType.leftPinky:
      case PoseLandmarkType.rightPinky:
      case PoseLandmarkType.leftIndex:
      case PoseLandmarkType.rightIndex:
      case PoseLandmarkType.leftThumb:
      case PoseLandmarkType.rightThumb: return Colors.limeAccent;

      case PoseLandmarkType.leftKnee:
      case PoseLandmarkType.rightKnee: return Colors.tealAccent;
      case PoseLandmarkType.leftAnkle:
      case PoseLandmarkType.rightAnkle: return Colors.amberAccent;
      
      case PoseLandmarkType.leftHeel:
      case PoseLandmarkType.rightHeel:
      case PoseLandmarkType.leftFootIndex:
      case PoseLandmarkType.rightFootIndex: return Colors.brown;
      
      default:
        return Colors.greenAccent;
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses;
  }
}