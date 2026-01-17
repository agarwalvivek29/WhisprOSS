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

        #if os(macOS)
        // Get the system default input device
        var defaultDeviceID: AudioDeviceID = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )

        guard status == noErr, defaultDeviceID != 0 else {
            print("❌ Failed to get default input device")
            throw NSError(domain: "SpeechManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No input device available"])
        }

        // Get device name for logging
        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(defaultDeviceID, &nameAddress, 0, nil, &nameSize, &deviceName)
        print("🎤 Using input device: \(deviceName) (ID: \(defaultDeviceID))")

        // Get the device's native sample rate
        var sampleRate: Float64 = 0
        var sampleRateSize = UInt32(MemoryLayout<Float64>.size)
        var sampleRateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let sampleRateStatus = AudioObjectGetPropertyData(
            defaultDeviceID,
            &sampleRateAddress,
            0,
            nil,
            &sampleRateSize,
            &sampleRate
        )

        if sampleRateStatus == noErr && sampleRate > 0 {
            print("🎤 Device native sample rate: \(Int(sampleRate)) Hz")
        } else {
            sampleRate = 48000 // Fallback
            print("⚠️ Could not get device sample rate, using fallback: \(Int(sampleRate)) Hz")
        }

        // Stop and reset audio engine to ensure clean state
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()

        // Set the input device on the audio unit
        let inputNode = audioEngine.inputNode
        if let audioUnit = inputNode.audioUnit {
            var deviceIDToSet = defaultDeviceID
            let setStatus = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceIDToSet,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if setStatus != noErr {
                print("⚠️ Failed to set audio input device (status: \(setStatus))")
            }
        }

        // Get the format AFTER setting the device - use the hardware format
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        print("✅ Hardware format: \(hardwareFormat.channelCount) ch, \(Int(hardwareFormat.sampleRate)) Hz")

        // Use nil format to let AVAudioEngine handle format conversion automatically
        // This is more robust for different audio devices (especially Bluetooth)
        let tapFormat: AVAudioFormat?
        if hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 {
            tapFormat = hardwareFormat
            print("✅ Using hardware format for tap")
        } else {
            tapFormat = nil
            print("✅ Using automatic format for tap (nil)")
        }
        #else
        let inputNode = audioEngine.inputNode
        let tapFormat = inputNode.outputFormat(forBus: 0)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        print("✅ Recognition request created")

        // Remove any existing tap
        inputNode.removeTap(onBus: 0)

        // Install tap with the compatible format
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, time in
            self?.recognitionRequest?.append(buffer)
            self?.updateLevel(from: buffer)
        }
        print("✅ Audio tap installed")

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
                if result.isFinal {
                    print("🗣️ Final transcript: '\(text)'")
                }
            }
            if let error = error {
                print("❌ Recognition error: \(error)")
                // Don't call stop() here to avoid recursive issues
            }
        }
        print("✅ Recognition started")

        startLevelTimer()
    }

    func stop() {
        print("🛑 SpeechManager.stop() called")
        print("🛑 Current transcript before stopping: '\(transcript)'")

        // Stop in the correct order to avoid race conditions
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()

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
