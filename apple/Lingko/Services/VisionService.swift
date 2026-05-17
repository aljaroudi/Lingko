//
//  VisionService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import Vision
import OSLog
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct VisionService {
    private let logger = Logger(subsystem: "com.lingko.vision", category: "service")

    // MARK: - Text Recognition

    /// Extract text from an image using Vision OCR
    func extractText(from image: PlatformImage) async throws -> [CapturedText] {
        logger.info("📸 Starting text recognition from image")

        #if os(iOS)
        guard let cgImage = image.cgImage else {
            logger.error("Failed to convert UIImage to CGImage")
            throw VisionError.invalidImage
        }
        #elseif os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            logger.error("Failed to convert NSImage to CGImage")
            throw VisionError.invalidImage
        }
        #endif

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

                    return CapturedText(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                self.logger.info("📝 Extracted \(capturedTexts.count) text regions")
                continuation.resume(returning: capturedTexts)
            }

            // Configure recognition request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Support multiple languages
            if #available(iOS 16.0, macOS 13.0, *) {
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

}

// MARK: - Errors

enum VisionError: LocalizedError {
    case invalidImage
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .recognitionFailed(let error):
            return "Text recognition failed: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidImage:
            return "Please try a different image"
        case .recognitionFailed:
            return "Please ensure the image contains clear, readable text"
        }
    }
}
