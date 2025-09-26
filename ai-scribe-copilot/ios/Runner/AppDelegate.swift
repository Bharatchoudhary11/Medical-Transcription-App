import AVFoundation
import CallKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler, CXCallObserverDelegate {
  private let methodChannelName = "ai_scribe_copilot/mic"
  private let eventChannelName = "ai_scribe_copilot/interruption"
  private var eventSink: FlutterEventSink?
  private let audioSession = AVAudioSession.sharedInstance()
  private let callObserver = CXCallObserver()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: controller.binaryMessenger)
    methodChannel.setMethodCallHandler(handle)

    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: controller.binaryMessenger)
    eventChannel.setStreamHandler(self)

    configureAudioSession()
    callObserver.setDelegate(self, queue: nil)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "setGain":
      if let gain = (call.arguments as? [String: Any])?["gain"] as? Double {
        setInputGain(gain: gain)
      }
      result(nil)
    case "requestFocus":
      requestAudioFocus()
      result(nil)
    case "abandonFocus":
      abandonAudioFocus()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configureAudioSession() {
    do {
      try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers])
      try audioSession.setPreferredSampleRate(16_000)
      try audioSession.setPreferredIOBufferDuration(0.02)
    } catch {
      NSLog("Failed to configure audio session: \(error)")
    }
  }

  private func setInputGain(gain: Double) {
    guard audioSession.isInputGainSettable else { return }
    do {
      try audioSession.setInputGain(Float(min(max(gain, 0.0), 1.0)))
    } catch {
      NSLog("Failed to set input gain: \(error)")
    }
  }

  private func requestAudioFocus() {
    do {
      try audioSession.setActive(true, options: [])
    } catch {
      NSLog("Failed to activate audio session: \(error)")
    }
  }

  private func abandonAudioFocus() {
    do {
      try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
    } catch {
      NSLog("Failed to deactivate audio session: \(error)")
    }
  }

  @objc private func handleInterruption(_ notification: Notification) {
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }
    switch type {
    case .began:
      emitEvent(type: "audioFocusLost")
    case .ended:
      emitEvent(type: "audioFocusGained")
    @unknown default:
      break
    }
  }

  private func emitEvent(type: String) {
    DispatchQueue.main.async {
      self.eventSink?(["type": type])
    }
  }

  // MARK: - FlutterStreamHandler
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - CXCallObserverDelegate
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    if call.hasEnded {
      emitEvent(type: "phoneCallEnded")
    } else if call.isOutgoing || call.hasConnected {
      emitEvent(type: "phoneCallStarted")
    }
  }
}
