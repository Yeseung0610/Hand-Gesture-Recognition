import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_gesture_recognition/presentation/provider/tensorflow_provider.dart';
import 'package:hand_gesture_recognition/presentation/screen/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProviderContainer().read(tensorflowProvider).loadModel();

  runApp(const HandGestureRecognitionApplication());
}

class HandGestureRecognitionApplication extends StatelessWidget {
  const HandGestureRecognitionApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}
