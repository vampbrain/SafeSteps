import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Google Maps before Flutter engine
    GMSServices.provideAPIKey("AIzaSyCroP5ArTzF4g5GmZdr7ml9KDlRviEQfbE")
    _ = GMSServices.sharedServices() // Force initialization
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
