//
//  PermissionsHelper.swift
//  WhisprOSS
//
//  Helper to check and request macOS permissions
//

import Foundation
import AppKit
import AVFoundation
import Speech

class PermissionsHelper {
    // MARK: - Accessibility
    static func checkAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermissions() {
        print("🔐 Requesting accessibility permissions...")
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let result = AXIsProcessTrustedWithOptions(options)
        print("🔐 Accessibility permission result: \(result)")

        if !result {
            print("🔐 Permission not granted, opening System Settings...")
            // Open System Settings directly since the prompt might not work for debug builds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                openAccessibilityPreferences()
            }
        }
    }

    static func openAccessibilityPreferences() {
        print("🔐 Opening Accessibility Settings...")

        // Simply open System Settings app - easier and more reliable
        let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.open(settingsURL)

        print("🔐 System Settings opened. Navigate to: Privacy & Security → Accessibility")
        print("🔐 Then click the + button and add: WhisprOSS (or the Xcode debug build)")
    }

    // MARK: - Microphone
    static func checkMicrophonePermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }

    static func requestMicrophonePermission() {
        print("🎤 Requesting microphone permission...")
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("🎤 Microphone permission result: \(granted)")
            if !granted {
                print("🎤 Permission denied or dialog dismissed, opening System Settings...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    openMicrophonePreferences()
                }
            }
        }
    }

    static func openMicrophonePreferences() {
        print("🎤 Opening Microphone Settings...")
        let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.open(settingsURL)
        print("🎤 Navigate to: Privacy & Security → Microphone")
    }

    // MARK: - Speech Recognition
    static func checkSpeechRecognitionPermission() -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        return status == .authorized
    }

    static func requestSpeechRecognitionPermission() async {
        print("🗣️ Requesting speech recognition permission...")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                print("🗣️ Speech Recognition permission result: \(status.rawValue)")
                if status != .authorized {
                    print("🗣️ Permission not granted, opening System Settings...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        openSpeechRecognitionPreferences()
                    }
                }
                continuation.resume()
            }
        }
    }

    static func openSpeechRecognitionPreferences() {
        print("🗣️ Opening Speech Recognition Settings...")
        let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.open(settingsURL)
        print("🗣️ Navigate to: Privacy & Security → Speech Recognition")
    }
}
