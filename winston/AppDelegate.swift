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
import MediaPlayer

class AppDelegate: UIResponder, UIApplicationDelegate {
  static private(set) var instance: AppDelegate! = nil
  var supportsHaptics: Bool = false
  
  static var orientationLock = UIInterfaceOrientationMask.portrait
      
  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
      return AppDelegate.orientationLock
  }
  
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    AppDelegate.instance = self
    let hapticCapability = CHHapticEngine.capabilitiesForHardware()
    supportsHaptics = hapticCapability.supportsHaptics
    
    // Configure audio session immediately
    AudioSessionManager.shared.configureAudioSession()
    
    // Handle scene lifecycle changes
    NotificationCenter.default.addObserver(
        forName: UIScene.willEnterForegroundNotification,
        object: nil,
        queue: .main
    ) { _ in
        AudioSessionManager.shared.configureAudioSession()
    }
    
    // Handle audio session interruptions
    NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: .main
    ) { notification in
        self.handleAudioInterruption(notification)
    }
    
    FirebaseApp.configure()
    
    Task {
      performSeenPostCleanup()
    }
    
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
  
  private func handleAudioInterruption(_ notification: Notification) {
     guard let info = notification.userInfo,
           let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
           let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
         return
     }
     
     switch type {
     case .began:
         print("[AUDIO] Interruption began")
     case .ended:
         guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
         let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
         if options.contains(.shouldResume) {
             AudioSessionManager.shared.configureAudioSession()
         }
     @unknown default:
         break
     }
 }
  
  func performSeenPostCleanup() {
      SeenSubredditManager.shared.cleanupOldPosts()
      getCleanupStatistics()
  }
  
  /// Get cleanup statistics
  func getCleanupStatistics() {
      let stats = SeenSubredditManager.shared.getSeenPostsStatistics()
      print("Seen posts statistics:")
      print("- Total subreddits: \(stats.totalSubreddits)")
      print("- Total posts: \(stats.totalPosts)")
      print("- Old posts (>7 days): \(stats.oldPosts)")
  }
    
}

class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
  func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    shortcutItemToProcess = shortcutItem
  }
}

class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private init() {}
    
    func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Use ambient category for background mixing
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            // Disable remote control events for ambient audio
            UIApplication.shared.beginReceivingRemoteControlEvents()
            MPRemoteCommandCenter.shared().playCommand.isEnabled = false
            MPRemoteCommandCenter.shared().pauseCommand.isEnabled = false
            MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = false
            MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = false
            
            print("[AUDIO] Set session to ambient with mix with others")
        } catch {
            print("[AUDIO] Error setting audio session: \(error)")
        }
    }
    
    func configureForVideoPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Keep mixing with others even in fullscreen
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("[AUDIO] Set session for video playback with mixing")
        } catch {
            print("[AUDIO] Error setting video playback session: \(error)")
        }
    }
}
