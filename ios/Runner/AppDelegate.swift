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
        self.nativeCaptureBridge.startTracerCapture(result: result)
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

  func startTracerCapture(result: @escaping FlutterResult) {
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
        self.resetSampleCounters()
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
      let payload: [String: Any] = [
        "filePath": outputFileURL.path,
        "diagnostics": diagnostics
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
        sampleCount,
        droppedFrameCount,
        firstSampleTime,
        lastSampleTime
      )
    }
    let measuredFps = measuredFramesPerSecond(
      sampleCount: counts.0,
      firstSampleTime: counts.2,
      lastSampleTime: counts.3
    )
    let format = selectedFormat
    return [
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
      "sampleCount": counts.0,
      "droppedFrameCount": counts.1,
      "firstFrameTimestampMs": timestampMs(counts.2) as Any,
      "lastFrameTimestampMs": timestampMs(counts.3) as Any,
      "startedAtMs": recordingStartedAt.map { Int($0.timeIntervalSince1970 * 1000) } as Any
    ]
  }

  private func resetSampleCounters() {
    sampleQueue.sync {
      sampleCount = 0
      droppedFrameCount = 0
      firstSampleTime = nil
      lastSampleTime = nil
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

private enum NativeCaptureError: Error {
  case configurationFailed(String)
}
