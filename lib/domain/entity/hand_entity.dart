import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:hand_gesture_recognition/common/assets/assets.dart';
import 'package:image/image.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper_plus/tflite_flutter_helper_plus.dart';
import "package:tflite_flutter_plus/src/bindings/types.dart" as types;

class HandEntity {

  Interpreter? interpreter;

  final List<List<int>> outputShapes = [];

  final List<TensorType> outputTypes = [];

  static const int inputSize = 224;

  static const double existThreshold = 0.1;

  static const double scoreThreshold = 0.3;

  HandEntity({this.interpreter}) {
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      interpreter ??= await Interpreter.fromAsset(Assets.models.handLandMark);

      for (var tensor in interpreter!.getOutputTensors()) {
        outputShapes.add(tensor.shape);
        outputTypes.add(tensor.type);
      }

    } catch (e, t) {
      log("TensorflowError", error: e, stackTrace: t);
    }
  }

  Map<String, dynamic>? predict(Image image) {
    if (interpreter == null) return null;

    if (Platform.isAndroid) {
      image = copyRotate(image, -90);
      image = flipHorizontal(image);
    }
    final tensorImage = TensorImage(types.TfLiteType.float32);
    tensorImage.loadImage(image);
    final inputImage = getProcessedImage(tensorImage);

    TensorBuffer outputLandmarks = TensorBufferFloat(outputShapes[0]);
    TensorBuffer outputExist = TensorBufferFloat(outputShapes[1]);
    TensorBuffer outputScores = TensorBufferFloat(outputShapes[2]);

    final inputs = <ByteBuffer>[inputImage.buffer];

    final outputs = <int, ByteBuffer>{
      0: outputLandmarks.buffer,
      1: outputExist.buffer,
      2: outputScores.buffer,
    };

    interpreter!.runForMultipleInputs(inputs, outputs);

    if (outputExist.getDoubleValue(0) < existThreshold ||
        outputScores.getDoubleValue(0) < scoreThreshold) {
      return null;
    }

    final landmarkPoints = outputLandmarks.getDoubleList().reshape([21, 3]);
    final landmarkResults = <Offset>[];
    for (var point in landmarkPoints) {
      landmarkResults.add(Offset(
        point[0] / inputSize * image.width,
        point[1] / inputSize * image.height,
      ));
    }

    return {'point': landmarkResults};
  }

  TensorImage getProcessedImage(TensorImage inputImage) {
    final imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputSize, inputSize, ResizeMethod.bilinear))
        .add(NormalizeOp(0, 255))
        .build();

    inputImage = imageProcessor.process(inputImage);
    return inputImage;
  }
}