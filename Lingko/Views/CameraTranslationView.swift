//
//  CameraTranslationView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import PhotosUI
import SwiftData

struct CameraTranslationView: View {
    @State private var visionService = VisionService()
    @State private var translationService = TranslationService()

    @State private var capturedTexts: [CapturedText] = []
    @State private var selectedText: CapturedText?
    @State private var translations: [TranslationResult] = []
    @State private var isProcessing = false

    let initialImage: UIImage
    let selectedLanguages: Set<Locale.Language>
    let autoSaveToHistory: Bool
    let historyService: HistoryService
    let aiService: AIAssistantService
    let tagService: TagService
    let modelContext: ModelContext

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Show image with text overlays
                GeometryReader { geometry in
                    Image(uiImage: initialImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay {
                            // Text overlays
                            ForEach(capturedTexts) { text in
                                TextOverlayView(
                                    capturedText: text,
                                    imageSize: initialImage.size,
                                    containerSize: geometry.size
                                )
                                .onTapGesture {
                                    selectedText = text
                                    Task {
                                        await translateText(text.text)
                                    }
                                }
                            }
                        }
                }
                .ignoresSafeArea()

                // Translation results sheet
                if !translations.isEmpty {
                    VStack {
                        Spacer()

                        translationResultsCard
                            .transition(.move(edge: .bottom))
                    }
                }

                // Processing indicator
                if isProcessing {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .controlSize(.regular)
                            Text("Recognizing text...")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("Image Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await processInitialImage()
            }
        }
    }

    // MARK: - Translation Results Card

    @ViewBuilder
    private var translationResultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Translations")
                        .font(.headline)
                    if let selectedText = selectedText {
                        Text(selectedText.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    withAnimation {
                        translations = []
                        selectedText = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(translations) { translation in
                        TranslationResultCompactRow(result: translation)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Image Processing

    private func processInitialImage() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Extract text from image
            let texts = try await visionService.extractText(from: initialImage)

            await MainActor.run {
                capturedTexts = texts
            }
        } catch {
            print("Failed to process image: \(error)")
        }
    }

    // MARK: - Translation Methods

    private func translateText(_ text: String) async {
        let results = await translationService.translateToAll(
            text: text,
            from: nil,
            to: selectedLanguages,
            includeLinguisticAnalysis: false,
            includeRomanization: true
        )

        await MainActor.run {
            withAnimation {
                translations = results
            }
        }

        // Auto-save to history if enabled
        if autoSaveToHistory && !results.isEmpty {
            await historyService.saveTranslations(
                results,
                sourceText: text,
                context: modelContext,
                aiService: aiService,
                tagService: tagService
            )
        }
    }
}

// MARK: - Text Overlay View

struct TextOverlayView: View {
    let capturedText: CapturedText
    let imageSize: CGSize
    let containerSize: CGSize

    var body: some View {
        let rect = convertBoundingBox(capturedText.boundingBox, imageSize: imageSize, containerSize: containerSize)

        Rectangle()
            .stroke(capturedText.isReliable ? Color.green : Color.yellow, lineWidth: 2)
            .background(capturedText.isReliable ? Color.green.opacity(0.1) : Color.yellow.opacity(0.1))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func convertBoundingBox(_ box: CGRect, imageSize: CGSize, containerSize: CGSize) -> CGRect {
        // Calculate aspect-fit scaled image size
        let aspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        var scaledImageSize: CGSize
        if aspectRatio > containerAspectRatio {
            // Image is wider - fit to width
            scaledImageSize = CGSize(
                width: containerSize.width,
                height: containerSize.width / aspectRatio
            )
        } else {
            // Image is taller - fit to height
            scaledImageSize = CGSize(
                width: containerSize.height * aspectRatio,
                height: containerSize.height
            )
        }

        // Center the scaled image in the container
        let offsetX = (containerSize.width - scaledImageSize.width) / 2
        let offsetY = (containerSize.height - scaledImageSize.height) / 2

        // Convert normalized coordinates (0-1) to screen coordinates
        // Note: Vision uses bottom-left origin, SwiftUI uses top-left
        return CGRect(
            x: offsetX + (box.minX * scaledImageSize.width),
            y: offsetY + ((1 - box.maxY) * scaledImageSize.height),  // Flip Y coordinate
            width: box.width * scaledImageSize.width,
            height: box.height * scaledImageSize.height
        )
    }
}

// MARK: - Compact Translation Result Row

struct TranslationResultCompactRow: View {
    let result: TranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.languageName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(result.translation)
                .font(.body)

            if let romanization = result.romanization {
                Text(romanization)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: SavedTranslation.self, Tag.self,
        configurations: config
    )

    return CameraTranslationView(
        initialImage: UIImage(systemName: "photo")!,
        selectedLanguages: [
            Locale.Language(identifier: "es"),
            Locale.Language(identifier: "fr"),
            Locale.Language(identifier: "de")
        ],
        autoSaveToHistory: true,
        historyService: HistoryService(),
        aiService: AIAssistantService(),
        tagService: TagService(),
        modelContext: container.mainContext
    )
}
