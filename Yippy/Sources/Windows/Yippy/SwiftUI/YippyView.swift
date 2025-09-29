//
//  YippyView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import Cocoa
import HotKey
import RxSwift
import RxRelay
import RxCocoa
import SwiftUI

class SUIYippyViewController: NSHostingController<YippyView> {
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: YippyView())
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if #available(macOS 26, *) {
            self.view.window?.backgroundColor = .clear
        }
    }
}

struct YippyView: View {
    
    enum Focus {
        case searchbar
    }
    
    @Bindable var viewModel = YippyViewModel()
    @FocusState private var focusState: Focus?

    @AppStorage("theme") private var theme: AppearanceTheme = AppearanceTheme.system
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            contentView
                .yippyBackground()
        }
        .padding(.top, NSApplication.isMacOS26 ? 28 : 0)
        .onChange(of: viewModel.isSearchBarFocused) { _, newValue in
            if newValue == true {
                self.focusState = .searchbar
            } else {
                self.focusState = nil
            }
        }
        .colorScheme(theme == .system ? colorScheme : (theme == .light ? .light : .dark))
    }

    @ViewBuilder
    private var contentView: some View {
        if #available(macOS 26, *) {
            liquidDesignView
                .safeAreaPadding(.top, 24)
                .navigationTitle(Text("Yippy"))
        } else {
            oldDesignView
                .safeAreaPadding(.top, 48)
        }
    }

}

@available(macOS 26.0, *)
private extension YippyView {
    private var liquidDesignView: some View {
        VStack(spacing: 4) {
            Text("Yippy")
                .font(.title)

            HStack {
                Text(viewModel.itemCountLabel)
                    .font(.subheadline)

                Spacer()

                Button {
                    showSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17))
                        .padding(.all, 8)
                }
                .buttonStyle(.plain)
                .glassEffect(
                    .clear.interactive(),
                    in: Circle()
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            liquidDesignSearchView

            CategoryFilterView(
                selectedCategory: $viewModel.selectedCategory,
                availableCategories: viewModel.getAvailableCategories()
            )
            .onChange(of: viewModel.selectedCategory) { _, newValue in
                viewModel.onCategorySelected(newValue)
            }

            YippyHistoryTableView(viewModel: viewModel)
                .onAppear(perform: viewModel.onAppear)
                .padding(.vertical, 8)
        }
        .searchable(text: $viewModel.searchBarValue)
    }

    private var liquidDesignSearchView: some View {
        TextField(text: $viewModel.searchBarValue, prompt: Text("Search For Something (􀆔\\)")) {
            Image(systemName: "magnifyingglass")
        }
        .textFieldStyle(.plain)
        .focused($focusState, equals: .searchbar)
        .autocorrectionDisabled()
        .onChange(of: viewModel.searchBarValue) { _, _ in
            viewModel.runSearch()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .glassEffect(in: Capsule())
        .overlay(content: {
            Capsule()
                .stroke(
                    colorScheme == .light ? Color.black.opacity(0.3) : Color.white.opacity(0.3),
                    lineWidth: 1
                )
        })
        .padding(.horizontal, 16)
    }
}

private extension YippyView {
    private var oldDesignView: some View {
        VStack(spacing: 4) {
            ZStack {
                Text("Yippy")
                    .font(.title)

                HStack {
                    Spacer()

                    Text(viewModel.itemCountLabel)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 8)

            TextField(text: $viewModel.searchBarValue, prompt: Text("Search For Something (􀆔\\)")) {
                Image(systemName: "magnifyingglass")
            }
            .focused($focusState, equals: .searchbar)
            .autocorrectionDisabled()
            .border(.secondary)
            .onChange(of: viewModel.searchBarValue) { _, _ in
                viewModel.runSearch()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            CategoryFilterView(
                selectedCategory: $viewModel.selectedCategory,
                availableCategories: viewModel.getAvailableCategories()
            )
            .onChange(of: viewModel.selectedCategory) { _, newValue in
                viewModel.onCategorySelected(newValue)
            }
            .padding(.bottom, 8)

            YippyHistoryTableView(viewModel: viewModel)
                .onAppear(perform: viewModel.onAppear)
                .padding(.vertical, 8)
        }
    }
}

struct YippyHistoryTableView: View {
    
    @Bindable var viewModel: YippyViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView(viewModel.panelPosition) {
                    if viewModel.panelPosition == .horizontal {
                        LazyHStack(spacing: 12) {
                            content(proxy: proxy, isVertical: false)
                        }
                    } else {
                        LazyVStack(spacing: 4) {
                            content(proxy: proxy, isVertical: true)
                                .padding(.top, 8)
                        }
                    }
                }
                .onChange(of: viewModel.selectedItem) { oldValue, newValue in
                    if let value = newValue {
                        reader.scrollTo(value)
                    }
                }
            }
        }
        .environment(\.historyCellSettings, HistoryCellSettings())
    }

    func content(proxy: GeometryProxy, isVertical: Bool) -> some View {
        ForEach(Array(viewModel.yippyHistory.items.enumerated()), id: \.element) { (index, item) in
            HistoryCellView(item: item, proxy: proxy, usingItemRtf: viewModel.isRichText)
                .yippyRowBackground(colorScheme: colorScheme)
                .overlay(alignment: .topLeading) {
                    if index < 10 {
                        VStack {
                            HStack {
                                Spacer()

                                (Text(Image(systemName: "command")) + Text("+ \(index)"))
                                    .font(.system(size: 10))
                                    .padding(.all, 4)
                                    .foregroundStyle(Color.white)
                                    .background(
                                        RoundedRectangle(
                                            cornerRadius: NSApplication.isMacOS26 ? 16 : 7,
                                            style: .continuous
                                        )
                                        .fill(Color.accentColor)
                                    )
                                    .padding(4)
                            }

                            Spacer()
                        }
                    }

                    if viewModel.selectedItem == item {
                        RoundedRectangle(
                            cornerRadius: NSApplication.isMacOS26 ? 16 : 7,
                            style: .continuous
                        )
                        .stroke(Color.accentColor, lineWidth: 6)
                    }
                }
                .onTapGesture {
                    viewModel.onSelectItem(at: index)
                }
                .contextMenu(menuItems: {
                    Button {
                        viewModel.paste(at: index)
                    } label: {
                        Label("Copy", systemImage: "document.on.document")
                    }

                    Button(role: .destructive) {
                        viewModel.delete(at: index)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                })
                .draggable(item)
        }
    }
}

extension YippyView {
    func showSettings() {
        Controller.main.settingsWindowController.showWindow(nil)
    }
}


extension NSApplication {
    static var isMacOS26: Bool {
        if #available(macOS 26, *) {
            true
        } else {
            false
        }
    }
}

private extension View {
    @ViewBuilder
    func yippyBackground() -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(
                    .clear.tint(Color.accentColor.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 36)
                )
                .padding(8)
        } else {
            self
                .materialBlur(style: .sidebar)
        }
    }

    @ViewBuilder
    func yippyRowBackground(colorScheme: ColorScheme) -> some View {
        if #available(macOS 26, *) {
            self
                .clipShape(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .glassEffect(
                    .regular.tint(colorScheme == .dark ? nil : .accentColor.opacity(0.2)).interactive(),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        } else {
            self
                .clipShape(
                    RoundedRectangle(cornerRadius: 7)
                )
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(NSColor.windowBackgroundColor))
                )
        }
    }
}
