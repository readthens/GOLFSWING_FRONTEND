import 'package:flutter/services.dart';

class NativeCaptureCapabilities {
  const NativeCaptureCapabilities({required this.highFpsCaptureAvailable});

  factory NativeCaptureCapabilities.fromJson(Map<dynamic, dynamic> json) {
    return NativeCaptureCapabilities(
      highFpsCaptureAvailable: json['highFpsCaptureAvailable'] == true,
    );
  }

  final bool highFpsCaptureAvailable;
}

class NativeCaptureBridge {
  const NativeCaptureBridge();

  static const _channel = MethodChannel('com.readthens.swinglensai/capture');

  Future<NativeCaptureCapabilities> getCaptureCapabilities() async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'getCaptureCapabilities',
    );
    return NativeCaptureCapabilities.fromJson(response ?? const {});
  }
}
