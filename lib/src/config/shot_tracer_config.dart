enum ShotTracerProcessingMode { backend, phone }

const _shotTracerProcessingModeRaw = String.fromEnvironment(
  'SHOT_TRACER_PROCESSING_MODE',
  defaultValue: 'backend',
);

ShotTracerProcessingMode get shotTracerProcessingMode {
  final value = _shotTracerProcessingModeRaw.trim().toLowerCase();
  return switch (value) {
    'phone' ||
    'local' ||
    'on_device' ||
    'on-device' => ShotTracerProcessingMode.phone,
    _ => ShotTracerProcessingMode.backend,
  };
}

bool get shotTracerPhoneProcessingEnabled =>
    shotTracerProcessingMode == ShotTracerProcessingMode.phone;

String get shotTracerProcessingModeLabel =>
    shotTracerPhoneProcessingEnabled ? 'PHONE' : 'BACKEND';
