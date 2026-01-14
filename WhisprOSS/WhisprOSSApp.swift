//
//  WhisprOSSApp.swift
//  WhisprOSS
//
//  Created by Vivek Agarwal on 14/01/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct WhisprOSSApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var controller: ConversationController

    init() {
        print("🚀 WhisprOSS initializing...")
        let settingsInstance = AppSettings()
        print("🚀 Settings loaded")
        let config = settingsInstance.liteLLMConfig ?? LiteLLMConfig(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)
        print("🚀 LiteLLM config ready")
        let llm = LiteLLMClient(config: config)
        print("🚀 LiteLLM client created")
        let controllerInstance = ConversationController(llm: llm, settings: settingsInstance)
        print("🚀 ConversationController created")
        _settings = StateObject(wrappedValue: settingsInstance)
        _controller = StateObject(wrappedValue: controllerInstance)
        print("🚀 WhisprOSS init complete")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(controller)
                .onAppear {
                    print("📱 ContentView onAppear - checking permissions before installing monitors...")

                    // Check all permissions
                    let hasAccessibility = PermissionsHelper.checkAccessibilityPermissions()
                    let hasMicrophone = PermissionsHelper.checkMicrophonePermission()
                    let hasSpeech = PermissionsHelper.checkSpeechRecognitionPermission()

                    print("📊 Permission Status:")
                    print("   🔐 Accessibility: \(hasAccessibility)")
                    print("   🎤 Microphone: \(hasMicrophone)")
                    print("   🗣️ Speech Recognition: \(hasSpeech)")

                    if !hasAccessibility {
                        print("⚠️ WARNING: Accessibility permission NOT granted! Global hotkeys will NOT work!")
                        print("⚠️ You MUST enable WhisprOSS in System Settings → Privacy & Security → Accessibility")
                    }

                    if !hasMicrophone {
                        print("⚠️ WARNING: Microphone permission NOT granted!")
                    }

                    if !hasSpeech {
                        print("⚠️ WARNING: Speech Recognition permission NOT granted!")
                    }

                    print("📱 Installing global monitors now...")
                    controller.installGlobalMonitors()
                    print("📱 onAppear complete")
                }
                .onChange(of: settings.liteLLMBaseURL) {
                    updateLLMClient()
                }
                .onChange(of: settings.liteLLMApiKey) {
                    updateLLMClient()
                }
        }
    }

    private func updateLLMClient() {
        guard settings.liteLLMConfig != nil else { return }
        // Note: In a production app, you'd want to handle updating the client more gracefully
        // For now, this requires an app restart to take effect
    }
}
