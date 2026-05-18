//
//  SpeechService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import Speech
import AVFoundation
import OSLog

@MainActor
@Observable
final class SpeechService {
    private let logger = Logger(subsystem: "com.lingko.speech", category: "service")

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private(set) var isRecording: Bool = false
    private(set) var transcript: String = ""
    private(set) var lastError: String?

    /// Request mic + speech recognition permissions. Returns true if both granted.
    func requestPermissions() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            logger.warning("⚠️ Speech recognition not authorized: \(speechStatus.rawValue)")
            lastError = "Speech recognition permission denied"
            return false
        }

        #if os(iOS)
        let micGranted: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        guard micGranted else {
            logger.warning("⚠️ Microphone access denied")
            lastError = "Microphone permission denied"
            return false
        }
        #endif

        return true
    }

    /// Start streaming recognition for the given locale.
    func startRecording(locale: Locale) throws {
        guard !isRecording else { return }

        recognitionTask?.cancel()
        recognitionTask = nil

        let candidate = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: .current)
        guard let rec = candidate, rec.isAvailable else {
            throw NSError(
                domain: "SpeechService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable for locale \(locale.identifier)"]
            )
        }
        recognizer = rec

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        transcript = ""
        lastError = nil
        isRecording = true
        logger.info("🎙️ Recording started for \(locale.identifier)")

        recognitionTask = rec.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.stopRecording()
                    }
                }
                if let error {
                    self.logger.error("❌ Recognition error: \(error.localizedDescription)")
                    self.lastError = error.localizedDescription
                    self.stopRecording()
                }
            }
        }
    }

    /// Stop recording and recognition.
    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.finish()
        request = nil
        recognitionTask = nil
        isRecording = false
        logger.info("🛑 Recording stopped")
    }
}
