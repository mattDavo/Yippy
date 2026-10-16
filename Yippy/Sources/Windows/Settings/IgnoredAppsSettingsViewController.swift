//
//  IgnoredAppsSettingsViewController.swift
//  Yippy
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

/// Settings tab listing the apps whose copies Yippy doesn't save.
///
/// Built in code rather than in `Main.storyboard`, and added to the settings tabs by `SettingsTabViewController`.
/// `HistorySettingsViewController` reuses it for another list of apps, by passing a different relay and text.
class IgnoredAppsSettingsViewController: NSViewController {

    private let bundleIdsRelay: BehaviorRelay<[String]>
    private let message: String
    private let prompt: String
    private let isIgnoredAppsList: Bool

    init(
        bundleIds: BehaviorRelay<[String]> = State.main.ignoredAppBundleIds,
        message: String = "Cairn won't save anything copied while one of these apps is in front, e.g. a password manager.",
        prompt: String = "Ignore"
    ) {
        self.bundleIdsRelay = bundleIds
        self.message = message
        self.prompt = prompt
        self.isIgnoredAppsList = bundleIds === State.main.ignoredAppBundleIds
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let tableView = NSTableView()
    private let addRemoveControl = NSSegmentedControl()

    private var bundleIds = [String]()

    private let disposeBag = DisposeBag()

    private static let addSegment = 0
    private static let removeSegment = 1

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 320))

        let label = NSTextField(wrappingLabelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.title = "App"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 24
        tableView.dataSource = self
        tableView.delegate = self
        if isIgnoredAppsList {
            tableView.setAccessibilityIdentifier(Accessibility.identifiers.ignoredAppsTableView)
        }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        addRemoveControl.translatesAutoresizingMaskIntoConstraints = false
        addRemoveControl.segmentCount = 2
        addRemoveControl.trackingMode = .momentary
        addRemoveControl.segmentStyle = .smallSquare
        addRemoveControl.setImage(NSImage(named: NSImage.addTemplateName), forSegment: Self.addSegment)
        addRemoveControl.setImage(NSImage(named: NSImage.removeTemplateName), forSegment: Self.removeSegment)
        addRemoveControl.setWidth(24, forSegment: Self.addSegment)
        addRemoveControl.setWidth(24, forSegment: Self.removeSegment)
        addRemoveControl.target = self
        addRemoveControl.action = #selector(onAddRemoveClicked)
        if isIgnoredAppsList {
            addRemoveControl.setAccessibilityIdentifier(Accessibility.identifiers.ignoredAppsAddRemoveControl)
        }

        view.addSubview(label)
        view.addSubview(scrollView)
        view.addSubview(addRemoveControl)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: label.trailingAnchor),

            addRemoveControl.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -1),
            addRemoveControl.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            addRemoveControl.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
        ])

        self.view = view
        self.preferredContentSize = view.frame.size
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bundleIdsRelay.subscribe(onNext: { [weak self] in
            self?.bundleIds = $0
            self?.tableView.reloadData()
            self?.updateRemoveEnabled()
        }).disposed(by: disposeBag)
    }

    private func updateRemoveEnabled() {
        addRemoveControl.setEnabled(tableView.selectedRow >= 0, forSegment: Self.removeSegment)
    }

    // MARK: Handle Actions

    @objc private func onAddRemoveClicked() {
        if addRemoveControl.selectedSegment == Self.addSegment {
            chooseApps()
        }
        else {
            removeSelected()
        }
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["app"]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = prompt

        guard let window = view.window else {
            return
        }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else {
                return
            }
            let newIds = panel.urls.compactMap({ Bundle(url: $0)?.bundleIdentifier })
            if let ids = Self.add(bundleIds: newIds, to: self.bundleIdsRelay.value) {
                self.bundleIdsRelay.accept(ids)
            }
        }
    }

    private func removeSelected() {
        let row = tableView.selectedRow
        guard bundleIds.indices.contains(row) else {
            return
        }
        var ids = bundleIds
        ids.remove(at: row)
        bundleIdsRelay.accept(ids)
    }

    /// Returns `existing` with any new ids appended, or nil if nothing changed.
    static func add(bundleIds: [String], to existing: [String]) -> [String]? {
        var ids = existing
        for id in bundleIds where !ids.contains(id) {
            ids.append(id)
        }
        return ids == existing ? nil : ids
    }
}

extension IgnoredAppsSettingsViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return bundleIds.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = bundleIds[row]
        let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)

        let cell = NSTableCellView()
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = appUrl.map({ NSWorkspace.shared.icon(forFile: $0.path) }) ?? NSImage(named: NSImage.applicationIconName)
        // Show the bundle id when the app isn't installed any more
        let name = appUrl.map({ FileManager.default.displayName(atPath: $0.path) }) ?? id
        let textField = NSTextField(labelWithString: name)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        textField.toolTip = id
        cell.addSubview(imageView)
        cell.addSubview(textField)
        cell.imageView = imageView
        cell.textField = textField
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18),
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveEnabled()
    }
}
