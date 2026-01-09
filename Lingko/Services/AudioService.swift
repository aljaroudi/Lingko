//
//  AudioService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import AVFoundation
import OSLog

@MainActor
final class AudioService {
    private let logger = Logger(subsystem: "com.lingko.audio", category: "service")
    private let synthesizer: AVSpeechSynthesizer

    init() {
        self.synthesizer = AVSpeechSynthesizer()
        configureAudioSession()
        logger.info("🔊 AudioService initialized")
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true, options: [])
            logger.debug("✅ Audio session configured")
        } catch {
            logger.error("❌ Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Speech Control

    /// Speak the given text in the specified language
    func speak(text: String, language: Locale.Language, rate: Float = 0.5) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Empty text provided for speech")
            return
        }

        // Stop any currently playing speech
        if synthesizer.isSpeaking {
            logger.info("🔇 Stopping previous speech")
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Create voice for language
        let languageCode = language.minimalIdentifier
        let voice = AVSpeechSynthesisVoice(language: languageCode)

        // List available voices for debugging
        let availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(languageCode) }
        logger.debug("Available voices for \(languageCode): \(availableVoices.count)")

        if voice == nil {
            logger.warning("⚠️  Voice not found for language: \(languageCode), using default")
        } else {
            logger.debug("Using voice: \(voice?.name ?? "unknown") - Quality: \(voice?.quality.rawValue ?? 0)")
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = max(0.0, min(1.0, rate))  // Clamp between 0.0 and 1.0
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        logger.info("🔊 Speaking text in \(languageCode) at rate \(utterance.rate)")
        logger.debug("📝 Text to speak: \(text.prefix(50))...")

        synthesizer.speak(utterance)

        // Check if actually speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if self.synthesizer.isSpeaking {
                self.logger.debug("✅ Speech is playing")
            } else {
                self.logger.warning("⚠️  Speech did not start - this may be a simulator limitation")
            }
        }
    }

    /// Stop the current speech immediately
    func stop() {
        if synthesizer.isSpeaking {
            logger.info("🔇 Stopping speech")
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Pause the current speech
    func pause() {
        if synthesizer.isSpeaking && !synthesizer.isPaused {
            logger.info("⏸️  Pausing speech")
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    /// Resume paused speech
    func resume() {
        if synthesizer.isPaused {
            logger.info("▶️  Resuming speech")
            synthesizer.continueSpeaking()
        }
    }

    // MARK: - State

    /// Whether the synthesizer is currently speaking
    var isPlaying: Bool {
        synthesizer.isSpeaking
    }

    /// Whether the synthesizer is currently paused
    var isPaused: Bool {
        synthesizer.isPaused
    }
}
