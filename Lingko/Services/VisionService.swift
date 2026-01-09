//
//  VisionService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import Vision
import CoreImage
import OSLog
import UIKit

@MainActor
struct VisionService {
    private let logger = Logger(subsystem: "com.lingko.vision", category: "service")

    // MARK: - Text Recognition

    /// Extract text from an image using Vision OCR
    func extractText(from image: UIImage) async throws -> [CapturedText] {
        logger.info("📸 Starting text recognition from image")

        guard let cgImage = image.cgImage else {
            logger.error("Failed to convert UIImage to CGImage")
            throw VisionError.invalidImage
        }

        return try await recognizeText(in: cgImage)
    }

    /// Extract text from a CIImage
    func extractText(from ciImage: CIImage) async throws -> [CapturedText] {
        logger.info("📸 Starting text recognition from CIImage")

        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            logger.error("Failed to convert CIImage to CGImage")
            throw VisionError.invalidImage
        }

        return try await recognizeText(in: cgImage)
    }

    // MARK: - Private Methods

    private func recognizeText(in cgImage: CGImage) async throws -> [CapturedText] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    self.logger.error("❌ Text recognition failed: \(error.localizedDescription)")
                    continuation.resume(throwing: VisionError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self.logger.warning("⚠️ No text observations found")
                    continuation.resume(returning: [])
                    return
                }

                self.logger.info("✅ Found \(observations.count) text observations")

                let capturedTexts = observations.compactMap { observation -> CapturedText? in
                    guard let topCandidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    // Get language hints if available
                    var detectedLanguage: String?
                    if #available(iOS 16.0, *) {
                        // iOS 16+ has language support in Vision
                        detectedLanguage = nil  // Language detection handled separately
                    }

                    return CapturedText(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: observation.boundingBox,
                        detectedLanguage: detectedLanguage
                    )
                }

                self.logger.info("📝 Extracted \(capturedTexts.count) text regions")
                continuation.resume(returning: capturedTexts)
            }

            // Configure recognition request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Support multiple languages
            if #available(iOS 16.0, *) {
                request.recognitionLanguages = ["en-US", "es-ES", "fr-FR", "de-DE", "ja-JP", "zh-Hans", "zh-Hant", "ar", "ko", "ru"]
            }

            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                self.logger.error("❌ Failed to perform Vision request: \(error.localizedDescription)")
                continuation.resume(throwing: VisionError.recognitionFailed(error))
            }
        }
    }

    // MARK: - Language Detection

    /// Detect language in recognized text
    func detectLanguage(in text: String) -> String? {
        logger.debug("🔍 Detecting language for text: \(text.prefix(50))...")

        if #available(iOS 16.0, *) {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)

            if let dominantLanguage = recognizer.dominantLanguage {
                logger.info("✅ Detected language: \(dominantLanguage.rawValue)")
                return dominantLanguage.rawValue
            }
        }

        logger.warning("⚠️ Could not detect language")
        return nil
    }
}

// MARK: - Errors

enum VisionError: LocalizedError {
    case invalidImage
    case recognitionFailed(Error)
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .recognitionFailed(let error):
            return "Text recognition failed: \(error.localizedDescription)"
        case .noTextFound:
            return "No text found in image"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidImage:
            return "Please try a different image"
        case .recognitionFailed:
            return "Please ensure the image contains clear, readable text"
        case .noTextFound:
            return "Please capture an image with visible text"
        }
    }
}

// MARK: - NaturalLanguage Import

import NaturalLanguage
