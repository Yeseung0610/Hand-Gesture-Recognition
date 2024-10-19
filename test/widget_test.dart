// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_gesture_recognition/common/assets/assets.dart';

import 'package:hand_gesture_recognition/main.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 모델 파일 경로 설정
  final interpreter = await Interpreter.fromAsset(Assets.models.handLandMark);

  // 입력 텐서 정보 가져오기
  final inputTensor = interpreter.getInputTensors().first;
  log('Input Tensor Shape: ${inputTensor.shape}');
  log('Input Tensor Type: ${inputTensor.type}');

  // 출력 텐서 정보 가져오기
  for (int i = 0; i < interpreter.getOutputTensors().length; i++) {
    final outputTensor = interpreter.getOutputTensors()[i];
    log('Output Tensor $i Shape: ${outputTensor.shape}');
    log('Output Tensor $i Type: ${outputTensor.type}');
  }

  interpreter.close();
}

void main2() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HandGestureRecognitionApplication());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
