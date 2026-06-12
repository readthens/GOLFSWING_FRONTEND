import 'package:flutter/services.dart';

class NativeCaptureCapabilities {
  const NativeCaptureCapabilities({
    required this.highFpsCaptureAvailable,
    this.nativeCaptureAvailable = false,
    this.trustedAutoCaptureAvailable = false,
    this.diagnosticOnly = true,
    this.deviceTier = 'D',
    this.deviceModel,
    this.systemVersion,
    this.preferredMode,
    this.selectedFormat = const {},
    this.supportedFormats = const [],
  });

  factory NativeCaptureCapabilities.fromJson(Map<dynamic, dynamic> json) {
    return NativeCaptureCapabilities(
      highFpsCaptureAvailable: json['highFpsCaptureAvailable'] == true,
      nativeCaptureAvailable: json['nativeCaptureAvailable'] == true,
      trustedAutoCaptureAvailable:
          json['trustedAutoCaptureAvailable'] == true,
      diagnosticOnly: json['diagnosticOnly'] != false,
      deviceTier: json['deviceTier'] as String? ?? 'D',
      deviceModel: json['deviceModel'] as String?,
      systemVersion: json['systemVersion'] as String?,
      preferredMode: json['preferredMode'] as String?,
      selectedFormat: _mapFromJson(json['selectedFormat']),
      supportedFormats: _listOfMapsFromJson(json['supportedFormats']),
    );
  }

  final bool highFpsCaptureAvailable;
  final bool nativeCaptureAvailable;
  final bool trustedAutoCaptureAvailable;
  final bool diagnosticOnly;
  final String deviceTier;
  final String? deviceModel;
  final String? systemVersion;
  final String? preferredMode;
  final Map<String, dynamic> selectedFormat;
  final List<Map<String, dynamic>> supportedFormats;

  bool get trustedForTracer =>
      nativeCaptureAvailable && trustedAutoCaptureAvailable && !diagnosticOnly;
  String get readinessLabel {
    if (trustedForTracer && deviceTier == 'A') return 'HIGH FPS READY';
    if (trustedForTracer) return 'STANDARD READY';
    return 'DIAGNOSTIC ONLY';
  }
}

class NativeTracerCaptureResult {
  const NativeTracerCaptureResult({
    required this.filePath,
    required this.diagnostics,
  });

  factory NativeTracerCaptureResult.fromJson(Map<dynamic, dynamic> json) {
    return NativeTracerCaptureResult(
      filePath: json['filePath'] as String? ?? '',
      diagnostics: _mapFromJson(json['diagnostics']),
    );
  }

  final String filePath;
  final Map<String, dynamic> diagnostics;
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

  Future<Map<String, dynamic>> startTracerCapture() async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'startTracerCapture',
    );
    return _mapFromJson(response);
  }

  Future<NativeTracerCaptureResult> stopTracerCapture() async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'stopTracerCapture',
    );
    return NativeTracerCaptureResult.fromJson(response ?? const {});
  }

  Future<Map<String, dynamic>> getCurrentCaptureDiagnostics() async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'getCurrentCaptureDiagnostics',
    );
    return _mapFromJson(response);
  }
}

Map<String, dynamic> _mapFromJson(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMapsFromJson(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(_mapFromJson).toList(growable: false);
}
