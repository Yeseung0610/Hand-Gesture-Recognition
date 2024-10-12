import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_gesture_recognition/presentation/provider/camera_provider.dart';

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
      await cameraProviderNotifier.initProvider();
      cameraProviderNotifier.startCameraStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraController = ref.watch(cameraProvider).controller.value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraController != null ? AspectRatio(
        aspectRatio: ref.watch(cameraProvider).controller.value!.value.aspectRatio,
        child: CameraPreview(cameraController),
      ) : Container(),
    );
  }
}