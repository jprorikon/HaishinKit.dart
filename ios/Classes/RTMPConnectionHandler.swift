import Foundation
import Flutter
import HaishinKit

class RTMPConnectionHandler: NSObject, MethodCallHandler {
    var instance: RTMPConnection?
    private let plugin: SwiftHaishinKitPlugin
    private var channel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var shouldSendSpeedStatistics: Bool = false

    init(plugin: SwiftHaishinKitPlugin) {
        self.plugin = plugin
        super.init()
        let id = Int(bitPattern: ObjectIdentifier(self))
        if let messanger = plugin.registrar?.messenger() {
            self.channel = FlutterEventChannel(name: "com.haishinkit.eventchannel/\(id)", binaryMessenger: messanger)
        } else {
            self.channel = nil
        }
        instance = RTMPConnection()
        instance?.addEventListener(.rtmpStatus, selector: #selector(handler), observer: self)
        instance?.addEventListener(.ioError, selector: #selector(handler), observer: self)
        channel?.setStreamHandler(self)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "RtmpConnection#connect":
            guard
                let arguments = call.arguments as? [String: Any?],
                let command = arguments["command"] as? String else {
                return
            }
            instance?.connect(command)
            startSendSpeedStatistics()
        case "RtmpConnection#close":
            instance?.close()
            stopSendSpeedStatistics()
        case "RtmpConnection#dispose":
            instance = nil
            plugin.onDispose(id: Int(bitPattern: ObjectIdentifier(self)))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startSendSpeedStatistics() {
        shouldSendSpeedStatistics = true
        DispatchQueue.global().async {
            while self.eventSink != nil && self.shouldSendSpeedStatistics {
                var map: [String: Any?] = [:]
                var data: [String: Any?] = [:]
                data["code"] = "SpeedStatistics"
                // get current speed
                data["outSpeedInByte"] = self.instance?.currentBytesOutPerSecond
                data["inSpeedInByte"] = self.instance?.currentBytesInPerSecond
                map["data"] = data
                self.eventSink?(map)
                Thread.sleep(forTimeInterval: 1) // send every 1 second
            }
        }
    }

    private func stopSendSpeedStatistics() {
        shouldSendSpeedStatistics = false
    }

    @objc
    private func handler(_ notification: Notification) {
        let event = Event.from(notification)
        var map: [String: Any?] = [:]
        map["type"] = event.type.rawValue
        map["data"] = ASObjectUtil.removeEmpty(event.data)
        eventSink?(map)
    }
}

extension RTMPConnectionHandler: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}
