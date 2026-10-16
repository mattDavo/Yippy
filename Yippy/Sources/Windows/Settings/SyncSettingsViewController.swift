//
//  SyncSettingsViewController.swift
//  Yippy
//

import Foundation
import Cocoa
import RxSwift

/// Settings tab for syncing the clipboard history and favourites with other computers through a sync server.
///
/// Built in code like `HistorySettingsViewController`. Only added on macOS 10.15 and later, where `SyncCoordinator` runs.
@available(macOS 10.15, *)
@MainActor
class SyncSettingsViewController: NSViewController {

    private let sync: SyncCoordinator

    private let serverField = NSTextField()
    private let accessKeyField = NSSecureTextField()
    private let keyField = NSTextField()
    private let turnOnButton = NSButton(title: "Turn On Sync", target: nil, action: nil)
    private let turnOffButton = NSButton(title: "Turn Off", target: nil, action: nil)
    private let eraseButton = NSButton(title: "Erase Synced Data…", target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")

    private let disposeBag = DisposeBag()

    init(sync: SyncCoordinator) {
        self.sync = sync
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 380))

        let intro = NSTextField(wrappingLabelWithString: "Sync your clipboard history and favourites with your other computers through your own sync server. Everything is encrypted with the sync key before it leaves this Mac.")

        serverField.placeholderString = "https://sync.example.com"
        accessKeyField.placeholderString = "Only if the server asks for one"
        keyField.placeholderString = "Leave empty to make a new key"
        keyField.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        for field in [serverField, accessKeyField, keyField] {
            field.lineBreakMode = .byTruncatingTail
            field.usesSingleLineMode = true
        }

        let newKeyButton = NSButton(title: "New Key", target: self, action: #selector(onNewKey))
        let copyKeyButton = NSButton(title: "Copy", target: self, action: #selector(onCopyKey))
        let keyNote = note("Enter the same server and sync key on each computer. Copying the key here doesn't add it to the history.")

        let grid = NSGridView(views: [
            [label("Server:"), serverField],
            [label("Access key:"), accessKeyField],
            [label("Sync key:"), keyField],
            [NSGridCell.emptyContentView, row([newKeyButton, copyKeyButton])],
            [NSGridCell.emptyContentView, keyNote],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.rowSpacing = 8
        grid.columnSpacing = 8

        turnOnButton.target = self
        turnOnButton.action = #selector(onTurnOn)
        turnOnButton.keyEquivalent = "\r"
        turnOffButton.target = self
        turnOffButton.action = #selector(onTurnOff)
        eraseButton.target = self
        eraseButton.action = #selector(onErase)
        let buttons = row([turnOnButton, turnOffButton, eraseButton])

        messageLabel.textColor = .systemRed
        messageLabel.isHidden = true
        statusLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [intro, grid, buttons, messageLabel, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
            intro.widthAnchor.constraint(equalTo: stack.widthAnchor),
            grid.widthAnchor.constraint(equalTo: stack.widthAnchor),
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        self.view = view
        self.preferredContentSize = view.frame.size
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        serverField.stringValue = sync.serverAddress
        accessKeyField.stringValue = sync.accessKey
        keyField.stringValue = sync.keyText ?? ""

        sync.status.subscribe(onNext: { [weak self] status in
            self?.statusLabel.stringValue = Self.describe(status)
            self?.updateButtons()
        }).disposed(by: disposeBag)
    }

    private func updateButtons() {
        turnOnButton.title = sync.isOn ? "Save Changes" : "Turn On Sync"
        turnOffButton.isEnabled = sync.isOn
        eraseButton.isEnabled = sync.isOn
    }

    private static func describe(_ status: SyncStatus) -> String {
        switch status {
        case .off:
            return "Off. Copies and favourites stay on this Mac."
        case .connecting:
            return "Connecting…"
        case .upToDate(let lastSynced):
            return "Up to date. Last synced \(DateFormatter.localizedString(from: lastSynced, dateStyle: .none, timeStyle: .short))."
        case .offline(let message):
            return "Offline: \(message) Changes are sent when the server is back."
        case .refused(let message):
            return "Not syncing: \(message)"
        }
    }

    private func show(message: String?) {
        messageLabel.stringValue = message ?? ""
        messageLabel.isHidden = message == nil
    }

    // MARK: - Actions

    @objc private func onNewKey() {
        if !keyField.stringValue.isEmpty && !confirm("New Sync Key", "Make a new sync key? Computers using the old one won't see what this Mac syncs until you enter the new key on them.", button: "Make New Key") {
            return
        }
        keyField.stringValue = SyncKey.generate().text
    }

    @objc private func onCopyKey() {
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            sync.copyWithoutSaving(key)
        }
    }

    @objc private func onTurnOn() {
        let message = sync.turnOn(serverAddress: serverField.stringValue, accessKey: accessKeyField.stringValue, keyText: keyField.stringValue)
        show(message: message)
        if message == nil {
            serverField.stringValue = sync.serverAddress
            keyField.stringValue = sync.keyText ?? keyField.stringValue
        }
        updateButtons()
    }

    @objc private func onTurnOff() {
        sync.turnOff()
        show(message: nil)
        updateButtons()
    }

    @objc private func onErase() {
        guard confirm("Erase Synced Data", "Delete everything this sync key stored on the server and turn sync off? Items stay on this Mac. Other computers stop syncing until you set up a new key.", button: "Erase") else {
            return
        }
        eraseButton.isEnabled = false
        sync.eraseServerData { [weak self] message in
            guard let self = self else {
                return
            }
            self.show(message: message)
            if message == nil {
                self.keyField.stringValue = ""
            }
            self.updateButtons()
        }
    }

    // MARK: - Views

    private func label(_ text: String) -> NSTextField {
        return NSTextField(labelWithString: text)
    }

    private func note(_ text: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.textColor = .secondaryLabelColor
        field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        return field
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    private func confirm(_ title: String, _ text: String, button: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
