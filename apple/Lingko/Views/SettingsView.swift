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
                    #if os(iOS)
                    Text("Download language packs in iOS Settings to enable offline translation")
                    #elseif os(macOS)
                    Text("Download language packs in System Settings to enable offline translation")
                    #endif
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

                // Accessibility & System Settings
                Section {
                    Toggle(isOn: $reduceMotion) {
                        Label("Reduce Motion", systemImage: "motion.reduce")
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
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
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
    
    private func openTranslateSettings() {
        #if os(iOS)
        PlatformUtils.openSystemSettings(urlString: UIApplication.openSettingsURLString)
        #elseif os(macOS)
        PlatformUtils.openSystemSettings(urlString: "x-apple.systempreferences:com.apple.Translate-Settings")
        #endif
    }
}

#Preview {
    SettingsView()
}
