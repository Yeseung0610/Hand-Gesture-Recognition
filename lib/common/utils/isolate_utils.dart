import 'dart:developer';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:hand_gesture_recognition/domain/entity/hand_entity.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'image_utils.dart';

class IsolateUtils {
  Isolate? _isolate;
  late SendPort _sendPort;
  late ReceivePort _receivePort;

  SendPort get sendPort => _sendPort;

  Future<void> initIsolate() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn<SendPort>(
      _entryPoint,
      _receivePort.sendPort,
    );

    _sendPort = await _receivePort.first;
  }

  static void _entryPoint(SendPort mainSendPort) async {
    log('IN ISOLATE');

    final childReceivePort = ReceivePort();
    mainSendPort.send(childReceivePort.sendPort);

    await for (final IsolateData? isolateData in childReceivePort) {
      if (isolateData != null) {
        final interpreter = Interpreter.fromAddress(isolateData.interpreterAddress);
        final hand = HandEntity(interpreter: interpreter);
        final image = ImageUtils.convertCameraImageToImage(isolateData.cameraImage);

        final results = hand.predict(image);
        isolateData.responsePort.send(results);
      }
    }
  }

  void dispose() {
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

class IsolateData {
  CameraImage cameraImage;
  int interpreterAddress;
  SendPort responsePort;

  IsolateData({
    required this.cameraImage,
    required this.interpreterAddress,
    required this.responsePort,
  });
}