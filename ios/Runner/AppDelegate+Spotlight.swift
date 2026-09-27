import Flutter
import UIKit
import CoreSpotlight

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = self.registrar(forPlugin: "SpotlightPlugin") {
      SpotlightPlugin.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if handleUserActivity(userActivity) {
      return true
    }
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }

  @discardableResult
  private func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
    if userActivity.activityType == CSSearchableItemActionType {
      SpotlightPlugin.shared?.handleSpotlightUserInfo(userActivity.userInfo)
      return true
    }
    if userActivity.activityType == "com.gekychat.openChat",
       let link = userActivity.userInfo?["link"] as? String {
      SpotlightPlugin.shared?.handleSpotlightUserInfo(["link": link])
      return true
    }
    return false
  }
}
