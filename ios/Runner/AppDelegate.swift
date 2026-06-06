import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var captureChannel: FlutterMethodChannel?

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
        result(["highFpsCaptureAvailable": false])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
