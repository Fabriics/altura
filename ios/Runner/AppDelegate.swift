import Flutter
import UIKit
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    //GMSServices.provideAPIKey("AIzaSyBB6JMMFw8Vz1MniyHuz4_iN3xQ7QbWbv8")
    // Non è necessario impostare il presentingViewController qui
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
