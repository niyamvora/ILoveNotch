// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

/// The clipboard tab: search, then click an item (or press Return for the first match) to put it
/// back on the clipboard. Favorites come first and stay.
struct ClipboardView: View {
    let clipboard: ClipboardFeature
    @State private var query = ""
    @FocusState private var searching: Bool

    var body: some View {
        if !clipboard.isRecording {
            FeatureUnavailableView(
                symbol: "doc.on.clipboard", title: "Keep what you copy",
                message: "Text, links, images, and files you copy, kept on this Mac to find and copy again. "
                    + "Passwords and anything marked private are skipped.",
                action: (label: "Turn On", perform: clipboard.startRecording))
        } else if clipboard.access == .asks || clipboard.access == .denied {
            FeatureUnavailableView(
                symbol: "lock", title: "Let ILoveNotch read what you copy",
                message: "In System Settings › Privacy & Security › Paste from Other Apps, set ILoveNotch to "
                    + "Always Allow. Until then macOS would ask each time.",
                action: (
                    label: "Open Privacy Settings",
                    perform: { NSWorkspace.shared.open(.privacySettings("Privacy_Pasteboard")) }
                )
            )
            .onAppear(perform: clipboard.refreshAccess)
        } else {
            history
                .onAppear {
                    clipboard.refreshAccess()
                    takeSearch()
                }
                .onChange(of: clipboard.wantsSearch) { takeSearch() }
        }
    }

    private var history: some View {
        let found = clipboard.search(query)
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.caption).opacity(0.6)
                TextField("Search what you copied", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searching)
                    .onSubmit { if let first = found.first { clipboard.pick(first) } }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            if found.isEmpty {
                FeatureUnavailableView(
                    symbol: "doc.on.clipboard", title: clipboard.items.isEmpty ? "Nothing copied yet" : "No matches",
                    message: clipboard.items.isEmpty ? "Copy something and it shows up here." : "Try other words.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(found) { row($0) }
                    }
                    .padding(.vertical, 4)
                }
                .fadingEdges()
            }
        }
    }

    /// The search field takes the keyboard when the tab opened from its shortcut.
    private func takeSearch() {
        guard clipboard.wantsSearch else { return }
        clipboard.wantsSearch = false
        searching = true
    }

    private func row(_ item: ClipItem) -> some View {
        Button {
            clipboard.pick(item)
        } label: {
            HStack(spacing: 8) {
                preview(item)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title(item)).font(.callout).lineLimit(1).truncationMode(.middle)
                    Text(detail(item)).font(.caption2).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    clipboard.toggleFavorite(item)
                } label: {
                    Image(systemName: item.favorite ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(item.favorite ? .yellow : .white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help(item.favorite ? "Remove from favorites" : "Keep as a favorite")
                .accessibilityLabel(item.favorite ? "Favorite" : "Not a favorite")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy again")
        .contextMenu {
            Button("Copy") { clipboard.pick(item) }
            Button(item.favorite ? "Remove from Favorites" : "Add to Favorites") { clipboard.toggleFavorite(item) }
            Divider()
            Button("Delete") { clipboard.remove(item) }
        }
        .accessibilityAction(named: "Delete") { clipboard.remove(item) }
    }

    @ViewBuilder private func preview(_ item: ClipItem) -> some View {
        switch item.kind {
        case .image:
            if let image = clipboard.thumbnail(for: item) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "photo")
            }
        case .files:
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.paths.first ?? "/")).resizable()
        case .link:
            Image(systemName: "link").font(.system(size: 13)).opacity(0.8)
        case .text:
            Image(systemName: "text.alignleft").font(.system(size: 13)).opacity(0.8)
        }
    }

    private func title(_ item: ClipItem) -> String {
        switch item.kind {
        case .files:
            let names = item.paths.map { URL(filePath: $0).lastPathComponent }
            return names.count == 1 ? names[0] : "\(names[0]) and \(names.count - 1) more"
        default:
            return item.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? item.text
        }
    }

    private func detail(_ item: ClipItem) -> String {
        let when = item.copied.formatted(.relative(presentation: .named))
        return [item.source, when].compactMap { $0 }.joined(separator: " · ")
    }
}
