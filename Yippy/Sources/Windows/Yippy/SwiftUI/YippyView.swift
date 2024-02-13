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
}

struct YippyView: View {
    
    enum Focus {
        case searchbar
    }
    
    @Bindable var viewModel = YippyViewModel()
    @FocusState private var focusState: Focus?
    
    var body: some View {
        NavigationStack {
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
                
                YippyHistoryTableView(viewModel: viewModel)
                    .onAppear(perform: viewModel.onAppear)
            }
        }
        .safeAreaPadding(.top, 48)
        .materialBlur(style: .sidebar)
        .onChange(of: viewModel.isSearchBarFocused) { _, newValue in
            if newValue == true {
                self.focusState = .searchbar
            } else {
                self.focusState = nil
            }
        }
    }
}

struct YippyHistoryTableView: View {
    
    @Bindable var viewModel: YippyViewModel
    
    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView(viewModel.panelPosition) {
                    if viewModel.panelPosition == .horizontal {
                        LazyHStack(spacing: 12) {
                            content(proxy: proxy)
                        }
                    } else {
                        LazyVStack(spacing: 4) {
                            content(proxy: proxy)
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
    
    func content(proxy: GeometryProxy) -> some View {
        ForEach(Array(viewModel.yippyHistory.items.enumerated()), id: \.element) { (index, item) in
            HistoryCellView(item: item, proxy: proxy, usingItemRtf: viewModel.isRichText)
                .clipShape(
                    RoundedRectangle(cornerRadius: 7)
                )
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(NSColor.windowBackgroundColor))
                )
                .overlay {
                    ZStack(alignment: .topLeading) {
                        if index < 10 {
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    Text("􀆔 + \(index)")
                                        .font(.system(size: 10))
                                        .padding(.all, 4)
                                        .foregroundStyle(Color.white)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.accentColor)
                                        )
                                }
                                
                                Spacer()
                            }
                        }
                        
                        if viewModel.selectedItem == item {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.accentColor, lineWidth: 6)
                        }
                    }
                }
                .onTapGesture {
                    viewModel.onSelectItem(at: index)
                }
                .contextMenu(
                    ContextMenu(menuItems: {
                        Button("Copy") {
                            viewModel.paste(at: index)
                        }
                        
                        Button("Delete") {
                            viewModel.delete(at: index)
                        }
                    })
                )
                .id(item)
                .draggable(item)
        }
    }
}
