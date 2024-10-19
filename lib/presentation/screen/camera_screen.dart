import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_gesture_recognition/presentation/provider/camera_provider.dart';
import 'package:hand_gesture_recognition/presentation/provider/tensorflow_provider.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => CameraScreenState();
}

class CameraScreenState extends ConsumerState<CameraScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final cameraProviderNotifier = ref.read(cameraProvider.notifier);
      final tensorflowProviderNotifier = ref.read(tensorflowProvider.notifier);

      await tensorflowProviderNotifier.initStateAsync();
      await cameraProviderNotifier.initCamera();
      cameraProviderNotifier.startCameraStream(tensorflowProviderNotifier.onLatestImageAvailable);
    });
  }

  @override
  void dispose() {
    super.dispose();
    final cameraProviderNotifier = ref.read(cameraProvider.notifier);
    cameraProviderNotifier.stopCameraStream();
  }

  @override
  Widget build(BuildContext context) {
    final cameraController = ref.watch(cameraProvider).controller.value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraController != null
          ? CameraPreview(cameraController)
          : Container(),
    );
  }
}