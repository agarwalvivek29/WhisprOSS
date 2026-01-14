//
//  ContentView.swift
//  WhisprOSS
//
//  Created by Vivek Agarwal on 14/01/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController
    @State private var hasAccessibilityPermission = false
    @State private var hasMicrophonePermission = false
    @State private var hasSpeechRecognitionPermission = false
    @State private var permissionCheckTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Status bar at top
            HStack {
                Circle()
                    .fill(controller.isRecording ? Color.red : Color.green)
                    .frame(width: 10, height: 10)
                Text(controller.isRecording ? "Recording..." : "Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                // Permission status indicators
                HStack(spacing: 8) {
                    PermissionIndicator(name: "Accessibility", granted: hasAccessibilityPermission)
                    PermissionIndicator(name: "Microphone", granted: hasMicrophonePermission)
                    PermissionIndicator(name: "Speech", granted: hasSpeechRecognitionPermission)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Permission warning banners
            if !hasAccessibilityPermission || !hasMicrophonePermission || !hasSpeechRecognitionPermission {
                VStack(spacing: 8) {
                    if !hasAccessibilityPermission {
                        VStack(alignment: .leading, spacing: 8) {
                            PermissionBanner(
                                icon: "hand.raised.fill",
                                title: "Accessibility Permission Required",
                                description: "Needed to monitor the Fn key globally",
                                grantAction: {
                                    print("🔔 Requesting Accessibility")
                                    PermissionsHelper.requestAccessibilityPermissions()
                                    recheckPermissions()
                                },
                                openSettingsAction: {
                                    PermissionsHelper.openAccessibilityPreferences()
                                }
                            )

                            // Instructions for debug builds
                            Text("📝 For Xcode builds: Open System Settings → Privacy & Security → Accessibility → Click '+' button → Press Cmd+Shift+G → Paste: /Users/agarwalvivek29/Library/Developer/Xcode/DerivedData/WhisprOSS-arhuvkuxazwkcchknllrnxbrlbrj/Build/Products/Debug/WhisprOSS.app")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                        }
                    }

                    if !hasMicrophonePermission {
                        PermissionBanner(
                            icon: "mic.fill",
                            title: "Microphone Permission Required",
                            description: "Needed to record your voice",
                            grantAction: {
                                print("🔔 Requesting Microphone")
                                PermissionsHelper.requestMicrophonePermission()
                                recheckPermissions()
                            },
                            openSettingsAction: {
                                PermissionsHelper.openMicrophonePreferences()
                            }
                        )
                    }

                    if !hasSpeechRecognitionPermission {
                        PermissionBanner(
                            icon: "waveform",
                            title: "Speech Recognition Permission Required",
                            description: "Needed to transcribe your speech",
                            grantAction: {
                                print("🔔 Requesting Speech Recognition")
                                Task {
                                    await PermissionsHelper.requestSpeechRecognitionPermission()
                                    recheckPermissions()
                                }
                            },
                            openSettingsAction: {
                                PermissionsHelper.openSpeechRecognitionPreferences()
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            // TEST BUTTON - Debug recording
            HStack {
                Button("🧪 TEST: Start Recording Manually") {
                    print("🧪 TEST BUTTON: Manually triggering recording...")
                    controller.testStartRecording()
                }
                .buttonStyle(.borderedProminent)

                if controller.isRecording {
                    Button("🛑 Stop Recording") {
                        Task {
                            await controller.testStopRecording()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()

            // Settings view
            SettingsView(settings: settings)
        }
        .onAppear {
            print("✅ ContentView appeared")
            checkPermissions()
            // Check permissions less frequently - only every 10 seconds
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                checkPermissions()
            }
        }
        .onDisappear {
            print("❌ ContentView disappeared")
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }

    private func checkPermissions() {
        let newAccessibility = PermissionsHelper.checkAccessibilityPermissions()
        let newMicrophone = PermissionsHelper.checkMicrophonePermission()
        let newSpeech = PermissionsHelper.checkSpeechRecognitionPermission()

        // Only log if permissions changed
        if newAccessibility != hasAccessibilityPermission {
            print("🔐 Accessibility permission changed: \(hasAccessibilityPermission) → \(newAccessibility)")
        }
        if newMicrophone != hasMicrophonePermission {
            print("🎤 Microphone permission changed: \(hasMicrophonePermission) → \(newMicrophone)")
        }
        if newSpeech != hasSpeechRecognitionPermission {
            print("🗣️ Speech Recognition permission changed: \(hasSpeechRecognitionPermission) → \(newSpeech)")
        }

        hasAccessibilityPermission = newAccessibility
        hasMicrophonePermission = newMicrophone
        hasSpeechRecognitionPermission = newSpeech
    }

    private func recheckPermissions() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkPermissions()
        }
    }
}

struct PermissionIndicator: View {
    let name: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? .green : .red)
                .font(.caption)
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct PermissionBanner: View {
    let icon: String
    let title: String
    let description: String
    let grantAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Grant") {
                grantAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Settings") {
                openSettingsAction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .environmentObject(ConversationController(llm: LiteLLMClient(config: .init(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)), settings: AppSettings()))
}
