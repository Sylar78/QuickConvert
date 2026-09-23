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
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    GADMobileAds.sharedInstance().start(completionHandler: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
