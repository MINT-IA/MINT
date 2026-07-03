import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
#if DEBUG || targetEnvironment(simulator)
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "MintRuntimeArgsPlugin"
    ) {
      let channel = FlutterMethodChannel(
        name: "ch.mint.app/runtime_args",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "launchArguments" {
          result(ProcessInfo.processInfo.arguments)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
#endif
  }
}
