import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let diskChannel = FlutterMethodChannel(name: "com.lxmwaniky.inkq/disk_space",
                                              binaryMessenger: controller.binaryMessenger)
    diskChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getFreeDiskSpace" {
        do {
            let fileManager = FileManager.default
            let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = attrs[.systemFreeSize] as? Int64 {
                result(freeSpace)
            } else {
                result(FlutterError(code: "UNAVAILABLE", message: "Failed to get system free size", details: nil))
            }
        } catch {
            result(FlutterError(code: "UNAVAILABLE", message: error.localizedDescription, details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
