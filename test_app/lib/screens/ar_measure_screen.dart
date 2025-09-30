import 'dart:math' as math;

import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class ARMeasureScreen extends StatefulWidget {
  const ARMeasureScreen({super.key});

  @override
  State<ARMeasureScreen> createState() => _ARMeasureScreenState();
}

class _ARMeasureScreenState extends State<ARMeasureScreen> {
  ArCoreController? _arCoreController;
  double? _distanceMeters;

  @override
  void dispose() {
    _arCoreController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesurer la distance (AR)')),
      body: ArCoreView(
        onArCoreViewCreated: _onArCoreViewCreated,
        enablePlaneRenderer: true,
        enableTapRecognizer: false,
      ),
    );
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    _arCoreController = controller;
    // Automatically compute distance on first detected plane point
    _arCoreController!.onPlaneDetected = (ArCorePlane plane) async {
      final Vector3? p = plane.centerPose?.translation;
      if (p == null || _distanceMeters != null) return;
      // Place a tiny marker for user feedback
      final material = ArCoreMaterial(color: Colors.redAccent);
      final sphere = ArCoreSphere(materials: [material], radius: 0.01);
      final node = ArCoreNode(shape: sphere, position: p, name: 'auto_marker');
      await _arCoreController!.addArCoreNode(node);
      final double d = await _computeDistanceToCamera(p);
      setState(() => _distanceMeters = d);
      if (mounted) {
        Navigator.of(context).pop(d);
      }
    };
  }

  double _distanceFromOrigin(Vector3? v) {
    if (v == null) return double.infinity;
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z).abs();
  }

  Future<double> _computeDistanceToCamera(Vector3 hitTranslation) async {
    try {
      // In ARCore world coordinates, the camera is at origin in view space, but here we
      // approximate distance by vector length from origin as many examples do.
      // If camera pose becomes available via the controller in the future, use that.
      return _distanceFromOrigin(hitTranslation);
    } catch (_) {
      return _distanceFromOrigin(hitTranslation);
    }
  }
}
