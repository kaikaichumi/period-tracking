import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:period_tracking/utils/constants.dart';

void main() {
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

  test('iOS 採用 UIScene 生命週期', () {
    // Apps built with the iOS 27 SDK fail to launch without a scene manifest.
    expect(infoPlist, contains('<string>FlutterSceneDelegate</string>'));
  });

  test(
    'iOS 的 Google 登入網址配置和用戶端 ID 一致',
    () {
      // Google Sign-In crashes the app when this URL scheme is missing.
      final reversedClientId =
          AppConstants.googleIosClientId.split('.').reversed.join('.');
      expect(infoPlist, contains('<string>$reversedClientId</string>'));
    },
    skip: AppConstants.googleIosClientId.isEmpty
        ? 'iOS 尚未設定 Google 用戶端 ID'
        : false,
  );
}
