//
//  SettingsView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultSpeechRate") private var defaultSpeechRate: Double = 0.5
    @AppStorage("autoSaveToHistory") private var autoSaveToHistory: Bool = true
    @AppStorage("includeLinguisticAnalysis") private var includeLinguisticAnalysis: Bool = true
    @AppStorage("includeRomanization") private var includeRomanization: Bool = true
    @AppStorage("reduceMotion") private var reduceMotion: Bool = false
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                // Language Management
                Section {
                    Button {
                        openTranslateSettings()
                    } label: {
                        HStack {
                            Label("Download Languages", systemImage: "arrow.down.circle")
                            Spacer()
                            Image(systemName: "arrow.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Language Management")
                } footer: {
                    Text("Download language packs in iOS Settings to enable offline translation")
                }
                
                // Translation Settings
                Section {
                    Toggle(isOn: $autoSaveToHistory) {
                        Label("Auto-save Translations", systemImage: "clock.arrow.circlepath")
                    }

                    Toggle(isOn: $includeLinguisticAnalysis) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Linguistic Analysis", systemImage: "brain")
                            Text("Show parts of speech and named entities")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $includeRomanization) {
                        Label("Romanization", systemImage: "textformat.abc")
                    }
                } header: {
                    Text("Translation")
                } footer: {
                    Text("Configure default behavior for translations")
                }

                // Audio Settings
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Speech Rate", systemImage: "gauge.with.dots.needle.33percent")
                            Spacer()
                            Text(String(format: "%.1fx", defaultSpeechRate))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(value: $defaultSpeechRate, in: 0.3...0.7, step: 0.1)
                            .tint(.accentColor)
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Default speed for text-to-speech playback")
                }

                // Accessibility Settings
                Section {
                    Toggle(isOn: $reduceMotion) {
                        Label("Reduce Motion", systemImage: "motion.reduce")
                    }

                    Toggle(isOn: $hapticFeedback) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("Customize accessibility features")
                }

                // App Information
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/aljaroudi/Lingko")!) {
                        HStack {
                            Label("GitHub Repository", systemImage: "link")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }

                // Privacy & Data
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(.green)
                            Text("100% On-Device")
                                .fontWeight(.medium)
                        }

                        Text("All translations and data processing happen entirely on your device. No data is ever sent to external servers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private func openTranslateSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    SettingsView()
}
