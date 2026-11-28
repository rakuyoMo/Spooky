import AppKit
import SwiftUI

// MARK: - SymbolCatalog

/// 可选的系统符号：按系统符号库的顺序列出，各语言文字的变体不单列。
enum SymbolCatalog {
    /// 各语言文字变体的名字后缀：变体名是 “基本名.后缀”，由系统按语言选用，不单列。
    private static let scriptSuffixes: Set = [
        "ar", "bn", "el", "gu", "he", "hi", "ja", "km", "kn", "ko", "ml", "mni",
        "mr", "my", "or", "pa", "rtl", "ru", "sat", "si", "ta", "te", "th", "zh",
    ]

    /// 全部可选的符号名，第一次用到时从系统符号库读出；读不到时为空，仍可输入完整的符号名。
    static let names: [String] = {
        let order = Bundle(path: "/System/Library/CoreServices/CoreGlyphs.bundle")?
            .url(forResource: "symbol_order", withExtension: "plist")
            .flatMap { try? Data(contentsOf: $0) }

        let names = order.flatMap {
            try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String]
        }

        return withoutScriptVariants(names ?? [])
    }()

    /// 去掉各语言文字的变体：名字以变体后缀结尾、去掉后缀的基本名也在列表里时不列出。
    ///
    /// - Parameter names: 系统符号库列出的全部名字。
    static func withoutScriptVariants(_ names: [String]) -> [String] {
        let all = Set(names)

        return names.filter { name in
            guard let dot = name.lastIndex(of: ".") else {
                return true
            }

            return !scriptSuffixes.contains(String(name[name.index(after: dot)...]))
                || !all.contains(String(name[..<dot]))
        }
    }

    /// 按搜索词筛选：搜索词按空白拆开，每一段都出现在名字里的符号才列出，不区分大小写；
    /// 搜索词正好是一个不在列表里的符号名时，把它排在最前面。
    ///
    /// - Parameters:
    ///   - query: 搜索框里的文字。
    ///   - names: 可选的符号名。
    static func search(_ query: String, in names: [String]) -> [String] {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace)

        guard !terms.isEmpty else {
            return names
        }

        let matches = names.filter { name in terms.allSatisfy { name.contains($0) } }
        let exact = query.trimmingCharacters(in: .whitespaces)

        guard
            !matches.contains(exact),
            NSImage(systemSymbolName: exact, accessibilityDescription: nil) != nil
        else { return matches }

        return [exact] + matches
    }
}

// MARK: - SymbolPickerButton

/// 选图标的按钮：显示当前的符号，点按弹出符号面板，选中一个后面板关闭。
struct SymbolPickerButton: View {
    /// 选中的符号名。
    @Binding
    var symbol: String

    /// 符号面板是否弹出。
    @State
    private var isPresented = false

    /// 带边框的按钮，图标 16 pt；辅助功能读出选中的符号名。
    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .frame(width: 32, height: 22)
        }
        .accessibilityValue(symbol)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SymbolPicker(selection: $symbol) {
                isPresented = false
            }
        }
    }
}

// MARK: - SymbolPicker

/// 符号面板：上面是搜索框，下面是每行 10 个、可以滚动的符号网格；选中的符号带强调色的底，点一个符号就选中它。
struct SymbolPicker: View {
    /// 选中的符号名。
    @Binding
    var selection: String

    /// 选中之后关闭面板。
    let done: () -> Void

    /// 搜索框里的文字。
    @State
    private var query = ""

    /// 搜索框、网格或没有结果的说明。
    var body: some View {
        let results = SymbolCatalog.search(query, in: SymbolCatalog.names)

        VStack(spacing: 8) {
            TextField("", text: $query, prompt: Text(AppLocalization.text("action.search")))
                .textFieldStyle(.roundedBorder)

            if results.isEmpty {
                Text(AppLocalization.text("toolbarButtons.symbols.empty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                grid(results)
            }
        }
        .padding(12)
        .frame(width: 380, height: 320)
    }
}

// MARK: - Private

extension SymbolPicker {
    /// 符号网格；打开时滚到选中的符号。
    private func grid(_ names: [String]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 10),
                    spacing: 4
                ) {
                    ForEach(names, id: \.self) { name in
                        cell(name)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
    }

    /// 一个符号：32 pt 见方，名字写在提示与辅助功能里。
    private func cell(_ name: String) -> some View {
        Button {
            selection = name
            done()
        } label: {
            Image(systemName: name)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background {
                    if name == selection {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.25))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
    }
}
