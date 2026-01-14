import Foundation
import AVFoundation
import Speech
import Combine
import Accelerate
#if os(macOS)
import CoreAudio
#endif

final class SpeechManager: NSObject, ObservableObject {
    @Published var transcript: String = ""
    @Published var level: Float = 0.0 // 0...1 for waveform UI

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()

    private var levelTimer: Timer?

    func requestPermissions() async throws {
        // Permissions are now handled by PermissionsHelper
        // This method is kept for compatibility
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)
        #endif
        // No-op on macOS
    }

    func startRecording() throws {
        print("🎙️ SpeechManager.startRecording() called")
        stop() // ensure clean state
        transcript = ""

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer not available!")
            throw NSError(domain: "SpeechManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

        // Check default input device and set it explicitly
        #if os(macOS)
        var selectedDeviceID: AudioDeviceID = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let getDefaultStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &selectedDeviceID
        )

        if getDefaultStatus == noErr && selectedDeviceID != 0 {
            let tempInputNode = audioEngine.inputNode
            if let audioUnit = tempInputNode.audioUnit {
                // Stop engine if running
                if audioEngine.isRunning {
                    audioEngine.stop()
                }

                var deviceIDToSet = selectedDeviceID
                let setStatus = AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &deviceIDToSet,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                if setStatus == noErr {
                    print("✅ Set audio input device (ID: \(selectedDeviceID))")
                } else {
                    print("⚠️ Failed to set audio input device (status: \(setStatus))")
                }

                // Reset the audio engine to pick up the device change
                audioEngine.reset()
            }
        }
        #endif

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        print("✅ Audio format: \(format.channelCount) ch, \(Int(format.sampleRate)) Hz")

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        print("✅ Recognition request created")

        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.recognitionRequest?.append(buffer)
            self?.updateLevel(from: buffer)
        }
        print("✅ Audio tap installed on input device: \(inputNode.inputFormat(forBus: 0).channelCount) channels")

        audioEngine.prepare()
        try audioEngine.start()
        print("✅ Audio engine started")
        print("✅ Audio engine isRunning: \(audioEngine.isRunning)")

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self?.transcript = text
                }
                // Only log final results
                if result.isFinal {
                    print("🗣️ Final transcript: '\(text)'")
                }
            }
            if let error = error {
                print("❌ Recognition error: \(error)")
                self?.stop()
            }
        }
        print("✅ Recognition started")

        startLevelTimer()
    }

    func stop() {
        print("🛑 SpeechManager.stop() called")
        print("🛑 Current transcript before stopping: '\(transcript)'")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        stopLevelTimer()
        print("🛑 Recording stopped. Final transcript: '\(transcript)'")
    }

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.sampleLevel()
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private var pendingLevel: Float = 0
    private func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let ch = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        var mean: Float = 0
        vDSP_meamgv(ch[0], 1, &mean, vDSP_Length(frames))
        let rms = sqrtf(mean)
        let normalized = min(max(rms * 10, 0), 1)
        pendingLevel = normalized
    }

    private func sampleLevel() {
        // simple smoothing
        let smoothed = (level * 0.8) + (pendingLevel * 0.2)
        if abs(smoothed - level) > 0.001 {
            level = smoothed
        }
    }
}

// NOTE: You may need to add Accelerate to your target for vDSP_meamgv. If not available, replace with simple averaging.
