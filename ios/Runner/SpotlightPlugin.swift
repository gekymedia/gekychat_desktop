import CoreSpotlight
import Flutter
import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

/// Indexes chats into iOS Spotlight and opens gekychat:// links when tapped.
final class SpotlightPlugin: NSObject, FlutterPlugin {
  private static let channelName = "gekychat/spotlight"
  private static let activityType = "com.gekychat.openChat"

  private var channel: FlutterMethodChannel?
  private var pendingOpenLink: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SpotlightPlugin()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.publish(instance)
  }

  /// Shared instance for AppDelegate to forward Spotlight / universal opens.
  static weak var shared: SpotlightPlugin?

  override init() {
    super.init()
    SpotlightPlugin.shared = self
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "indexItems":
      guard let args = call.arguments as? [String: Any],
            let items = args["items"] as? [[String: Any]] else {
        result(FlutterError(code: "bad_args", message: "items required", details: nil))
        return
      }
      let domain = (args["domain"] as? String) ?? "com.gekychat.spotlight"
      indexItems(items, domain: domain, result: result)

    case "deleteAll":
      let domain = (call.arguments as? [String: Any])?["domain"] as? String
        ?? "com.gekychat.spotlight"
      CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { error in
        if let error {
          result(FlutterError(code: "delete_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }

    case "getPendingOpen":
      let link = pendingOpenLink
      pendingOpenLink = nil
      result(link)

    case "donateOpen":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String,
            let title = args["title"] as? String,
            let link = args["link"] as? String else {
        result(FlutterError(code: "bad_args", message: "id/title/link required", details: nil))
        return
      }
      donateOpen(id: id, title: title, link: link)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func indexItems(_ items: [[String: Any]], domain: String, result: @escaping FlutterResult) {
    var searchable: [CSSearchableItem] = []

    for item in items {
      guard let id = item["id"] as? String,
            let title = item["title"] as? String,
            let link = item["link"] as? String else { continue }

      let attributes = CSSearchableItemAttributeSet(contentType: .text)
      attributes.title = title
      attributes.displayName = title
      attributes.contentDescription = item["subtitle"] as? String
      if let keywords = item["keywords"] as? [String] {
        attributes.keywords = keywords
      }
      attributes.identifier = id

      let searchableItem = CSSearchableItem(
        uniqueIdentifier: id,
        domainIdentifier: domain,
        attributeSet: attributes
      )
      searchable.append(searchableItem)
    }

    let index = CSSearchableIndex.default()
    index.deleteSearchableItems(withDomainIdentifiers: [domain]) { deleteError in
      if let deleteError {
        NSLog("Spotlight delete before reindex: \(deleteError.localizedDescription)")
      }
      index.indexSearchableItems(searchable) { error in
        if let error {
          result(FlutterError(code: "index_failed", message: error.localizedDescription, details: nil))
        } else {
          result(["count": searchable.count])
        }
      }
    }
  }

  private func donateOpen(id: String, title: String, link: String) {
    let activity = NSUserActivity(activityType: SpotlightPlugin.activityType)
    activity.title = title
    activity.isEligibleForSearch = true
    activity.isEligibleForPrediction = true
    activity.persistentIdentifier = id
    activity.userInfo = ["link": link, "id": id]
    activity.becomeCurrent()
  }

  /// Called from AppDelegate when user taps a Spotlight result.
  func handleSpotlightUserInfo(_ userInfo: [AnyHashable: Any]?) {
    guard let userInfo else { return }

    if let id = userInfo[CSSearchableItemActivityIdentifier] as? String,
       let link = linkFromUniqueId(id) {
      deliverOpen(link: link)
      return
    }

    if let link = userInfo["link"] as? String {
      deliverOpen(link: link)
    }
  }

  private func linkFromUniqueId(_ id: String) -> String? {
    if id.hasPrefix("chat:") {
      let raw = String(id.dropFirst("chat:".count))
      return "gekychat://chat/\(raw)"
    }
    if id.hasPrefix("group:") {
      let raw = String(id.dropFirst("group:".count))
      return "gekychat://group/\(raw)"
    }
    return nil
  }

  private func deliverOpen(link: String) {
    pendingOpenLink = link
    channel?.invokeMethod("onOpen", arguments: ["link": link])
  }
}
