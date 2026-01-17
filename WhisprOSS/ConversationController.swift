import Foundation
import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

@MainActor
final class ConversationController: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var level: Float = 0

    let speech = SpeechManager()
    let llm: LiteLLMClient
    let settings: AppSettings

    private var globalKeyDownMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var previousModifierFlags: NSEvent.ModifierFlags = []

    init(llm: LiteLLMClient, settings: AppSettings) {
        self.llm = llm
        self.settings = settings
        // Don't request permissions during init - it blocks UI
        // Permissions are now handled by PermissionsHelper in ContentView
    }

    func installGlobalMonitors() {
        #if os(macOS)
        removeGlobalMonitors()
        print("🎯 Installing event monitors...")

        let handleKeyDown: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }

            // Right Command key (keyCode 54) as fallback for testing
            let isRightCommand = event.keyCode == 54

            if isRightCommand && !self.isRecording {
                print("🎤 Right Command key DOWN - starting recording")
                self.startRecording()
            }
        }

        let handleKeyUp: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }

            let isRightCommand = event.keyCode == 54

            if isRightCommand && self.isRecording {
                print("🛑 Right Command key UP - stopping recording")
                Task { await self.stopAndProcess() }
            }
        }

        let handleFlagsChanged: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }

            let currentFlags = event.modifierFlags
            let previousFlags = self.previousModifierFlags

            // Check if Fn key state changed (NSEvent.ModifierFlags.function = 0x800000)
            let fnWasPressed = previousFlags.contains(.function)
            let fnIsPressed = currentFlags.contains(.function)

            if fnIsPressed && !fnWasPressed && !self.isRecording {
                // Fn key just pressed
                print("🎤 Fn key PRESSED! Starting recording...")
                self.startRecording()
            } else if !fnIsPressed && fnWasPressed && self.isRecording {
                // Fn key just released
                print("🛑 Fn key RELEASED! Stopping recording...")
                Task { await self.stopAndProcess() }
            }

            self.previousModifierFlags = currentFlags
        }

        // Global monitors - capture events from OTHER apps
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                handleKeyDown(event)
            } else if event.type == .flagsChanged {
                handleFlagsChanged(event)
            }
        }
        globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: handleKeyUp)
        print("✅ Global monitors installed (captures events from other apps)")

        // Local monitors - capture events from THIS app
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                handleKeyDown(event)
            } else if event.type == .flagsChanged {
                handleFlagsChanged(event)
            }
            return event
        }
        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            handleKeyUp(event)
            return event
        }
        print("✅ Local monitors installed (captures events from WhisprOSS window)")
        print("🎯 All monitors ready!")
        print("🎯 Press and HOLD Fn key to record, release to stop")
        print("🎯 Or use RIGHT Command (⌘) for testing")
        #endif
    }

    func removeGlobalMonitors() {
        #if os(macOS)
        if let m = globalKeyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = globalKeyUpMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyUpMonitor { NSEvent.removeMonitor(m) }
        globalKeyDownMonitor = nil
        globalKeyUpMonitor = nil
        localKeyDownMonitor = nil
        localKeyUpMonitor = nil
        previousModifierFlags = []
        #endif
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        do {
            try speech.startRecording()
            bindLevel()
            #if os(macOS)
            HUDWindowController.shared.show(controller: self, settings: settings, atBottom: true)
            #endif
            print("🎙️ Recording started")
        } catch {
            print("❌ Error starting recording: \(error)")
            isRecording = false
        }
    }

    private func bindLevel() {
        // Simple polling since SpeechManager publishes level
        Task { [weak self] in
            guard let self = self else { return }
            while self.isRecording {
                await MainActor.run { self.level = self.speech.level }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }

    private func stopRecording() {
        speech.stop()
        isRecording = false
        #if os(macOS)
        // Don't hide - the HUD stays visible in idle state
        // Just update position in case we need to re-center
        HUDWindowController.shared.updatePosition()
        #endif
    }

    private func messages(from transcript: String) -> [[String: String]] {
        return [
            ["role": "system", "content": settings.buildSystemPrompt()],
            ["role": "user", "content": transcript]
        ]
    }

    private func pasteToFrontmostApp(_ text: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        // Simulate Command+V
        let src = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true) // Command
        cmdDown?.flags = .maskCommand
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // V
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)
        cmdUp?.flags = []
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        #endif
    }

    func stopAndProcess() async {
        let transcript = speech.transcript
        print("📝 Raw transcript from speech: '\(transcript)'")
        stopRecording()

        guard !transcript.isEmpty else {
            print("⚠️ Transcript is empty, nothing to process")
            return
        }

        // Check if LLM processing is enabled
        if settings.useLLMProcessing {
            print("[LLM] Processing enabled, sending to LLM...")
            print("💬 Model: \(settings.llmModel)")
            print("💬 System prompt: \(settings.buildSystemPrompt())")

            do {
                var final = ""
                let stream = try await llm.streamChatCompletion(model: settings.llmModel, messages: messages(from: transcript))
                print("💬 Streaming response from LLM...")
                for try await token in stream {
                    final.append(token)
                    // Accumulate tokens silently to avoid spamming logs
                }
                print("✅ LLM response complete: '\(final)'")
                print("📋 Pasting to frontmost app...")
                pasteToFrontmostApp(final)
                print("✅ Paste complete!")
            } catch {
                print("❌ LLM error: \(error)")
                print("📋 Fallback: Pasting raw transcript instead...")
                pasteToFrontmostApp(transcript)
                print("✅ Fallback paste complete!")
            }
        } else {
            print("[Direct] LLM disabled, pasting raw transcript")
            pasteToFrontmostApp(transcript)
            print("✅ Direct paste complete!")
        }
    }

    // TEST METHODS - For debugging
    func testStartRecording() {
        print("🧪 TEST: testStartRecording() called")
        startRecording()
    }

    func testStopRecording() async {
        print("🧪 TEST: testStopRecording() called")
        await stopAndProcess()
    }
}
