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
    #if os(iOS)
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    #elseif os(macOS)
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                // Language Management
                Section {
                    NavigationLink {
                        LanguageDownloadView(showsDoneButton: false)
                    } label: {
                        Label("Languages", systemImage: "character.bubble")
                    }
                } header: {
                    Text("Language Management")
                }
                
                // Translation Settings
                Section {
                    Toggle(isOn: $autoSaveToHistory) {
                        Label("Auto-save Translations", systemImage: "clock.arrow.circlepath")
                    }

                    Toggle(isOn: $includeLinguisticAnalysis) {
                        Label("Linguistic Analysis", systemImage: "brain")
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

                // Accessibility & System Settings
                Section {
                    Toggle(isOn: $reduceMotion) {
                        Label("Reduce Motion", systemImage: "tortoise")
                   
                    }

                    #if os(iOS)
                    Toggle(isOn: $hapticFeedback) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                    #elseif os(macOS)
                    Toggle(isOn: $launchAtLogin) {
                        Label("Launch at Login", systemImage: "power")
                    }
                    .onChange(of: launchAtLogin) { _, newValue in
                        MacAppDelegate.setLaunchAtLogin(newValue)
                    }
                    .onAppear {
                        launchAtLogin = MacAppDelegate.isLaunchAtLoginEnabled()
                    }
                    #endif
                } header: {
                    #if os(iOS)
                    Text("Accessibility")
                    #elseif os(macOS)
                    Text("Settings")
                    #endif
                } footer: {
                    Text("Customize accessibility features")
                }

                // App Information
                Section("About") {
                    LabeledContent("Version", value: appVersion)

                    Link(destination: URL(string: "https://github.com/aljaroudi/Lingko")!) {
                        Label("Source Code", systemImage: "arrow.up.right")
                    }
                    Link(destination: URL(string: "https://aljaroudi.com")!) {
                        Label("Developer Website", systemImage: "arrow.up.right")
                    }
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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

}

#Preview {
    SettingsView()
}
