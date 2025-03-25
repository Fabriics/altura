import Flutter
import UIKit
import GoogleMaps
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    GMSServices.provideAPIKey("AIzaSyBB6JMMFw8Vz1MniyHuz4_iN3xQ7QbWbv8")

    // Imposta il presenting view controller per Google Sign-In
    if let rootVC = window?.rootViewController {
      // Se necessario, configura il clientID (ad esempio, se non lo stai già ottenendo da Firebase)
      // GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "YOUR_CLIENT_ID")
      GIDSignIn.sharedInstance.presentingViewController = rootVC
      print("Presenting view controller impostato: \(rootVC)")
    } else {
      print("Root view controller non trovato!")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
