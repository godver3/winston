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
    @Binding var loading: Bool
    @State private var shimmerOffset: CGFloat = -200
    @State private var pulseOpacity: Double = 0.3
    @State private var isVisible = false
    @State private var gradientOffset: Double = 0
    @State private var isCollapsed = false
    
    private var hasError: Bool {
        errorMessage != nil
    }
    
    // Define consistent border gradient
    private var borderGradient: AngularGradient {
        AngularGradient(
            colors: hasError ? [
                .red,
                .orange,
                .red.opacity(0.6),
                .orange,
                .red
            ] : [
                .blue,
                .purple,
                .pink,
                .cyan,
                .blue.opacity(0.8),
                .purple,
                .pink.opacity(0.9),
                .cyan,
                .blue
            ],
            center: .center,
            startAngle: .degrees(gradientOffset),
            endAngle: .degrees(gradientOffset + 360)
        )
    }
    
    var body: some View {
        if generatedSummary != nil || errorMessage != nil {
            VStack(spacing: 0) {
                // AI Header with animated effects
                HStack {
                    HStack(spacing: 6) {
                        // Updated AI icon - removed circle background, applied gradient directly
                        Image(systemName: hasError ? "exclamationmark.triangle.fill" : "brain.head.profile")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                hasError ?
                                    LinearGradient(colors: [.red], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(
                                        colors: [.purple, .blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                        
                        Text(hasError ? "Error" : "Analysis")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: hasError ?
                                        [.red, .orange, .red] :
                                        [.purple, .blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                                        
                    HStack(spacing: 8) {
                        // Animated status indicator - only show green dots when loading
                        HStack(spacing: 4) {
                            if hasError {
                                // Removed xmark icon - now empty for errors
                            } else if loading {
                                ForEach(0..<3) { index in
                                    Circle()
                                        .fill(Color.green.opacity(0.8))
                                        .frame(width: 4, height: 4)
                                        .scaleEffect(isVisible ? 1.0 : 0.5)
                                        .animation(
                                            .easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.2),
                                            value: isVisible
                                        )
                                }
                            }
                        }
                        
                        Spacer()
                        
                      if (generatedSummary ?? errorMessage ?? "").count > 0 {
                        // Collapse/Expand button
                        Button(action: {
                          isCollapsed.toggle()
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(
                                    hasError ?
                                        LinearGradient(colors: [.red], startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(
                                            colors: [.purple, .blue, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
//                                .animation(.easeIn(duration: 0.3), value: isCollapsed)
                        }
                        .buttonStyle(PlainButtonStyle())
                      }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        // Base background - darker for black parent
                        Color.black.opacity(0.4)
                        
                        // Animated shimmer overlay - FIXED: Now uses shimmerOffset
//                        Rectangle()
//                            .fill(
//                                LinearGradient(
//                                    colors: hasError ? [
//                                        .clear,
//                                        .white.opacity(0.05),
//                                        .red.opacity(0.15),
//                                        .orange.opacity(0.1),
//                                        .clear
//                                    ] : [
//                                        .clear,
//                                        .white.opacity(0.05),
//                                        .purple.opacity(0.15),
//                                        .blue.opacity(0.1),
//                                        .clear
//                                    ],
//                                    startPoint: .leading,
//                                    endPoint: .trailing
//                                )
//                            )
//                            .offset(x: shimmerOffset)
//                            .mask(
//                                Rectangle()
//                                    .fill(LinearGradient(
//                                        colors: [.clear, .black, .black, .clear],
//                                        startPoint: .leading,
//                                        endPoint: .trailing
//                                    ))
//                            )
//                            .animation(.linear(duration: 4.0).repeatForever(autoreverses: false), value: shimmerOffset)
                    }
                )
                
                // Separator with padding - only show when not collapsed
                if !isCollapsed && (generatedSummary ?? errorMessage ?? "").count > 0 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: hasError ? [
                                    .red.opacity(0.4),
                                    .orange.opacity(0.4),
                                    .red.opacity(0.2),
                                    .orange.opacity(0.4),
                                    .red.opacity(0.4)
                                ] : [
                                    .blue.opacity(0.4),
                                    .purple.opacity(0.4),
                                    .pink.opacity(0.4),
                                    .purple.opacity(0.4),
                                    .blue.opacity(0.4),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                              )
                            )
                        .frame(height: 3)
                        .padding(.horizontal, 16)
                        .opacity(0.7)
                }
 
                // Main content area with inset appearance - only show when not collapsed
                if !isCollapsed && (generatedSummary ?? errorMessage ?? "").count > 0 {
                    ZStack {
                        // Inset background - darker for black parent
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                // Inner shadow overlay
                                ZStack {
                                    // Top inner shadow
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.black.opacity(0.6), .black.opacity(0.2), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: 12)
                                        .offset(y: -6)
                                    
                                    // Bottom inner shadow
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.clear, .black.opacity(0.2), .black.opacity(0.6)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: 12)
                                        .offset(y: 6)
                                }
                                .allowsHitTesting(false)
                            )
                        
                        // Scrollable content
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                if let error = errorMessage {
                                    // Removed duplicate error header - now just shows the error message
                                    Text(error)
                                        .font(.system(size: 16, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else if let summary = generatedSummary {
                                    Markdown(summary)
                                        .font(.system(size: 16, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    .frame(maxHeight: 400)
                }
            }
            .padding(2) // Add small inset from border to prevent bleed-through
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .background(
                ZStack {
                    // Base background with gradient - darker for black parent
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.7),
                                    Color.black.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Simplified border - just use stroke on RoundedRectangle
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderGradient, lineWidth: 3)
                        .blur(radius: 0.5)
                        .animation(.linear(duration: 8.0).repeatForever(autoreverses: false), value: gradientOffset)
                    
                    // Glow layer - FIXED: Now uses gradientOffset properly
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            AngularGradient(
                                colors: hasError ? [
                                    .red.opacity(0.4),
                                    .orange.opacity(0.4),
                                    .red.opacity(0.2),
                                    .orange.opacity(0.4),
                                    .red.opacity(0.4)
                                ] : [
                                    .blue.opacity(0.4),
                                    .purple.opacity(0.4),
                                    .pink.opacity(0.4),
                                    .cyan.opacity(0.4),
                                    .blue.opacity(0.4),
                                    .purple.opacity(0.4),
                                    .pink.opacity(0.4),
                                    .cyan.opacity(0.4),
                                    .blue.opacity(0.4)
                                ],
                                center: .center,
                                startAngle: .degrees(gradientOffset * 0.7),
                                endAngle: .degrees(gradientOffset * 0.7 + 360)
                            ),
                            lineWidth: 8
                        )
                        .blur(radius: 8)
                        .animation(.linear(duration: 10.0).repeatForever(autoreverses: false), value: gradientOffset)
                    
                    // Inner inset shadow overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            RadialGradient(
                                colors: hasError ? [
                                    .clear,
                                    .red.opacity(0.15),
                                    .orange.opacity(0.25),
                                    .black.opacity(0.5)
                                ] : [
                                    .clear,
                                    .blue.opacity(0.1),
                                    .purple.opacity(0.15),
                                    .pink.opacity(0.12),
                                    .black.opacity(0.4)
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 180
                            )
                        )
                        .blendMode(.multiply)
                }
            )
            .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 6)
            .shadow(color: hasError ? .red.opacity(0.15) : .purple.opacity(0.1), radius: 6, x: 0, y: 3)
            .shadow(color: hasError ? .orange.opacity(0.1) : .blue.opacity(0.05), radius: 3, x: 0, y: 2)
            // Fixed: Removed fade in/out animation that was causing entire view to fade
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    isVisible = true
                }
                
                // FIXED: Start continuous animations
                startContinuousAnimations()
            }
            .onTapGesture {
              isCollapsed.toggle()
            }
        }
    }
    
    // FIXED: Separate function to handle continuous animations
    private func startContinuousAnimations() {
        // Shimmer animation
//        shimmerOffset = -300
//        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
//            shimmerOffset = 800
//        }
        
        // Pulse animation
        pulseOpacity = 0.75
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.90
        }
        
        // Gradient rotation animation
        gradientOffset = 0
        withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
            gradientOffset = 360
        }
    }
}
