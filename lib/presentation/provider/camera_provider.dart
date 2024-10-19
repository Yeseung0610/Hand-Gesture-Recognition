
import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/utils/isolate_utils.dart';

final cameraProvider = StateNotifierProvider<CameraStateNotifier, CameraState>((ref) => CameraStateNotifier(CameraState()));

class CameraStateNotifier extends StateNotifier<CameraState> {
  CameraStateNotifier(super.state);

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    final newCamera = cameras[1];
    await _onNewCameraSelected(newCamera);
  }

  Future<void> _onNewCameraSelected(CameraDescription newCamera) async {
    state = state.copyWith(
      cameraDescription: AsyncValue.data(newCamera),
      controller: AsyncValue.data(CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      )),
    );

    try {
      await state.controller.value!.initialize();
      state = state.copyWith(isInitialized: true);
    } on CameraException catch (e, t) {
      log('CameraException', error: e, stackTrace: t);
    }
  }

  void startCameraStream(void Function(CameraImage image) callback) {
    state.controller.value!.startImageStream(callback);
  }

  void stopCameraStream() {
    state.controller.value!.stopImageStream();
  }
}

class CameraState {

  final AsyncValue<CameraController> controller;

  final AsyncValue<CameraDescription> _cameraDescription;

  final bool isInitialized;

  bool draw;

  CameraState({
    this.controller = const AsyncValue.loading(),
    AsyncValue<CameraDescription> cameraDescription = const AsyncValue.loading(),
    this.isInitialized = false,
    this.draw = false,
  }): _cameraDescription = cameraDescription;

  CameraState copyWith({
    AsyncValue<CameraController>? controller,
    AsyncValue<CameraDescription>? cameraDescription,
    bool? isInitialized,
    bool? draw,
  }) => CameraState(
    controller: controller ?? this.controller,
    cameraDescription: cameraDescription ?? _cameraDescription,
    isInitialized: isInitialized ?? this.isInitialized,
    draw: draw ?? this.draw,
  );
}