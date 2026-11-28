import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - CustomToolbarButtonTests

/// 工具栏的自定义按钮：脚本怎样运行、拿到哪些变量，按钮怎样保存，以及工具栏上的标签、点按、编辑与删除。
@MainActor
struct CustomToolbarButtonTests {
    /// 用户在一个框里写脚本，换语言只靠第一行的 `#!`；脚本在仓库根目录运行，失败时错误框里要有输出与退出状态，
    /// 解释器不存在时系统只说脚本文件找不到，要写出 `#!` 这一行才看得出是哪个解释器。
    @Test("脚本按 #! 选解释器、在仓库根目录运行，失败时留下输出与结束的状态")
    func runsScripts() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let variables = CustomToolbarScript.variables(location: location, branch: nil, remotes: [])

        // 没有 #! 时交给 zsh，工作目录是仓库根目录
        try await CustomToolbarScript.run(
            #"print -r -- "$ZSH_VERSION|$(pwd -P)|$SPOOKY_REPOSITORY_PATH" > zsh.txt"#,
            variables: variables,
            location: location
        )

        let zsh = try String(contentsOf: directory.appending(path: "zsh.txt"), encoding: .utf8)

        let fields = zsh
            .trimmingCharacters(in: .newlines)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map(String.init)

        try #require(fields.count == 3)

        #expect(!fields[0].isEmpty)
        #expect(fields[2] == directory.path)

        // pwd -P 给出的是 /private/var 下的真实路径，两边按同一方式解析链接后比较
        #expect(
            URL(fileURLWithPath: fields[1]).resolvingSymlinksInPath().path
                == directory.resolvingSymlinksInPath().path
        )

        // 以 #! 开头时由这一行选解释器
        try await CustomToolbarScript.run(
            "#!/bin/bash\nprintf '%s' \"$BASH_VERSION\" > bash.txt\n",
            variables: variables,
            location: location
        )

        #expect(try !String(contentsOf: directory.appending(path: "bash.txt"), encoding: .utf8).isEmpty)

        // 以非零状态退出：原文是输出，空一行后是退出状态
        let failure = await #expect(throws: CustomToolbarScriptError.self) {
            try await CustomToolbarScript.run("echo broken\nexit 3", variables: variables, location: location)
        }

        #expect(failure?.diagnostic == "broken\n\n" + AppLocalization.text("toolbarButtons.error.status", Int32(3)))

        // 解释器不存在时启动失败，原文先写 #! 这一行
        let missing = await #expect(throws: CustomToolbarScriptError.self) {
            try await CustomToolbarScript.run("#!/nonexistent/interpreter\n", variables: variables, location: location)
        }

        #expect(try #require(missing).diagnostic.hasPrefix("#!/nonexistent/interpreter\n"))
    }

    /// 变量让脚本不必写死仓库的位置、主机与远端：上游所在的远端名里可能有 “/”，要取对得上的最长的名字；
    /// 没有远端上游时按 Git 的默认取 origin，没有值的变量不设，脚本才能用 `${VAR-}` 判断。
    @Test("描述仓库的变量：上游对上最长的远端名，没有远端上游时取 origin，没有值的不设")
    func variables() {
        let remotes = ["origin", "fork", "fork/team"].map { name in
            var remote = RemoteConfiguration(name: name)
            remote.urls = ["git@example.com:" + name + ".git"]
            return remote
        }

        // 服务器仓库，上游在名字带 “/” 的远端上
        let server = CustomToolbarScript.variables(
            location: .remote(host: "spooky-test", path: "/srv/git/app"),
            branch: BranchStatus(head: "feature", oid: "abc123", upstream: "fork/team/feature"),
            remotes: remotes
        )

        #expect(
            server == [
                .repositoryPath: "/srv/git/app",
                .repositoryName: "app",
                .sshHost: "spooky-test",
                .branch: "feature",
                .head: "abc123",
                .upstream: "fork/team/feature",
                .remote: "fork/team",
                .remoteURL: "git@example.com:fork/team.git",
            ]
        )

        // 本机仓库，HEAD 分离、没有上游：不设主机、分支与上游，远端取 origin
        let detached = CustomToolbarScript.variables(
            location: .local(path: "/Users/spooky/app"),
            branch: BranchStatus(head: nil, oid: "abc123", upstream: nil),
            remotes: remotes
        )

        #expect(
            detached == [
                .repositoryPath: "/Users/spooky/app",
                .repositoryName: "app",
                .head: "abc123",
                .remote: "origin",
                .remoteURL: "git@example.com:origin.git",
            ]
        )

        // 还没读到状态、也没有远端
        let bare = CustomToolbarScript.variables(location: .local(path: "/Users/spooky/app"), branch: nil, remotes: [])

        #expect(bare == [.repositoryPath: "/Users/spooky/app", .repositoryName: "app"])
    }

    /// 脚本要用到登录 shell 里的 PATH 与自定义变量；继承来的同名旧变量可能描述的是别的仓库，这次没有值的也要去掉。
    @Test("脚本的环境：本机执行 Git 的变量盖过继承的值，描述仓库的变量换掉继承的同名旧值")
    func environment() {
        let environment = CustomToolbarScript.environment(
            inherited: ["PATH": "/usr/bin:/bin", "HOME": "/Users/spooky", "SPOOKY_SSH_HOST": "stale"],
            local: ["PATH": "/opt/homebrew/bin:/usr/bin:/bin", "SPOOKY_BRANCH": "custom"],
            variables: [.repositoryPath: "/repo", .branch: "main"]
        )

        #expect(environment["PATH"] == "/opt/homebrew/bin:/usr/bin:/bin")
        #expect(environment["HOME"] == "/Users/spooky")
        #expect(environment["SPOOKY_REPOSITORY_PATH"] == "/repo")
        #expect(environment["SPOOKY_BRANCH"] == "main")
        #expect(environment["SPOOKY_SSH_HOST"] == nil)
    }

    /// 编辑按钮要原位替换，面板与表格的顺序才不变；偏好里的内容损坏时不能让设置页与工具栏出错。
    @Test("按钮存在偏好里：新的追加，编辑原位替换，删除；内容损坏时视为没有按钮")
    func store() {
        let defaults = MemoryDefaults()
        let store = CustomToolbarButtonStore(defaults: defaults)

        var deploy = CustomToolbarButton(name: "Deploy", script: "make deploy")
        let open = CustomToolbarButton(symbol: "folder", name: "Open", script: "open .")

        store.save(deploy)
        store.save(open)

        deploy.name = "Ship"
        store.save(deploy)

        #expect(CustomToolbarButtonStore(defaults: defaults).buttons == [deploy, open])

        store.remove(open.id)

        #expect(CustomToolbarButtonStore(defaults: defaults).buttons == [deploy])

        defaults.set(Data("broken".utf8), forKey: CustomToolbarButtonStore.key)

        #expect(CustomToolbarButtonStore(defaults: defaults).buttons.isEmpty)
    }

    /// 名称不限长度，工具栏却不截断标签：放不下时截成放得下的前缀加省略号，不在省略号前留空格；
    /// 符号面板不单列各语言文字的变体，输入完整的符号名时即使不在列表里也能选；对话框只在三项都有效时能保存。
    @Test("工具栏上的标签截短，符号面板的筛选，对话框的保存条件")
    func labelsSymbolsAndRules() {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let width = { (text: String) in
            NSAttributedString(string: text, attributes: [.font: font]).size().width
        }

        // 放得下的名称原样作标签
        #expect(RepositoryToolbar.customButtonLabel("Deploy") == "Deploy")

        // 放不下时截短：英文截在空白处不留空格，中文同样按宽度截
        for name in [String(repeating: "Deploy to production ", count: 5), String(repeating: "部署到生产环境", count: 5)] {
            let label = RepositoryToolbar.customButtonLabel(name)

            #expect(label.hasSuffix("…"))
            #expect(!label.dropLast().hasSuffix(" "))
            #expect(name.hasPrefix(label.dropLast()))
            #expect(width(label) <= RepositoryToolbar.customButtonLabelWidth)
        }

        // 各语言文字的变体在基本名也在时不列出，名字以同样的字母结尾的普通符号照常列出
        let names = ["character", "character.ar", "bolt", "bolt.car", "a.circle.fill", "a.circle.fill.hi", "sun.max"]

        #expect(SymbolCatalog.withoutScriptVariants(names) == ["character", "bolt", "bolt.car", "a.circle.fill", "sun.max"])
        #expect(SymbolCatalog.names.contains(CustomToolbarButton.defaultSymbol))

        // 搜索词的每一段都要出现在名字里；完整的符号名不在列表里时排在最前面
        #expect(SymbolCatalog.search("circle fill", in: names) == ["a.circle.fill", "a.circle.fill.hi"])
        #expect(SymbolCatalog.search("hammer", in: names) == ["hammer"])
        #expect(SymbolCatalog.search(" ", in: names) == names)

        // 名称与脚本都不能只有空白，图标要是有的符号；保存时名称去掉首尾的空白，脚本原样保留
        let button = CustomToolbarButton(name: "  Deploy  ", script: "#!/bin/sh\nmake\n")

        #expect(CustomToolbarButtonDialog.canSave(button))
        #expect(CustomToolbarButtonDialog.trimmed(button).name == "Deploy")
        #expect(CustomToolbarButtonDialog.trimmed(button).script == button.script)

        for invalid in [
            CustomToolbarButton(name: " ", script: "make"),
            CustomToolbarButton(name: "Deploy", script: " \n "),
            CustomToolbarButton(symbol: "no.such.symbol", name: "Deploy", script: "make"),
        ] {
            #expect(!CustomToolbarButtonDialog.canSave(invalid))
        }
    }
}
