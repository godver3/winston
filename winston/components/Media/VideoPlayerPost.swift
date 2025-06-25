import SwiftUI
import Defaults
import CoreMedia
import AVKit
import AVFoundation
import Combine

// MARK: - Updated SharedVideo with AVQueuePlayer
class SharedVideo: ObservableObject, Equatable {
  static func == (lhs: SharedVideo, rhs: SharedVideo) -> Bool {
    lhs.url == rhs.url && lhs.id == rhs.id && lhs.queuePlayer.currentItem == rhs.queuePlayer.currentItem
  }
  
  var queuePlayer: AVQueuePlayer
  var url: URL
  var id: String
  var size: CGSize
  var key: String
  private var playerLooper: AVPlayerLooper?
  
  static func get(url: URL, size: CGSize, resetCache: Bool = false, prevVideoId: String? = nil) -> SharedVideo {
    
    if resetCache {
      let cacheKey = SharedVideo.cacheKey(url: url, size: size)
      Caches.videos.cache.removeValue(forKey: cacheKey)
    }
    
    let sharedVideo = SharedVideo(url: url, size: size)
    
    if let prevVideoId {
      Nav.shared.currVideos[sharedVideo.id] = Nav.shared.currVideos[prevVideoId]
      Nav.shared.currVideos[prevVideoId] = nil
    }
    
    return sharedVideo
  }

  static func cacheKey(url: URL, size: CGSize) -> String {
    return "\(url.absoluteString):\(size.width)x\(size.height)"
  }
  
  init(url: URL, size: CGSize) {
    self.url = url
    self.id = randomString(length: 12)
    self.size = size
    self.key = SharedVideo.cacheKey(url: url, size: size)
    
    // Initialize empty queue player
    self.queuePlayer = AVQueuePlayer()
    
    if let asset = Caches.videos.get(key: self.key) {
      print("[VID] RETRIEVED FROM CACHE \(url.absoluteString)")
      let playerItem = AVPlayerItem(asset: asset)
      self.queuePlayer.insert(playerItem, after: nil)
    } else {
      if NetworkMonitor.shared.connectedToWifi {
        let playerItem = AVPlayerItem(url: url)
        self.queuePlayer.insert(playerItem, after: nil)
        
        // Cache the asset once it's loaded
        Caches.videos.addKeyValue(key: self.key, data: { playerItem.asset }, expires: Date().dateByAdding(1, .day).date)
      }
    }
    
    self.queuePlayer.volume = 0.0
    self.queuePlayer.isMuted = true
  }
  
  // MARK: - Enhanced Loading with Better Error Handling
  func loadIfNeeded() {
    // Check if we already have a valid item
    if queuePlayer.currentItem != nil && queuePlayer.status != .failed {
      return
    }
    
    Task(priority: .high) {
      do {
        // Clear any failed items first
        await MainActor.run {
          if queuePlayer.items().contains(where: { $0.status == .failed }) {
            queuePlayer.removeAllItems()
          }
        }
        
        // Wait for asset to load
        let asset = AVURLAsset(url: self.url)
        let (duration, tracks, isPlayable) = try await asset.load(.duration, .tracks, .isPlayable)
        
        guard isPlayable else {
          print("[VID] Asset not playable: \(self.url)")
          return
        }
        
        // Cache the asset
        Caches.videos.addKeyValue(key: self.key, data: { asset }, expires: Date().dateByAdding(1, .day).date)
        
        let playerItem = AVPlayerItem(asset: asset)
        
        await MainActor.run {
          // Clear queue if it has failed items
          if queuePlayer.items().contains(where: { $0.status == .failed }) {
            queuePlayer.removeAllItems()
          }
          
          // Add new item if queue is empty
          if queuePlayer.items().isEmpty {
            queuePlayer.insert(playerItem, after: nil)
          }
        }
        
        print("[VID] Successfully loaded asset: \(self.url)")
        
      } catch {
        print("[VID] Failed to load asset: \(error)")
        
        // Fallback: try direct URL loading
        await MainActor.run {
          if queuePlayer.items().isEmpty {
            let fallbackItem = AVPlayerItem(url: self.url)
            queuePlayer.insert(fallbackItem, after: nil)
          }
        }
      }
    }
  }
  
  // MARK: - Looping Support
  func enableLooping() {
    guard let currentItem = queuePlayer.currentItem else { return }
    
    // Remove existing looper
    playerLooper = nil
    
    // Create new looper
    playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: currentItem)
  }
  
  func disableLooping() {
    playerLooper = nil
  }
  
  // MARK: - Queue Management
  func replaceCurrentItem(with newItem: AVPlayerItem) {
    queuePlayer.removeAllItems()
    queuePlayer.insert(newItem, after: nil)
  }
  
  func hasValidItem() -> Bool {
    return queuePlayer.currentItem != nil && queuePlayer.currentItem?.status != .failed
  }
}

struct VideoPlayerPost: View, Equatable {
  static func == (lhs: VideoPlayerPost, rhs: VideoPlayerPost) -> Bool {
    lhs.url == rhs.url && lhs.sharedVideo?.id == rhs.sharedVideo?.id
  }
  
  var controller: UIViewController?
  var sharedVideo: SharedVideo?
  let markAsSeen: (() async -> ())?
  var compact = false
  var contentWidth: CGFloat
  var url: URL
  var size: CGSize
  let resetVideo: ((SharedVideo) -> ())?
  var maxMediaHeightScreenPercentage: CGFloat
  
  @State private var firstFullscreen = false
  @State private var fullscreen = false
  @State private var playerStatusObserver: AnyCancellable?
  @State private var notificationObservers: [NSObjectProtocol] = []
  
  @Default(.VideoDefSettings) private var videoDefSettings
  @Environment(\.scenePhase) private var scenePhase
  
  private var autoPlayVideos: Bool { videoDefSettings.autoPlay }
  private var loopVideos: Bool { videoDefSettings.loop }
  private var muteVideos: Bool { videoDefSettings.mute }
  private var pauseBackgroundAudioOnFullscreen: Bool { videoDefSettings.pauseBGAudioOnFullscreen }
  
  init(controller: UIViewController?, cachedVideo: SharedVideo?, markAsSeen: (() async -> ())?, compact: Bool = false, contentWidth: CGFloat, url: URL, resetVideo: ((SharedVideo) -> ())?, maxMediaHeightScreenPercentage: CGFloat) {
    self.controller = controller
    self.sharedVideo = cachedVideo
    self.markAsSeen = markAsSeen
    self.compact = compact
    self.contentWidth = contentWidth
    self.url = url
    self.size = cachedVideo?.size ?? .zero
    self.resetVideo = resetVideo
    self.maxMediaHeightScreenPercentage = maxMediaHeightScreenPercentage
  }
  
  var safe: Double { getSafeArea().top + getSafeArea().bottom }
  
  var body: some View {
    let maxHeight: CGFloat = (maxMediaHeightScreenPercentage / 100) * (.screenH)
    let sourceWidth = size.width
    let sourceHeight = size.height
    let propHeight = (contentWidth * sourceHeight) / sourceWidth
    let finalHeight = maxMediaHeightScreenPercentage != 110 ? Double(min(maxHeight, propHeight)) : Double(propHeight)
    
    if let sharedVideo = sharedVideo {
      let hasAudio = sharedVideo.queuePlayer.currentItem?.tracks.contains(where: {$0.assetTrack?.mediaType == AVMediaType.audio}) ?? false
      
      if let controller = controller {
        AVQueuePlayerRepresentable(
          fullscreen: $fullscreen,
          autoPlayVideos: autoPlayVideos,
          queuePlayer: sharedVideo.queuePlayer,
          aspect: .resizeAspectFill,
          controller: controller
        )
        .frame(width: compact ? scaledCompactModeThumbSize() : contentWidth, height: compact ? scaledCompactModeThumbSize() : CGFloat(finalHeight))
        .mask(RR(12, Color.black))
        .allowsHitTesting(false)
        .contentShape(Rectangle())
        .onTapGesture {
          if markAsSeen != nil { Task(priority: .background) { await markAsSeen?() } }
          withAnimation {
            fullscreen = true
          }
        }
      } else {
        ZStack {
          Group {
            if !fullscreen {
              VideoPlayer(player: sharedVideo.queuePlayer)
                .scaledToFill()
                .ignoresSafeArea()
            } else {
              Color.clear
            }
          }
          .frame(width: compact ? scaledCompactModeThumbSize() : contentWidth, height: compact ? scaledCompactModeThumbSize() : CGFloat(finalHeight))
          .clipped()
          .fixedSize()
          .mask(RR(12, Color.black))
          .contentShape(Rectangle())
          .onTapGesture {
            if markAsSeen != nil { Task(priority: .background) { await markAsSeen?() } }
            sharedVideo.loadIfNeeded()
            withAnimation {
              fullscreen = true
            }
          }
                  
          // Play button overlay
          Image(systemName: "play.fill")
            .foregroundColor(.white.opacity(0.75))
            .fontSize(32)
            .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
            .opacity((autoPlayVideos && sharedVideo.hasValidItem()) || NetworkMonitor.shared.connectedToWifi ? 0 : 1)
            .allowsHitTesting(false)
        }
        .onAppear {
          setupPlayer()
        }
        .onChange(of: NetworkMonitor.shared.connectedToWifi) { isConnected in
          if isConnected {
            sharedVideo.loadIfNeeded()
            // Try to auto-play if enabled and we now have a valid item
            if autoPlayVideos {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if sharedVideo.hasValidItem() {
                  sharedVideo.queuePlayer.play()
                }
              }
            }
          }
        }
        .onChange(of: scenePhase) { newPhase in
          handleScenePhaseChange(newPhase)
        }
        .onDisappear() {
          cleanupPlayer()
        }
        .onChange(of: fullscreen) { val in
          handleFullscreenChange(val)
        }
        .fullScreenCover(isPresented: $fullscreen) {
          FullScreenQueueVP(sharedVideo: sharedVideo)
        }
      }
    }
  }
  
  // MARK: - Player Management Methods
  private func setupPlayer() {
    guard let sharedVideo = sharedVideo else { return }
    
    // Setup looping if enabled
    if loopVideos {
      sharedVideo.enableLooping()
      addObservers()
    }
    
    // Monitor player status
    playerStatusObserver = sharedVideo.queuePlayer.publisher(for: \.currentItem)
      .compactMap { $0 }
      .flatMap { item in
        item.publisher(for: \.status)
      }
      .sink { status in
        if status == .readyToPlay && autoPlayVideos {
            sharedVideo.queuePlayer.play()
        }
        
        if status == .failed {
          print("[VID] Queue player item failed, attempting reset")
          resetVideo?(sharedVideo)
        }
      }
    
    // Handle failed player
    if let currentItem = sharedVideo.queuePlayer.currentItem, currentItem.status == .failed {
      resetVideo?(sharedVideo)
    } else if NetworkMonitor.shared.connectedToWifi {
      sharedVideo.loadIfNeeded()
    }
    
    // Auto-play if enabled
    if autoPlayVideos && sharedVideo.hasValidItem() {
      sharedVideo.queuePlayer.play()
    }
    
    // Track usage
    Nav.shared.currVideos[sharedVideo.id] = (Nav.shared.currVideos[sharedVideo.id] ?? 0) + 1
  }
  
  private func handleScenePhaseChange(_ newPhase: ScenePhase) {
    guard let sharedVideo = sharedVideo else { return }
    
    switch newPhase {
    case .active:
      // Reload if needed after backgrounding
      if !sharedVideo.hasValidItem() {
        sharedVideo.loadIfNeeded()
        resetVideo?(sharedVideo)
      }
      
      if autoPlayVideos {
        // Small delay to ensure player is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          sharedVideo.queuePlayer.play()
        }
      }
      
    case .inactive, .background:
      sharedVideo.queuePlayer.pause()
      
    @unknown default:
      break
    }
  }
  
  private func handleFullscreenChange(_ val: Bool) {
    guard let sharedVideo = sharedVideo else { return }
    
    if !firstFullscreen {
      firstFullscreen = true
      sharedVideo.queuePlayer.isMuted = muteVideos
      sharedVideo.queuePlayer.play()
    }
    
    if !val && !autoPlayVideos {
      sharedVideo.queuePlayer.seek(to: .zero)
      sharedVideo.queuePlayer.pause()
      firstFullscreen = false
    }
    
    sharedVideo.queuePlayer.volume = val ? 1.0 : 0.0
  }
  
  private func cleanupPlayer() {
    guard let sharedVideo = sharedVideo else { return }
    
    removeObservers()
    playerStatusObserver?.cancel()
    
    if (Nav.shared.currVideos[sharedVideo.id] ?? 0) <= 1 {
      Task(priority: .background) {
        sharedVideo.queuePlayer.seek(to: .zero)
        sharedVideo.queuePlayer.pause()
        
        // Consider removing from cache if memory is tight
        if ProcessInfo.processInfo.thermalState == .critical {
          Caches.videos.cache.removeValue(forKey: sharedVideo.key)
        }
      }
    }
    
    Nav.shared.currVideos[sharedVideo.id] = (Nav.shared.currVideos[sharedVideo.id] ?? 0) > 1 ? Nav.shared.currVideos[sharedVideo.id]! - 1 : nil
  }
  
  // MARK: - Notification Observers
  private func addObservers() {
    guard let sharedVideo = sharedVideo else { return }
    removeObservers() // Clean up first
    
    // Only add observers if we have a current item
    guard let currentItem = sharedVideo.queuePlayer.currentItem else { return }
    
    let endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: currentItem,
      queue: nil) { [weak sharedVideo] notif in
        guard let sharedVideo = sharedVideo else { return }
        Task(priority: .background) {
          // AVPlayerLooper handles this automatically, but keeping for manual control
          if sharedVideo.queuePlayer.items().count == 1 {
            sharedVideo.queuePlayer.seek(to: .zero)
            sharedVideo.queuePlayer.play()
          }
        }
      }
    
    let failedObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: currentItem,
      queue: nil) { [self] notif in
        guard let sharedVideo = self.sharedVideo else { return }
        Task(priority: .background) {
          resetVideo?(sharedVideo)
        }
      }
    
    notificationObservers = [endObserver, failedObserver]
  }
  
  private func removeObservers() {
    for observer in notificationObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    notificationObservers.removeAll()
  }
}

// MARK: - Updated AVPlayerRepresentable for Queue Player
struct AVQueuePlayerRepresentable: UIViewRepresentable {
  @Binding var fullscreen: Bool
  var autoPlayVideos: Bool
  let queuePlayer: AVQueuePlayer
  let aspect: AVLayerVideoGravity
  var controller: UIViewController

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let playerController = NiceAVQueuePlayer(fullscreen: $fullscreen, autoPlayVideos: autoPlayVideos)
    playerController.allowsVideoFrameAnalysis = false
    playerController.player = queuePlayer
    playerController.videoGravity = aspect

    context.coordinator.controller = playerController
    controller.addChild(playerController)
    playerController.view.frame = view.bounds
    view.addSubview(playerController.view)
    playerController.didMove(toParent: controller)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    if let playerController = context.coordinator.controller, playerController.autoPlayVideos != autoPlayVideos {
      playerController.autoPlayVideos = autoPlayVideos
    }
    if fullscreen {
      context.coordinator.controller?.enterFullScreen(animated: true)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject {
    var controller: NiceAVQueuePlayer? = nil
  }
}

// MARK: - Updated Player Controller for Queue Player
class NiceAVQueuePlayer: AVPlayerViewController, AVPlayerViewControllerDelegate {
  @Binding var fullscreen: Bool
  var autoPlayVideos: Bool
  var ida = UUID().uuidString
  var gone = true
  @Default(.VideoDefSettings) private var videoDefSettings
  
  override open var prefersStatusBarHidden: Bool {
    return true
  }

  init(fullscreen: Binding<Bool>, autoPlayVideos: Bool) {
    self._fullscreen = fullscreen
    self.autoPlayVideos = autoPlayVideos
    super.init(nibName: nil, bundle: nil)
    self.delegate = self
    showsPlaybackControls = false
  }

  required init?(coder aDecoder: NSCoder) {
    self.autoPlayVideos = false
    self._fullscreen = Binding(get: { true }, set: { _, _ in return })
    super.init(coder: aDecoder)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    if autoPlayVideos && gone {
      self.player?.play()
      gone = false
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    if !showsPlaybackControls {
      player?.pause()
      gone = true
    }
  }

  @objc private func didTapView() {
    enterFullScreen(animated: true)
    showsPlaybackControls = true
  }

  func enterFullScreen(animated: Bool) {
    let selector = NSSelectorFromString("enterFullScreenAnimated:completionHandler:")
    
    if self.responds(to: selector) {
      self.perform(selector, with: animated, with: nil)
    }
  }

  func exitFullScreen(animated: Bool) {
    let selector = NSSelectorFromString("exitFullScreenAnimated:completionHandler:")
    
    if self.responds(to: selector) {
      self.perform(selector, with: animated, with: nil)
    }
  }

  func playerViewController(
    _ playerViewController: AVPlayerViewController,
    willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
  ) {
    coordinator.animate(alongsideTransition: nil) { [weak self] context in
      guard let self = self else { return }
      if !context.isCancelled {
        self.player?.volume = 1.0
        self.player?.play()
        self.showsPlaybackControls = true
      }
    }
  }

  func playerViewController(
    _ playerViewController: AVPlayerViewController,
    willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
  ) {
    let isPlaying = self.player?.isPlaying ?? false
    coordinator.animate(alongsideTransition: nil) { [weak self] context in
      guard let self = self else { return }
      if !context.isCancelled {
        self.fullscreen = false
        doThisAfter(0.0) {
          self.player?.volume = 0.0
        }
        self.showsPlaybackControls = false
        if !self.autoPlayVideos {
          self.player?.pause()
        } else if isPlaying {
          self.player?.play()
        }
      }
    }
  }
}

// MARK: - Updated FullScreen Player
struct FullScreenQueueVP: View {
  var sharedVideo: SharedVideo
  @Environment(\.dismiss) private var dismiss
  @State private var cancelDrag: Bool?
  @State private var isPinching: Bool = false
  @State private var drag: CGSize = .zero
  @State private var scale: CGFloat = 1.0
  @State private var anchor: UnitPoint = .zero
  @State private var offset: CGSize = .zero
  @State private var altSize: CGSize = .zero
  
  var body: some View {
    let interpolate = interpolatorBuilder([0, 100], value: abs(drag.height))
    VideoPlayer(player: sharedVideo.queuePlayer)
      .background(
        sharedVideo.size != .zero
        ? nil
        : GeometryReader { geo in
          Color.clear
            .onAppear { altSize = geo.size }
            .onChange(of: geo.size) { newValue in altSize = newValue }
        }
      )
      .scaleEffect(interpolate([1, 0.9], true))
      .offset(cancelDrag ?? false ? .zero : drag)
      .gesture(
        scale != 1.0
        ? nil
        : DragGesture(minimumDistance: 10)
          .onChanged { val in
            if cancelDrag == nil { cancelDrag = abs(val.translation.width) > abs(val.translation.height) }
            if cancelDrag == nil || cancelDrag! { return }
            var transaction = Transaction()
            transaction.isContinuous = true
            transaction.animation = .interpolatingSpring(stiffness: 1000, damping: 100, initialVelocity: 0)
            
            let endPos = val.translation
            withTransaction(transaction) {
              drag = endPos
            }
          }
          .onEnded { val in
            let prevCancelDrag = cancelDrag
            cancelDrag = nil
            if prevCancelDrag == nil || prevCancelDrag! { return }
            let shouldClose = abs(val.translation.width) > 100 || abs(val.translation.height) > 100
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 20, initialVelocity: 0)) {
              drag = .zero
              if shouldClose {
                dismiss()
              }
            }
          }
      )
  }
}
