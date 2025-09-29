//
//  SettingsWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 28/2/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI
import HotKey

class SettingsWindowController: NSWindowController {
    
    static func createSettingsWindowController() -> SettingsWindowController {
        let window = NSWindow(contentViewController: SettingsHostingViewController(rootView: SettingsView()))
        let controller = SettingsWindowController(window: window)
        return controller
    }
}

class SettingsHostingViewController: NSHostingController<SettingsView> {
    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        super.init(coder: coder, rootView: SettingsView())
    }

    override init(rootView: SettingsView) {
        super.init(rootView: rootView)
    }
}

enum AppearanceTheme: String, CaseIterable, Codable {
    case system
    case light
    case dark
}

struct SettingsView: View {
    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case shortcuts = "Hot keys"
        case about = "About"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .shortcuts: return "keyboard"
            case .about: return "info.circle"
            }
        }

        var color: Color {
            switch self {
            case .general:
                Color.green
            case .appearance:
                Color.blue
            case .shortcuts:
                Color.orange
            case .about:
                Color.red
            }
        }
    }

    @SwiftUI.State private var selection: SettingsSection? = .general
    @AppStorage("useCompactUI") private var useCompactUI: Bool = false
    @AppStorage("theme") private var theme: AppearanceTheme = AppearanceTheme.system // system, light, dark

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases) { section in
                HStack(spacing: 4) {
                    Image(systemName: section.systemImage)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(section.color)
                        )

                    Text(section.rawValue)
                }
                .onTapGesture {
                    selection = section
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.all, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selection == section ? Color.accentColor : .clear)
                )
            }
            .navigationTitle("Preferences")
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selection {
                case .general: GeneralSettingsView()
                case .appearance: AppearanceSettingsView(theme: $theme, useCompactUI: $useCompactUI)
                case .shortcuts: ShortcutsSettingsView()
                case .about: AboutSettingsView()
                case .none: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .formStyle(.grouped)
        }
        .frame(minWidth: 640, minHeight: 420)
        .colorScheme(theme == .system ? colorScheme : (theme == .light ? .light : .dark))
    }
}

private struct GeneralSettingsView: View {
    @SwiftUI.State private var launchAtLogin: Bool = true
    @SwiftUI.State private var maxStoredItems: Int = 500
    @SwiftUI.State private var showsRichText: Bool = true
    @SwiftUI.State private var isRichTextWhenPasting: Bool = true

    var body: some View {
        Form {
            Section("Launch") {
                Toggle("Launch at login", isOn: $launchAtLogin)
//                Toggle("Show in menu bar", isOn: $showInMenuBar)
            }
            Section("Rich Text") {
                Toggle("Show rich text", isOn: $showsRichText)

                Toggle("Use rich text when pasting", isOn: $isRichTextWhenPasting)
            }
            Section("Others") {
                Picker("Maximum number of stored items", selection: $maxStoredItems) {
                    ForEach(Constants.settings.maxHistoryItemsOptions, id: \.self) { number in
                        Text("\(number)").tag(number)
                    }
                }

                Button("Clear history", role: .destructive) {
                    State.main.history.clear()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("General")
        .onChange(of: maxStoredItems) { _, newValue in
            Settings.main.maxHistory = newValue
            State.main.history.setMaxItems(newValue)
        }
        .onChange(of: showsRichText) { _, newValue in
            State.main.showsRichText.accept(newValue)
        }
        .onChange(of: isRichTextWhenPasting) { _, newValue in
            State.main.pastesRichText.accept(newValue)
        }
        .onChange(of: launchAtLogin) { _, newValue in
            State.main.launchAtLogin.accept(newValue)
        }
        .onAppear {
            showsRichText = State.main.showsRichText.value
            isRichTextWhenPasting = State.main.pastesRichText.value
            launchAtLogin = State.main.launchAtLogin.value
            maxStoredItems = Settings.main.maxHistory
        }
    }
}

private struct AppearanceSettingsView: View {
    @Binding var theme: AppearanceTheme
    @Binding var useCompactUI: Bool

    @SwiftUI.State private var position: PanelPosition = .bottom

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $theme) {
                    Text("System").tag(AppearanceTheme.system)
                    Text("Light").tag(AppearanceTheme.light)
                    Text("Dark").tag(AppearanceTheme.dark)
                }
                .pickerStyle(.segmented)
            }

            Section("Interface") {
                Picker("Position", selection: $position) {
                    ForEach(PanelPosition.allCases, id: \.identifier) { pos in
                        Text(pos.title).tag(pos)
                    }
                }
            }
        }
        .onChange(of: position, { _, newValue in
            State.main.panelPosition.accept(newValue)
        })
        .onAppear {
            position = State.main.panelPosition.value
        }
        .navigationTitle("Appearance")
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
                VStack(alignment: .leading) {
                    Text(Bundle.main.appName)
                        .font(.title2)
                        .bold()
                    Text("App version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            Text("© \(Calendar.current.component(.year, from: .now)) Matthew Davidson")
                .foregroundStyle(.secondary)
            Link("Github", destination: URL(string: "https://github.com/")!)
        }
        .navigationTitle("About")
    }
}

private extension Bundle {
    var appName: String { object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Приложение" }
    var appVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }
    var appBuild: String { object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "" }
}
