import 'dart:developer';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_gesture_recognition/domain/entity/hand_entity.dart';

import '../../common/utils/isolate_utils.dart';

final tensorflowProvider = StateNotifierProvider<TensorflowStateNotifier, TensorflowState>((ref) => TensorflowStateNotifier(TensorflowState(
  handEntity: HandEntity(),
)));

// TODO [20241012] 현재는 Provider내부에 모든 기능을 구현했음. 추후 레이어 바운더리 구분 필요 (data/data_source, data/repository_impl domain/use_case, domain/repository, presentation/provider)
class TensorflowStateNotifier extends StateNotifier<TensorflowState> {
  TensorflowStateNotifier(super.state);

  final IsolateUtils _isolateUtils = IsolateUtils();

  Future<void> initStateAsync() async {
    await _isolateUtils.initIsolate();
  }

  onLatestImageAvailable(CameraImage cameraImage) async {
    if (state.handEntity.interpreter != null && !state.predicting) {
      state = state.copyWith(predicting: true);

      final uiThreadTimeStart = DateTime.now().millisecondsSinceEpoch;
      
      final Map<String, dynamic>? inferenceResults = await _inference(
        cameraImage: cameraImage,
        interpreterAddress: state.handEntity.interpreter!.address,
      );

      final uiThreadInferenceElapsedTime = DateTime.now().millisecondsSinceEpoch - uiThreadTimeStart;

      if (inferenceResults?.containsKey('point') == true) {
        state = state.copyWith(
          handFoldPercent: _calculateHandFoldPercentage(inferenceResults!['point']),
        );
        log(state.handFoldPercent.toString());
      }

      // // pass results to HomeView
      // widget.resultsCallback(inferenceResults["recognitions"]);
      //
      // // pass stats to HomeView
      // widget.statsCallback((inferenceResults["stats"] as Stats)
      //   ..totalElapsedTime = uiThreadInferenceElapsedTime);

      state = state.copyWith(predicting: false);
    }
  }

  Future<Map<String, dynamic>?> _inference({
    required CameraImage cameraImage,
    required int interpreterAddress,
  }) async {
    final ReceivePort receivePort = ReceivePort();

    final isolateData = IsolateData(
      cameraImage: cameraImage,
      interpreterAddress: interpreterAddress,
      responsePort: receivePort.sendPort,
    );

    _isolateUtils.sendPort.send(isolateData);

    final Map<String, dynamic>? results = await receivePort.first;
    receivePort.close();

    return results;
  }

  double _calculateHandFoldPercentage(List<Offset> points) {
    if (state.initialDistance == 0.0) {
      state = state.copyWith(initialDistance: (points[1] - points[0]).distance);
    }

    final indicesToCheck = [4, 8, 12, 16, 20];

    final currentDistance = (points[1] - points[0]).distance;

    final distanceFactor = state.initialDistance / currentDistance;

    double weightedDistanceSum = 0.0;
    double weightSum = 0.0;
    double interpolationFactor = 0.5;

    for (int i = 0; i < indicesToCheck.length - 1; i++) {
      int index1 = indicesToCheck[i];
      int index2 = indicesToCheck[i + 1];

      double segmentDistance = (points[index1] - points[index2]).distance * distanceFactor;
      double weight = 1.0 / (1.0 + interpolationFactor * segmentDistance);

      weightedDistanceSum += segmentDistance * weight;
      weightSum += weight;
    }

    double averageWeightedDistance = weightedDistanceSum / weightSum;

    double maxDistance = 500.0;
    double foldPercentage = (1 - (averageWeightedDistance / maxDistance)) * 100.0;
    return foldPercentage.clamp(0.0, 100.0);
  }
}

class TensorflowState {

  final HandEntity handEntity;

  final bool predicting;

  final double initialDistance;

  final double handFoldPercent;

  TensorflowState({
    required this.handEntity,
    this.predicting = false,
    this.initialDistance = 0.0,
    this.handFoldPercent = 0.0,
  });

  TensorflowState copyWith({
    HandEntity? handEntity,
    bool? predicting,
    double? initialDistance,
    double? handFoldPercent,
  }) {
    return TensorflowState(
      handEntity: handEntity ?? this.handEntity,
      predicting: predicting ?? this.predicting,
      initialDistance: initialDistance ?? this.initialDistance,
      handFoldPercent: handFoldPercent ?? this.handFoldPercent,
    );
  }

}