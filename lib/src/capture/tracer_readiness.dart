import 'package:flutter/foundation.dart';

@immutable
class TracerReadinessInput {
  const TracerReadinessInput({
    required this.cameraReady,
    required this.rearCameraActive,
    required this.guideOverlay,
    required this.ballAnchorSet,
    required this.targetLineSet,
    required this.whiteBallConfirmed,
    required this.sensorVerified,
    required this.phoneLevel,
    required this.phoneStable,
    required this.simulatorOrUnverified,
    this.ballAnchorLaunchZone = true,
    this.targetLineForward = true,
    this.stableDurationMs = 1000,
  });

  final bool cameraReady;
  final bool rearCameraActive;
  final bool guideOverlay;
  final bool ballAnchorSet;
  final bool ballAnchorLaunchZone;
  final bool targetLineSet;
  final bool targetLineForward;
  final bool whiteBallConfirmed;
  final bool sensorVerified;
  final bool phoneLevel;
  final bool phoneStable;
  final bool simulatorOrUnverified;
  final int stableDurationMs;
}

@immutable
class TracerReadinessResult {
  const TracerReadinessResult({required this.checks});

  final Map<String, bool> checks;

  bool get coreReady {
    return checks['rear_camera_active'] == true &&
        checks['guide_overlay'] == true &&
        checks['ball_anchor_set'] == true &&
        checks['ball_anchor_launch_zone'] == true &&
        checks['target_line_set'] == true &&
        checks['target_line_forward'] == true &&
        checks['white_ball_confirmed'] == true;
  }

  bool get motionReady {
    return checks['sensor_verified'] == true &&
        checks['phone_level'] == true &&
        checks['phone_stable'] == true &&
        checks['stable_duration_1s'] == true;
  }

  bool get autoEligible =>
      coreReady && motionReady && checks['simulator_or_unverified'] != true;
  bool get unverifiedTestCapture =>
      coreReady && checks['simulator_or_unverified'] == true;
  bool get canRecord => autoEligible || unverifiedTestCapture;
}

TracerReadinessResult buildTracerReadiness(TracerReadinessInput input) {
  return TracerReadinessResult(
    checks: {
      'rear_camera_active': input.cameraReady && input.rearCameraActive,
      'guide_overlay': input.guideOverlay,
      'ball_anchor_set': input.ballAnchorSet,
      'ball_anchor_launch_zone': input.ballAnchorLaunchZone,
      'target_line_set': input.targetLineSet,
      'target_line_forward': input.targetLineForward,
      'white_ball_confirmed': input.whiteBallConfirmed,
      'sensor_verified': input.sensorVerified,
      'phone_level': input.phoneLevel,
      'phone_stable': input.phoneStable,
      'stable_duration_1s': input.stableDurationMs >= 1000,
      'simulator_or_unverified':
          input.simulatorOrUnverified || !input.sensorVerified,
    },
  );
}
