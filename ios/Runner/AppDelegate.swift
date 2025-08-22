import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Check if app was launched from a Universal Link
    if let userActivity = launchOptions?[.userActivity] as? NSUserActivity,
       userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      // This will be handled by the Flutter app_links plugin
      print("App launched from Universal Link: \(url)")
    }
    
    GMSServices.provideAPIKey("")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle Universal Links when app is already running
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    // Handle Universal Links
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      // This will be handled by the Flutter app_links plugin
      print("App continued from Universal Link: \(url)")
      return true
    }
    return false
  }
}
