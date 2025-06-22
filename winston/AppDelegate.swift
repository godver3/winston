//
//  AppDelegate.swift
//  winston
//
//  Created by Igor Marcossi on 31/07/23.
//

import Foundation
import UIKit
import SwiftUI
import AVKit
import AVFoundation
import Nuke
import CoreHaptics
import Firebase

class AppDelegate: UIResponder, UIApplicationDelegate {
  static private(set) var instance: AppDelegate! = nil
  var supportsHaptics: Bool = false
  
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    AppDelegate.instance = self
    let hapticCapability = CHHapticEngine.capabilitiesForHardware()
    supportsHaptics = hapticCapability.supportsHaptics
    
    NotificationCenter.default.addObserver(forName: UIScene.willEnterForegroundNotification, object: nil, queue: nil) { (_) in
      setAudioToMixWithOthers()
    }
    
    FirebaseApp.configure()
    
    return true
  }
    
  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    
    if let shortcutItem = options.shortcutItem {
      shortcutItemToProcess = shortcutItem
    }
    
    let sceneConfiguration = UISceneConfiguration(name: "Custom Configuration", sessionRole: connectingSceneSession.role)
    sceneConfiguration.delegateClass = CustomSceneDelegate.self
    
    return sceneConfiguration
  }
    
}

class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
  func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    shortcutItemToProcess = shortcutItem
  }
}

public func setAudioToMixWithOthers() {
	do {
		let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.playback, mode: AVAudioSession.Mode.default, options: [.mixWithOthers])
    try audioSession.setActive(true)
    print("[AUDIO] Set session to mix with others")
	} catch {
		print("[AUDIO] Error setting audio session to mix with others")
	}
}
