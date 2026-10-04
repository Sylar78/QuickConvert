import Flutter
import UIKit
import GoogleMobileAds

// Ce fichier suit le cycle de vie classique d'UIApplicationDelegate, celui de
// la version de Flutter que le projet utilise (voir FLUTTER_VERSION dans les
// workflows). Il portait auparavant `FlutterImplicitEngineDelegate` et un
// `SceneDelegate`, un modele introduit par une version bien plus recente :
// ces types n'existent pas dans l'embarque iOS d'ici, et la compilation
// s'arretait dessus. Ne les reintroduire qu'avec la montee de Flutter.
@main
@objc class AppDelegate: FlutterAppDelegate {
  // Fichiers recus par « Ouvrir avec » / « Partager » (types declares dans
  // Info.plist), copies dans le dossier temporaire puis remis au code Dart
  // par ce canal : voir lib/services/shared_files_service.dart.
  private var sharedChannel: FlutterMethodChannel?
  private var pendingShared: [[String: Any]] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    GADMobileAds.sharedInstance().start(completionHandler: nil)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "fr.quickconvert.app/partage",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "takeSharedFiles" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self?.pendingShared ?? [])
        self?.pendingShared = []
      }
      sharedChannel = channel
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Les liens `quickconvert://` et ceux des modules restent a Flutter.
    guard url.isFileURL else {
      return super.application(app, open: url, options: options)
    }
    if let file = copySharedFile(url) {
      pendingShared = [file]
      sharedChannel?.invokeMethod("sharedFilesAvailable", arguments: nil)
    }
    return true
  }

  // Avec LSSupportsOpeningDocumentsInPlace, le fichier peut rester a sa place
  // d'origine (iCloud, autre app) : on y accede le temps de le copier.
  private func copySharedFile(_ url: URL) -> [String: Any]? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let manager = FileManager.default
    let dir = manager.temporaryDirectory.appendingPathComponent("partages", isDirectory: true)
    try? manager.removeItem(at: dir)
    do {
      try manager.createDirectory(at: dir, withIntermediateDirectories: true)
      let target = dir.appendingPathComponent(url.lastPathComponent)
      try manager.copyItem(at: url, to: target)
      let attributes = try? manager.attributesOfItem(atPath: target.path)
      let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
      return ["path": target.path, "name": url.lastPathComponent, "size": size]
    } catch {
      return nil
    }
  }
}
