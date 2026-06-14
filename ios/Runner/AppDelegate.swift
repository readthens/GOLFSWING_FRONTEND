import AVFoundation
import CoreMedia
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var captureChannel: FlutterMethodChannel?
  private let nativeCaptureBridge = NativeCaptureBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeCaptureBridge") else {
      return
    }
    captureChannel = FlutterMethodChannel(
      name: "com.readthens.swinglensai/capture",
      binaryMessenger: registrar.messenger()
    )
    captureChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "getCaptureCapabilities":
        result(self.nativeCaptureBridge.getCaptureCapabilities())
      case "startTracerCapture":
        self.nativeCaptureBridge.startTracerCapture(arguments: call.arguments, result: result)
      case "stopTracerCapture":
        self.nativeCaptureBridge.stopTracerCapture(result: result)
      case "getCurrentCaptureDiagnostics":
        result(self.nativeCaptureBridge.currentDiagnostics())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

final class NativeCaptureBridge: NSObject, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let sessionQueue = DispatchQueue(label: "com.readthens.swinglensai.nativeCapture.session")
  private let sampleQueue = DispatchQueue(label: "com.readthens.swinglensai.nativeCapture.samples")
  private var session: AVCaptureSession?
  private var movieOutput: AVCaptureMovieFileOutput?
  private var videoDataOutput: AVCaptureVideoDataOutput?
  private var selectedDevice: AVCaptureDevice?
  private var selectedFormat: NativeCaptureFormat?
  private var outputURL: URL?
  private var pendingStartResult: FlutterResult?
  private var pendingStopResult: FlutterResult?
  private var sampleCount = 0
  private var droppedFrameCount = 0
  private var firstSampleTime: CMTime?
  private var lastSampleTime: CMTime?
  private var recordingStartedAt: Date?
  private var lastError: String?
  private var localTracer = NativeTracerState()

  func getCaptureCapabilities() -> [String: Any] {
    let formats = supportedFormats()
    let best = formats.first
    let tier = tier(for: best)
    return [
      "platform": "ios",
      "nativeCaptureAvailable": best != nil,
      "highFpsCaptureAvailable": (best?.targetFps ?? 0) >= 120,
      "trustedAutoCaptureAvailable": (best?.targetFps ?? 0) >= 120,
      "deviceTier": tier,
      "deviceModel": deviceModelIdentifier(),
      "systemVersion": UIDevice.current.systemVersion,
      "selectedFormat": best?.toDictionary() as Any,
      "supportedFormats": formats.map { $0.toDictionary() },
      "preferredMode": best?.label ?? "diagnostic",
      "diagnosticOnly": (best?.targetFps ?? 0) < 120
    ]
  }

  func startTracerCapture(arguments: Any?, result: @escaping FlutterResult) {
    sessionQueue.async {
      if self.movieOutput?.isRecording == true {
        DispatchQueue.main.async {
          result(FlutterError(code: "already_recording", message: "Native tracer capture is already recording.", details: nil))
        }
        return
      }
      do {
        try self.configureSession()
        guard let session = self.session, let movieOutput = self.movieOutput else {
          throw NativeCaptureError.configurationFailed("Native capture session was not created.")
        }
        self.resetSampleCounters(arguments: arguments)
        if !session.isRunning {
          session.startRunning()
        }
        let outputURL = self.makeOutputURL()
        self.outputURL = outputURL
        self.recordingStartedAt = Date()
        self.pendingStartResult = result
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "native_capture_start_failed", message: "\(error)", details: nil))
        }
      }
    }
  }

  func stopTracerCapture(result: @escaping FlutterResult) {
    sessionQueue.async {
      guard let movieOutput = self.movieOutput, movieOutput.isRecording else {
        DispatchQueue.main.async {
          result(FlutterError(code: "not_recording", message: "Native tracer capture is not recording.", details: nil))
        }
        return
      }
      self.pendingStopResult = result
      movieOutput.stopRecording()
    }
  }

  func currentDiagnostics() -> [String: Any] {
    var diagnostics = baseDiagnostics()
    diagnostics["isRecording"] = movieOutput?.isRecording == true
    diagnostics["lastError"] = lastError as Any
    return diagnostics
  }

  func fileOutput(
    _ output: AVCaptureFileOutput,
    didStartRecordingTo fileURL: URL,
    from connections: [AVCaptureConnection]
  ) {
    let payload: [String: Any] = [
      "started": true,
      "filePath": fileURL.path,
      "diagnostics": currentDiagnostics()
    ]
    DispatchQueue.main.async {
      self.pendingStartResult?(payload)
      self.pendingStartResult = nil
    }
  }

  func fileOutput(
    _ output: AVCaptureFileOutput,
    didFinishRecordingTo outputFileURL: URL,
    from connections: [AVCaptureConnection],
    error: Error?
  ) {
    sessionQueue.async {
      self.session?.stopRunning()
      if let error {
        self.lastError = "\(error)"
      }
      var diagnostics = self.baseDiagnostics()
      diagnostics["isRecording"] = false
      diagnostics["lastError"] = self.lastError as Any
      let localResult = diagnostics["localTracerResult"] as? [String: Any] ?? [:]
      let payload: [String: Any] = [
        "filePath": outputFileURL.path,
        "diagnostics": diagnostics,
        "localResult": localResult
      ]
      DispatchQueue.main.async {
        if let error {
          self.pendingStopResult?(
            FlutterError(code: "native_capture_finish_failed", message: "\(error)", details: diagnostics)
          )
        } else {
          self.pendingStopResult?(payload)
        }
        self.pendingStopResult = nil
      }
    }
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if firstSampleTime == nil {
      firstSampleTime = timestamp
    }
    lastSampleTime = timestamp
    sampleCount += 1
    updateLocalTracer(sampleBuffer: sampleBuffer, timestamp: timestamp)
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didDrop sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    droppedFrameCount += 1
  }

  private func configureSession() throws {
    let format = try selectedCaptureFormat()
    let device = format.device
    let session = AVCaptureSession()
    session.beginConfiguration()
    session.sessionPreset = .inputPriority
    try configureDevice(device, format: format)

    let videoInput = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(videoInput) else {
      throw NativeCaptureError.configurationFailed("Unable to add rear camera input.")
    }
    session.addInput(videoInput)

    if let audioDevice = AVCaptureDevice.default(for: .audio),
       let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
       session.canAddInput(audioInput) {
      session.addInput(audioInput)
    }

    let movieOutput = AVCaptureMovieFileOutput()
    guard session.canAddOutput(movieOutput) else {
      throw NativeCaptureError.configurationFailed("Unable to add movie output.")
    }
    session.addOutput(movieOutput)
    if let connection = movieOutput.connection(with: .video), connection.isVideoStabilizationSupported {
      connection.preferredVideoStabilizationMode = .auto
    }

    let dataOutput = AVCaptureVideoDataOutput()
    dataOutput.alwaysDiscardsLateVideoFrames = false
    dataOutput.setSampleBufferDelegate(self, queue: sampleQueue)
    if session.canAddOutput(dataOutput) {
      session.addOutput(dataOutput)
    }

    session.commitConfiguration()
    self.session = session
    self.movieOutput = movieOutput
    self.videoDataOutput = dataOutput
    self.selectedDevice = device
    self.selectedFormat = format
    self.lastError = nil
  }

  private func configureDevice(_ device: AVCaptureDevice, format: NativeCaptureFormat) throws {
    try device.lockForConfiguration()
    device.activeFormat = format.format
    let frameDuration = CMTime(value: 1, timescale: CMTimeScale(format.targetFps.rounded()))
    device.activeVideoMinFrameDuration = frameDuration
    device.activeVideoMaxFrameDuration = frameDuration
    if device.isFocusModeSupported(.locked) {
      device.focusMode = .locked
    }
    if device.isExposureModeSupported(.locked) {
      device.exposureMode = .locked
    }
    if device.isWhiteBalanceModeSupported(.locked) {
      device.whiteBalanceMode = .locked
    }
    device.unlockForConfiguration()
  }

  private func updateLocalTracer(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    let frameTimestampMs = timestampMs(timestamp) ?? 0
    if let candidate = brightCandidate(in: pixelBuffer, timestampMs: frameTimestampMs) {
      localTracer.update(candidate: candidate, sampleCount: sampleCount)
    } else if localTracer.impactTimestampMs == nil {
      localTracer.trackingState = "waiting_for_impact"
    }
  }

  private func brightCandidate(in pixelBuffer: CVPixelBuffer, timestampMs: Int) -> NativeTracerPoint? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
    let width = planeCount > 0 ? CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) : CVPixelBufferGetWidth(pixelBuffer)
    let height = planeCount > 0 ? CVPixelBufferGetHeightOfPlane(pixelBuffer, 0) : CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow: Int
    let baseAddress: UnsafeMutableRawPointer?
    if planeCount > 0 {
      bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
      baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
    } else {
      bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
      baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    }
    guard width > 0, height > 0, bytesPerRow > 0, let baseAddress else {
      return nil
    }

    let anchor = localTracer.guide.ballAnchor
    let previous = localTracer.ballPath.last ?? localTracer.lastCandidate
    let centerX = localTracer.impactTimestampMs == nil ? Double(anchor.x) : (previous?.x ?? Double(anchor.x))
    let centerY = localTracer.impactTimestampMs == nil ? Double(anchor.y) : (previous?.y ?? Double(anchor.y))
    let radiusX = localTracer.impactTimestampMs == nil ? 0.16 : 0.28
    let radiusY = localTracer.impactTimestampMs == nil ? 0.16 : 0.28
    let minX = max(0, Int((centerX - radiusX) * Double(width)))
    let maxX = min(width - 1, Int((centerX + radiusX) * Double(width)))
    let minY = max(0, Int((centerY - radiusY) * Double(height)))
    let maxY = min(height - 1, Int((centerY + radiusY) * Double(height)))
    guard minX < maxX, minY < maxY else {
      return nil
    }

    let stride = max(2, min(width, height) / 120)
    let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
    var bestValue = 0
    var bestX = minX
    var bestY = minY
    var y = minY
    while y <= maxY {
      let row = buffer + y * bytesPerRow
      var x = minX
      while x <= maxX {
        let value = Int(row[x])
        if value > bestValue {
          bestValue = value
          bestX = x
          bestY = y
        }
        x += stride
      }
      y += stride
    }
    guard bestValue >= 185 else {
      return nil
    }
    return NativeTracerPoint(
      x: Double(bestX) / Double(width),
      y: Double(bestY) / Double(height),
      timestampMs: timestampMs,
      confidence: min(1.0, Double(bestValue) / 255.0)
    )
  }

  private func selectedCaptureFormat() throws -> NativeCaptureFormat {
    guard let format = supportedFormats().first else {
      throw NativeCaptureError.configurationFailed("No rear high-FPS capture format is available.")
    }
    return format
  }

  private func supportedFormats() -> [NativeCaptureFormat] {
    let deviceTypes: [AVCaptureDevice.DeviceType] = [
      .builtInWideAngleCamera,
      .builtInTripleCamera,
      .builtInDualWideCamera,
      .builtInDualCamera,
      .builtInUltraWideCamera,
      .builtInTelephotoCamera
    ]
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: deviceTypes,
      mediaType: .video,
      position: .back
    )
    return discovery.devices.flatMap { device in
      device.formats.compactMap { format -> NativeCaptureFormat? in
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let ranges = format.videoSupportedFrameRateRanges
        guard let maxFps = ranges.map({ $0.maxFrameRate }).max(), maxFps >= 60 else {
          return nil
        }
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)
        let targetFps = maxFps >= 239 ? 240.0 : maxFps >= 119 ? 120.0 : 60.0
        return NativeCaptureFormat(
          device: device,
          format: format,
          width: width,
          height: height,
          maxFps: maxFps,
          targetFps: targetFps
        )
      }
    }
    .sorted { lhs, rhs in
      if lhs.priority != rhs.priority {
        return lhs.priority > rhs.priority
      }
      if lhs.targetFps != rhs.targetFps {
        return lhs.targetFps > rhs.targetFps
      }
      return lhs.width * lhs.height > rhs.width * rhs.height
    }
  }

  private func baseDiagnostics() -> [String: Any] {
    let counts = sampleQueue.sync {
      (
        sampleCount: sampleCount,
        droppedFrameCount: droppedFrameCount,
        firstSampleTime: firstSampleTime,
        lastSampleTime: lastSampleTime,
        localTracer: localTracer.toDictionary()
      )
    }
    let measuredFps = measuredFramesPerSecond(
      sampleCount: counts.sampleCount,
      firstSampleTime: counts.firstSampleTime,
      lastSampleTime: counts.lastSampleTime
    )
    let format = selectedFormat
    var diagnostics: [String: Any] = [
      "source": "avfoundation",
      "deviceModel": deviceModelIdentifier(),
      "systemVersion": UIDevice.current.systemVersion,
      "deviceTier": tier(for: format),
      "formatLabel": format?.label as Any,
      "targetFps": format?.targetFps as Any,
      "measuredFps": measuredFps as Any,
      "width": format?.width as Any,
      "height": format?.height as Any,
      "lensPosition": "back",
      "lensDeviceType": selectedDevice?.deviceType.rawValue as Any,
      "stabilizationSupported": movieOutput?.connection(with: .video)?.isVideoStabilizationSupported == true,
      "focusLocked": selectedDevice?.focusMode == .locked,
      "exposureLocked": selectedDevice?.exposureMode == .locked,
      "whiteBalanceLocked": selectedDevice?.whiteBalanceMode == .locked,
      "exposureDurationSeconds": selectedDevice?.exposureDuration.seconds as Any,
      "iso": selectedDevice?.iso as Any,
      "sampleCount": counts.sampleCount,
      "droppedFrameCount": counts.droppedFrameCount,
      "firstFrameTimestampMs": timestampMs(counts.firstSampleTime) as Any,
      "lastFrameTimestampMs": timestampMs(counts.lastSampleTime) as Any,
      "startedAtMs": recordingStartedAt.map { Int($0.timeIntervalSince1970 * 1000) } as Any
    ]
    diagnostics["localTracerResult"] = counts.localTracer
    diagnostics["trackingState"] = counts.localTracer["trackingState"]
    diagnostics["impactTimestampMs"] = counts.localTracer["impactTimestampMs"]
    diagnostics["confidence"] = counts.localTracer["confidence"]
    diagnostics["ballPath"] = counts.localTracer["ballPath"]
    return diagnostics
  }

  private func resetSampleCounters(arguments: Any?) {
    let guide = NativeTracerGuide(arguments: arguments)
    sampleQueue.sync {
      sampleCount = 0
      droppedFrameCount = 0
      firstSampleTime = nil
      lastSampleTime = nil
      localTracer = NativeTracerState(guide: guide)
    }
  }

  private func measuredFramesPerSecond(
    sampleCount: Int,
    firstSampleTime: CMTime?,
    lastSampleTime: CMTime?
  ) -> Double? {
    guard sampleCount > 1,
          let firstSampleTime,
          let lastSampleTime else {
      return nil
    }
    let duration = CMTimeGetSeconds(CMTimeSubtract(lastSampleTime, firstSampleTime))
    guard duration > 0 else {
      return nil
    }
    return Double(sampleCount - 1) / duration
  }

  private func timestampMs(_ time: CMTime?) -> Int? {
    guard let time else {
      return nil
    }
    return Int(CMTimeGetSeconds(time) * 1000)
  }

  private func makeOutputURL() -> URL {
    let filename = "swinglens_tracer_\(UUID().uuidString).mov"
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
    try? FileManager.default.removeItem(at: url)
    return url
  }

  private func tier(for format: NativeCaptureFormat?) -> String {
    guard let format else {
      return "D"
    }
    if format.targetFps >= 240 || format.label == "4K120" {
      return "A"
    }
    if format.targetFps >= 120 {
      return "B"
    }
    if format.targetFps >= 60 {
      return "C"
    }
    return "D"
  }

  private func deviceModelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    return mirror.children.reduce(into: "") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else {
        return
      }
      identifier.append(String(UnicodeScalar(UInt8(bitPattern: value))))
    }
  }
}

private struct NativeCaptureFormat {
  let device: AVCaptureDevice
  let format: AVCaptureDevice.Format
  let width: Int
  let height: Int
  let maxFps: Double
  let targetFps: Double

  var label: String {
    let shortEdge = min(width, height)
    let longEdge = max(width, height)
    if shortEdge >= 2160 && targetFps >= 120 {
      return "4K120"
    }
    if shortEdge >= 1080 && targetFps >= 240 {
      return "1080p240"
    }
    if shortEdge >= 1080 && targetFps >= 120 {
      return "1080p120"
    }
    if shortEdge >= 2160 && targetFps >= 60 {
      return "4K60"
    }
    return "\(longEdge)x\(shortEdge)@\(Int(targetFps))"
  }

  var priority: Int {
    switch label {
    case "1080p240":
      return 5
    case "4K120":
      return 4
    case "1080p120":
      return 3
    case "4K60":
      return 2
    default:
      return targetFps >= 60 ? 1 : 0
    }
  }

  func toDictionary() -> [String: Any] {
    [
      "label": label,
      "width": width,
      "height": height,
      "maxFps": maxFps,
      "targetFps": targetFps,
      "deviceType": device.deviceType.rawValue,
      "localizedName": device.localizedName
    ]
  }
}

private struct NativeTracerGuide {
  let ballAnchor: CGPoint
  let targetPoint: CGPoint

  init(arguments: Any? = nil) {
    let payload = arguments as? [String: Any] ?? [:]
    let ballPayload = payload["ball_anchor"] as? [String: Any] ?? [:]
    let targetLine = payload["target_line"] as? [String: Any] ?? [:]
    let targetPayload = targetLine["end"] as? [String: Any] ?? [:]
    ballAnchor = CGPoint(
      x: CGFloat(NativeTracerGuide.normalized(ballPayload["x"], fallback: 0.5)),
      y: CGFloat(NativeTracerGuide.normalized(ballPayload["y"], fallback: 0.78))
    )
    targetPoint = CGPoint(
      x: CGFloat(NativeTracerGuide.normalized(targetPayload["x"], fallback: 0.5)),
      y: CGFloat(NativeTracerGuide.normalized(targetPayload["y"], fallback: 0.28))
    )
  }

  private static func normalized(_ value: Any?, fallback: Double) -> Double {
    let number: Double
    if let value = value as? Double {
      number = value
    } else if let value = value as? NSNumber {
      number = value.doubleValue
    } else if let value = value as? String, let parsed = Double(value) {
      number = parsed
    } else {
      number = fallback
    }
    return min(1.0, max(0.0, number))
  }
}

private struct NativeTracerPoint {
  let x: Double
  let y: Double
  let timestampMs: Int
  let confidence: Double

  func distance(to point: CGPoint) -> Double {
    let dx = x - Double(point.x)
    let dy = y - Double(point.y)
    return sqrt(dx * dx + dy * dy)
  }

  func distance(to point: NativeTracerPoint) -> Double {
    let dx = x - point.x
    let dy = y - point.y
    return sqrt(dx * dx + dy * dy)
  }

  func toDictionary() -> [String: Any] {
    [
      "x": round(x * 10_000) / 10_000,
      "y": round(y * 10_000) / 10_000,
      "timestamp_ms": timestampMs,
      "confidence": round(confidence * 1_000) / 1_000
    ]
  }
}

private struct NativeTracerState {
  var guide = NativeTracerGuide()
  var trackingState = "idle"
  var impactTimestampMs: Int?
  var ballPath: [NativeTracerPoint] = []
  var lastCandidate: NativeTracerPoint?

  init(guide: NativeTracerGuide = NativeTracerGuide()) {
    self.guide = guide
    trackingState = "waiting_for_impact"
  }

  mutating func update(candidate: NativeTracerPoint, sampleCount: Int) {
    lastCandidate = candidate
    if impactTimestampMs == nil {
      trackingState = "waiting_for_impact"
      guard sampleCount >= 8 else {
        return
      }
      if candidate.distance(to: guide.ballAnchor) >= 0.035 {
        impactTimestampMs = candidate.timestampMs
        trackingState = "impact_detected"
        ballPath = [
          NativeTracerPoint(
            x: Double(guide.ballAnchor.x),
            y: Double(guide.ballAnchor.y),
            timestampMs: max(0, candidate.timestampMs - 12),
            confidence: candidate.confidence
          ),
          candidate
        ]
      }
      return
    }

    guard let impactTimestampMs else {
      return
    }
    let elapsed = candidate.timestampMs - impactTimestampMs
    if elapsed > 1_400 {
      trackingState = "tracking_complete"
      return
    }
    if let lastPoint = ballPath.last {
      let enoughTime = candidate.timestampMs - lastPoint.timestampMs >= 24
      let enoughDistance = candidate.distance(to: lastPoint) >= 0.01
      if !enoughTime && !enoughDistance {
        trackingState = "tracking_live"
        return
      }
    }
    ballPath.append(candidate)
    if ballPath.count > 70 {
      ballPath.removeFirst(ballPath.count - 70)
    }
    trackingState = "tracking_live"
  }

  func toDictionary() -> [String: Any] {
    let confidences = ballPath.map { $0.confidence }
    let confidence: Double? = confidences.isEmpty
      ? nil
      : confidences.reduce(0, +) / Double(confidences.count)
    var payload: [String: Any] = [
      "trackingState": trackingState,
      "tracking_state": trackingState,
      "ballPath": ballPath.map { $0.toDictionary() },
      "ball_path": ballPath.map { $0.toDictionary() },
      "metrics": [
        "path_source": "client_phone",
        "processing_mode": "phone",
        "detector_version": "phone_local_v1",
        "visual_only": true,
        "not_launch_monitor": true
      ],
      "style": ["name": "signature"]
    ]
    if let impactTimestampMs {
      payload["impactTimestampMs"] = impactTimestampMs
      payload["impact_timestamp_ms"] = impactTimestampMs
    }
    if let confidence {
      payload["confidence"] = round(confidence * 1_000) / 1_000
    }
    return payload
  }
}

private enum NativeCaptureError: Error {
  case configurationFailed(String)
}
