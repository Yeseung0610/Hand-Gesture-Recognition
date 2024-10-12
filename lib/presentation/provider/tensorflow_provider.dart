import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_gesture_recognition/common/assets/assets.dart';
import 'package:image/image.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import "package:tflite_flutter_plus/src/bindings/types.dart" as types;
import 'package:tflite_flutter_helper_plus/tflite_flutter_helper_plus.dart';

final Provider<TensorflowProvider> tensorflowProvider = Provider((ref) => TensorflowProvider(TensorflowState()));

// TODO [20241012] 현재는 Provider내부에 모든 기능을 구현했음. 추후 레이어 바운더리 구분 필요 (data/data_source, data/repository_impl domain/use_case, domain/repository, presentation/provider)
class TensorflowProvider extends StateNotifier<TensorflowState> {

  static int inputSize = 300;
  final double existThreshold = 0.1;
  final double scoreThreshold = 0.3;

  TensorflowProvider(super.state);

  Future<void> loadModel() async {
    if (state.interpreter.hasValue) return;

    try {
      state = state.copyWith(
        interpreter: AsyncValue.data(await Interpreter.fromAsset(Assets.models.handLandMark, options: InterpreterOptions()..threads = 4))
      );

      for (var tensor in state.interpreter.value!.getOutputTensors()) {
        state.outputShapes.add(tensor.shape);
        state.outputTypes.add(tensor.type);
      }

    } catch (e, t) {
      log("TensorflowError", error: e, stackTrace: t);
    }
  }

  TensorImage getProcessedImage(TensorImage inputImage) {
    final imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputSize, inputSize, ResizeMethod.bilinear))
        .add(NormalizeOp(0, 255))
        .build();

    inputImage = imageProcessor.process(inputImage);
    return inputImage;
  }

  Map<String, dynamic>? predict(Image image) {
    if (!state.interpreter.hasValue) {
      return null;
    }

    if (Platform.isAndroid) {
      image = copyRotate(image, -90);
      image = flipHorizontal(image);
    }
    final tensorImage = TensorImage(types.TfLiteType.float32);
    tensorImage.loadImage(image);
    final inputImage = getProcessedImage(tensorImage);

    TensorBuffer outputLandmarks = TensorBufferFloat(state.outputShapes[0]);
    TensorBuffer outputExist = TensorBufferFloat(state.outputShapes[1]);
    TensorBuffer outputScores = TensorBufferFloat(state.outputShapes[2]);

    final inputs = <Object>[inputImage.buffer];

    final outputs = <int, Object>{
      0: outputLandmarks.buffer,
      1: outputExist.buffer,
      2: outputScores.buffer,
    };

    state.interpreter.value!.runForMultipleInputs(inputs, outputs);

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

  onLatestImageAvailable(CameraImage cameraImage) async {
    if (state.interpreter.hasValue && !state.predicting) {
      state = state.copyWith(predicting: true);

      var uiThreadTimeStart = DateTime.now().millisecondsSinceEpoch;

      // Data to be passed to inference isolate
      var isolateData = IsolateData(
          cameraImage, state.interpreter.value!.address, classifier.labels);

      /// perform inference in separate isolate
      Map<String, dynamic> inferenceResults = await inference(isolateData);

      var uiThreadInferenceElapsedTime =
          DateTime.now().millisecondsSinceEpoch - uiThreadTimeStart;

      // pass results to HomeView
      widget.resultsCallback(inferenceResults["recognitions"]);

      // pass stats to HomeView
      widget.statsCallback((inferenceResults["stats"] as Stats)
        ..totalElapsedTime = uiThreadInferenceElapsedTime);

      // set predicting to false to allow new frames
      setState(() {
        predicting = false;
      });
    }
  }
}

class TensorflowState {

  final AsyncValue<Interpreter> interpreter;

  final List<List<int>> outputShapes;

  final List<TensorType> outputTypes;

  bool predicting;

  TensorflowState({
    this.interpreter = const AsyncValue.loading(),
    this.outputShapes = const [],
    this.outputTypes = const [],
    this.predicting = false,
  });

  TensorflowState copyWith({
    AsyncValue<Interpreter>? interpreter,
    List<List<int>>? outputShapes,
    List<TensorType>? outputTypes,
    bool? predicting,
  }) {
    return TensorflowState(
      interpreter: interpreter ?? this.interpreter,
      outputShapes: outputShapes ?? this.outputShapes,
      outputTypes: outputTypes ?? this.outputTypes,
      predicting: predicting ?? this.predicting,
    );
  }

}