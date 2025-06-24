//
//  GeneratedSummaryView.swift
//  winston
//
//  Created by Zander Bobronnikov on 6/22/25.
//

import SwiftUI
import MarkdownUI

struct GeneratedSummaryView: View {
    @Binding var generatedSummary: String?
    @Binding var errorMessage: String?
    @Binding var streaming: Bool
    @State var loading: Bool = true
    @State private var isVisible = false
    @State private var gradientOffset: Double = 0
    @State private var isCollapsed = false
    
    private var hasError: Bool {
        errorMessage != nil
    }
    
    private var hasContent: Bool {
        (generatedSummary ?? errorMessage ?? "").count > 0
    }
    
    var body: some View {
        if generatedSummary != nil || errorMessage != nil {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Separator
                if !isCollapsed && hasContent {
                    separatorView
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                
                // Content with smooth streaming
                if !isCollapsed && hasContent {
                    contentView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .background(backgroundView)
            .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 6)
            .shadow(color: hasError ? .red.opacity(0.15) : .purple.opacity(0.1), radius: 6, x: 0, y: 3)
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    isVisible = true
                }
                startContinuousAnimations()
            }
            .onTapGesture {
              isCollapsed.toggle()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: hasError ? "exclamationmark.triangle.fill" : "brain.head.profile")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(headerGradient)
                
                Text(hasError ? "Error" : "Analysis")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(headerGradient)
            }
            
            HStack(spacing: 8) {
                // Smooth loading indicator
                if loading && !hasError {
                    loadingIndicator
                }
                
                Spacer()
                
                if hasContent {
                    collapseButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color.black.opacity(0.4)
                
                // Subtle shimmer during loading
                if loading {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.03), .blue.opacity(0.08), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isVisible ? 200 : -200)
                        .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: isVisible)
                }
            }
        )
    }
    
    private var headerGradient: LinearGradient {
        hasError ?
            LinearGradient(colors: [.red], startPoint: .leading, endPoint: .trailing) :
            LinearGradient(colors: [.purple, .blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var loadingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.green.opacity(0.8))
                    .frame(width: 4, height: 4)
                    .scaleEffect(isVisible ? 1.2 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isVisible
                    )
            }
        }
    }
    
    private var collapseButton: some View {
        Button(action: {
          isCollapsed.toggle()
        }) {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(headerGradient)
                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                .animation(.easeInOut(duration: 0.3), value: isCollapsed)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var separatorView: some View {
        Rectangle()
            .fill(separatorGradient)
            .frame(height: 3)
            .padding(.horizontal, 16)
            .opacity(0.7)
    }
    
    private var separatorGradient: LinearGradient {
        LinearGradient(
            colors: hasError ? [
                .red.opacity(0.4), .orange.opacity(0.4), .red.opacity(0.2), .orange.opacity(0.4), .red.opacity(0.4)
            ] : [
                .blue.opacity(0.4), .purple.opacity(0.4), .pink.opacity(0.4), .purple.opacity(0.4), .blue.opacity(0.4)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var contentView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black.opacity(0.6))
                .overlay(innerShadowOverlay)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if let summary = generatedSummary {
                            // Use the smooth streaming markdown view
                            StreamingMarkdownView(
                                text: summary,
                                isStreaming: streaming,
                                isLoading: $loading,
                                scrollProxy: proxy
                            )
                        }
                        
                        // Invisible anchor for auto-scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxHeight: 400)
    }
    
    private var innerShadowOverlay: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    colors: [.black.opacity(0.6), .black.opacity(0.2), .clear],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(height: 12)
                .offset(y: -6)
            
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, .black.opacity(0.2), .black.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(height: 12)
                .offset(y: 6)
        }
        .allowsHitTesting(false)
    }
    
    private var backgroundView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color.black.opacity(0.7), Color.black.opacity(0.8)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            
            // Animated border - slower during loading to reduce overhead
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderGradient, lineWidth: 3)
                .blur(radius: 0.5)
                .animation(.linear(duration: loading ? 12.0 : 8.0).repeatForever(autoreverses: false), value: gradientOffset)
            
            // Glow effect - reduced during loading
            RoundedRectangle(cornerRadius: 16)
                .stroke(glowGradient, lineWidth: loading ? 4 : 8)
                .blur(radius: loading ? 4 : 8)
                .animation(.linear(duration: loading ? 15.0 : 10.0).repeatForever(autoreverses: false), value: gradientOffset)
        }
    }
    
    private var borderGradient: AngularGradient {
        AngularGradient(
            colors: hasError ? [
                .red, .orange, .red.opacity(0.6), .orange, .red
            ] : [
                .blue, .purple, .pink, .cyan, .blue.opacity(0.8), .purple, .pink.opacity(0.9), .cyan, .blue
            ],
            center: .center,
            startAngle: .degrees(gradientOffset),
            endAngle: .degrees(gradientOffset + 360)
        )
    }
    
    private var glowGradient: AngularGradient {
        AngularGradient(
            colors: hasError ? [
                .red.opacity(0.4), .orange.opacity(0.4), .red.opacity(0.2), .orange.opacity(0.4), .red.opacity(0.4)
            ] : [
                .blue.opacity(0.4), .purple.opacity(0.4), .pink.opacity(0.4), .cyan.opacity(0.4),
                .blue.opacity(0.4), .purple.opacity(0.4), .pink.opacity(0.4), .cyan.opacity(0.4), .blue.opacity(0.4)
            ],
            center: .center,
            startAngle: .degrees(gradientOffset * 0.7),
            endAngle: .degrees(gradientOffset * 0.7 + 360)
        )
    }
    
    private func startContinuousAnimations() {
        gradientOffset = 0
        withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
            gradientOffset = 360
        }
    }
}

// Enhanced Markdown view with smooth streaming and jitter-free auto-scroll
struct StreamingMarkdownView: View {
    let text: String
    let isStreaming: Bool
    @Binding var isLoading: Bool
    let scrollProxy: ScrollViewProxy
    @State private var displayedText = ""
    @State private var animationTimer: Timer?
    @State private var shouldAutoScroll = true
    @State private var lastUserScrollTime = Date.distantPast
    @State private var lastTextLength = 0
    @State private var scrollWorkItem: DispatchWorkItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Markdown(displayedText)
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: text) { newValue in
                    if isStreaming {
                        smoothlyUpdateText(to: newValue)
                    } else {
                        displayedText = newValue
                        checkIfComplete()
                        // Final scroll when streaming ends
                        scrollToBottom(withDelay: 0.1)
                    }
                }
                .onChange(of: isStreaming) { streaming in
                    if !streaming {
                        checkIfComplete()
                        scrollToBottom(withDelay: 0.1)
                    } else {
                        // Reset auto-scroll when streaming starts
                        shouldAutoScroll = true
                        lastTextLength = 0
                    }
                }
                .onChange(of: displayedText) { newText in
                    handleTextChange(newText)
                }
                .onAppear {
                    displayedText = text
                    shouldAutoScroll = true
                    lastTextLength = text.count
                }
                .onDisappear {
                    cleanupTimers()
                }
                .background(
                    // Gesture detector for manual scrolling
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { _ in
                                    handleUserScroll()
                                }
                        )
                )
        }
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            resumeAutoScrollIfNeeded()
        }
    }
    
    private func handleTextChange(_ newText: String) {
        let newLength = newText.count
        let hasNewContent = newLength > lastTextLength
        
        if hasNewContent {
            lastTextLength = newLength
            
            // Only auto-scroll if we should and there's new content during streaming
            if shouldAutoScroll && (isStreaming || isLoading) {
                scheduleSmootScroll()
            }
        }
        
        if !isStreaming {
            checkIfComplete()
        }
    }
    
    private func handleUserScroll() {
        shouldAutoScroll = false
        lastUserScrollTime = Date()
        cancelScheduledScroll()
    }
    
    private func resumeAutoScrollIfNeeded() {
        let timeSinceUserScroll = Date().timeIntervalSince(lastUserScrollTime)
        if !shouldAutoScroll && timeSinceUserScroll > 2.0 && (isStreaming || isLoading) {
            shouldAutoScroll = true
            scheduleSmootScroll()
        }
    }
    
    private func smoothlyUpdateText(to newText: String) {
        animationTimer?.invalidate()
        
        // If new text is shorter, update immediately
        guard newText.count >= displayedText.count else {
            displayedText = newText
            return
        }
        
        let currentLength = displayedText.count
        let newLength = newText.count
        
        guard newLength > currentLength else {
            displayedText = newText
            return
        }
        
        // Use larger chunks and slower timing to reduce UI updates
        var charIndex = currentLength
        let chunkSize = 5 // Larger chunks for smoother performance
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            guard charIndex < newLength else {
                timer.invalidate()
                displayedText = newText
                return
            }
            
            let endIndex = min(charIndex + chunkSize, newLength)
            displayedText = String(newText.prefix(endIndex))
            charIndex = endIndex
        }
    }
    
    private func scheduleSmootScroll() {
        guard shouldAutoScroll else { return }
        
        // Cancel any existing scroll work
        cancelScheduledScroll()
        
        // Create new scroll work item with debouncing
        scrollWorkItem = DispatchWorkItem {
            performSmoothScroll()
        }
        
        // Execute with a small delay to batch scroll requests
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: scrollWorkItem!)
    }
    
    private func cancelScheduledScroll() {
        scrollWorkItem?.cancel()
        scrollWorkItem = nil
    }
    
    private func performSmoothScroll() {
        guard shouldAutoScroll && !Thread.isMainThread == false else { return }
        
        // Use a single, consistent animation for all auto-scrolls
        withAnimation(.easeOut(duration: 0.3)) {
            scrollProxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    private func scrollToBottom(withDelay delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.4)) {
                scrollProxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
    
    private func cleanupTimers() {
        animationTimer?.invalidate()
        animationTimer = nil
        cancelScheduledScroll()
    }
    
    private func checkIfComplete() {
        if !isStreaming && displayedText == text {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isLoading = false
            }
        }
    }
}
