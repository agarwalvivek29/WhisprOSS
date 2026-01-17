//
//  WelcomeStepView.swift
//  WhisprOSS
//
//  First step of onboarding - welcome screen
//

import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title and tagline
            VStack(spacing: 8) {
                Text("Welcome to WhisprOSS")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Voice-first dictation for macOS")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "mic.fill",
                    title: "Press to Talk",
                    description: "Hold the Fn key and speak naturally"
                )

                FeatureRow(
                    icon: "bolt.fill",
                    title: "Instant Transcription",
                    description: "On-device speech recognition for privacy"
                )

                FeatureRow(
                    icon: "text.cursor",
                    title: "Auto-Paste",
                    description: "Text appears wherever you're typing"
                )

                FeatureRow(
                    icon: "brain",
                    title: "AI Enhancement",
                    description: "Optional LLM cleanup for polished text"
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Get Started button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeStepView(onContinue: {})
}
