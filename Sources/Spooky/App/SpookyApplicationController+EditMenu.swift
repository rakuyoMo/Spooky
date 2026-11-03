import AppKit

// MARK: - Edit Menu

extension SpookyApplicationController {
    /// Edit 菜单：撤销与重做、系统文本动作、提交信息的段落重排，以及查找、拼写与语法、替换、大小写转换与朗读五个子菜单。
    ///
    /// 除查找框的聚焦外，各项都不指定 target，经响应链交给第一响应者，由它决定是否可用。
    func configureEditMenu(in menu: NSMenu) {
        let edit = addMenu("menu.edit", to: menu)

        // 标题与可用性由窗口的撤销管理器在每次打开菜单时给出
        addItem("menu.undo", action: Selector(("undo:")), key: "z", to: edit)
        addItem("menu.redo", action: Selector(("redo:")), key: "z", modifiers: [.command, .shift], to: edit)

        edit.addItem(.separator())
        configureClipboardItems(in: edit)

        edit.addItem(.separator())
        addItem(
            "commit.reformatParagraph",
            action: #selector(CommitMessageTextView.reformatParagraph(_:)),
            key: "w",
            modifiers: [.command, .shift],
            to: edit
        )

        edit.addItem(.separator())
        configureFindMenu(in: edit)
        configureSpellingMenu(in: edit)
        configureSubstitutionsMenu(in: edit)
        configureTransformationsMenu(in: edit)
        configureSpeechMenu(in: edit)
    }

    /// 剪切、拷贝、粘贴、粘贴并匹配样式、删除与全选。
    ///
    /// Delete 只在第一响应者实现 `delete:` 时可用；不可用时 ⌘⌫ 照常交给列表与文本框自己的按键处理。
    private func configureClipboardItems(in edit: NSMenu) {
        addItem("menu.cut", action: #selector(NSText.cut(_:)), key: "x", to: edit)
        addItem("menu.copy", action: #selector(NSText.copy(_:)), key: "c", to: edit)
        addItem("menu.paste", action: #selector(NSText.paste(_:)), key: "v", to: edit)
        addItem(
            "menu.pasteAndMatchStyle",
            action: #selector(NSTextView.pasteAsPlainText(_:)),
            key: "v",
            modifiers: [.option, .shift, .command],
            to: edit
        )
        addItem("menu.delete", action: #selector(NSText.delete(_:)), key: "\u{8}", to: edit)
        addItem("menu.selectAll", action: #selector(NSText.selectAll(_:)), key: "a", to: edit)
    }

    /// Find 子菜单：聚焦工具栏搜索框（按住 ⌥ 为 Search），以及文本区查找栏的查找下一个、上一个、用所选内容查找与跳到所选内容。
    private func configureFindMenu(in edit: NSMenu) {
        let find = addMenu("menu.find", to: edit)
        addItem("action.find", action: #selector(RepositoryWindowController.focusSearch), key: "f", to: find)

        // 按住 ⌥ 时 Find… 换成 Search，同样聚焦工具栏搜索框
        let search = NSMenuItem(
            title: AppLocalization.text("action.search"),
            action: #selector(RepositoryWindowController.focusSearch),
            keyEquivalent: "f"
        )
        search.keyEquivalentModifierMask = [.command, .option]
        search.isAlternate = true
        find.addItem(search)

        // 查找栏的三个动作共用一个方法，由 tag 区分
        let findPanelAction = #selector(NSTextView.performFindPanelAction(_:))
        addItem("menu.findNext", action: findPanelAction, key: "g", to: find)
        find.items.last?.tag = Int(NSFindPanelAction.next.rawValue)

        addItem(
            "menu.findPrevious",
            action: findPanelAction,
            key: "g",
            modifiers: [.command, .shift],
            to: find
        )
        find.items.last?.tag = Int(NSFindPanelAction.previous.rawValue)

        addItem("menu.useSelectionForFind", action: findPanelAction, key: "e", to: find)
        find.items.last?.tag = Int(NSFindPanelAction.setFindString.rawValue)

        addItem(
            "menu.jumpToSelection",
            action: #selector(NSResponder.centerSelectionInVisibleArea(_:)),
            key: "j",
            to: find
        )
    }

    /// Spelling and Grammar 子菜单：拼写与语法面板、立即检查，以及三个检查开关。
    private func configureSpellingMenu(in edit: NSMenu) {
        let spelling = addMenu("menu.spelling", to: edit)
        addItem("menu.showSpelling", action: #selector(NSText.showGuessPanel(_:)), key: ":", to: spelling)
        addItem("menu.checkDocument", action: #selector(NSText.checkSpelling(_:)), key: ";", to: spelling)

        spelling.addItem(.separator())
        addItem(
            "menu.checkSpellingWhileTyping",
            action: #selector(NSTextView.toggleContinuousSpellChecking(_:)),
            to: spelling
        )
        addItem("menu.checkGrammar", action: #selector(NSTextView.toggleGrammarChecking(_:)), to: spelling)
        addItem(
            "menu.correctSpelling",
            action: #selector(NSTextView.toggleAutomaticSpellingCorrection(_:)),
            to: spelling
        )
    }

    /// Substitutions 子菜单：替换面板与五个自动替换开关，都不带快捷键。
    private func configureSubstitutionsMenu(in edit: NSMenu) {
        let substitutions = addMenu("menu.substitutions", to: edit)
        addItem(
            "menu.showSubstitutions",
            action: #selector(NSTextView.orderFrontSubstitutionsPanel(_:)),
            to: substitutions
        )

        substitutions.addItem(.separator())
        addItem(
            "menu.smartCopyPaste",
            action: #selector(NSTextView.toggleSmartInsertDelete(_:)),
            to: substitutions
        )
        addItem(
            "menu.smartQuotes",
            action: #selector(NSTextView.toggleAutomaticQuoteSubstitution(_:)),
            to: substitutions
        )
        addItem(
            "menu.smartDashes",
            action: #selector(NSTextView.toggleAutomaticDashSubstitution(_:)),
            to: substitutions
        )
        addItem(
            "menu.smartLinks",
            action: #selector(NSTextView.toggleAutomaticLinkDetection(_:)),
            to: substitutions
        )
        addItem(
            "menu.textReplacement",
            action: #selector(NSTextView.toggleAutomaticTextReplacement(_:)),
            to: substitutions
        )
    }

    /// Transformations 子菜单：所选文字转大写、小写与首字母大写。
    private func configureTransformationsMenu(in edit: NSMenu) {
        let transformations = addMenu("menu.transformations", to: edit)
        addItem("menu.upperCase", action: #selector(NSResponder.uppercaseWord(_:)), to: transformations)
        addItem("menu.lowerCase", action: #selector(NSResponder.lowercaseWord(_:)), to: transformations)
        addItem("menu.capitalize", action: #selector(NSResponder.capitalizeWord(_:)), to: transformations)
    }

    /// Speech 子菜单：朗读所选文字或全文，以及停止朗读。
    private func configureSpeechMenu(in edit: NSMenu) {
        let speech = addMenu("menu.speech", to: edit)
        addItem("menu.startSpeaking", action: #selector(NSTextView.startSpeaking(_:)), to: speech)
        addItem("menu.stopSpeaking", action: #selector(NSTextView.stopSpeaking(_:)), to: speech)
    }
}
