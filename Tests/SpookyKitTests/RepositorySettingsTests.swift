import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositorySettingsTests

/// 仓库设置：只读写仓库本地配置，删除没有设置的键不算失败；规则文件去掉注释与空行，LFS 只取 `filter=lfs` 的路径模式，带引号的模式可以含空格。
struct RepositorySettingsTests {
    /// 本地配置写入后读回原值，删除后回到没有设置。
    @Test("本地配置的读写")
    func localConfiguration() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()
        let runner = temporary.runner

        try await runner.setLocalConfig(RepositorySettings.Key.bodyLineLimit, to: "80")
        try await runner.setLocalConfig(RepositorySettings.Key.showsBodyGuide, to: "false")
        try await runner.setLocalConfig(RepositorySettings.Key.signingKey, to: "~/.ssh/id 签名.pub")
        try await runner.setLocalConfig(RepositorySettings.Key.issueTrackerTemplate, to: "https://example.invalid/{ISSUE_NUMBER}")

        var settings = try await runner.repositorySettings()
        #expect(settings.bodyLineLimit == 80)
        #expect(settings.showsBodyGuide == Optional(false))
        #expect(settings.signingKey == "~/.ssh/id 签名.pub")
        #expect(settings.issueTrackerTemplate == "https://example.invalid/{ISSUE_NUMBER}")
        #expect(settings.allowedSignersFile == nil)

        // 删除写过的键与没有写过的键都不报错
        try await runner.setLocalConfig(RepositorySettings.Key.bodyLineLimit, to: nil)
        try await runner.setLocalConfig(RepositorySettings.Key.allowedSignersFile, to: nil)

        settings = try await runner.repositorySettings()
        #expect(settings.bodyLineLimit == nil)
        #expect(settings.showsBodyGuide == Optional(false))
    }

    /// 三份规则文件在仓库所在机器上的位置；不存在时规则为空，存在时去掉注释与空行。
    @Test("规则文件")
    func ruleFiles() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()
        let runner = temporary.runner
        let root = temporary.directory

        var settings = try await runner.repositorySettings()
        #expect(!settings.ignore.exists && settings.ignore.patterns.isEmpty)
        #expect(settings.ignore.path.hasSuffix("/.gitignore"))
        #expect(settings.exclude.path.hasSuffix("/info/exclude"))

        try Data("# 注释\n\n*.log\n  build/  \n".utf8).write(to: root.appending(path: ".gitignore"))
        try Data("*.psd filter=lfs diff=lfs merge=lfs -text\n*.txt text\n\"设计 稿/*.sketch\" filter=lfs\n".utf8)
            .write(to: root.appending(path: ".gitattributes"))

        settings = try await runner.repositorySettings()
        #expect(settings.ignore.exists)
        #expect(settings.ignore.patterns == ["*.log", "build/"])
        #expect(settings.lfs.patterns == ["*.psd", "设计 稿/*.sketch"])
    }

    /// 配置输出里出现不认识的键时说明输出已错位，按格式错误处理。
    @Test("配置输出的格式错误")
    func malformedConfiguration() {
        #expect(throws: RepositoryReadError.self) {
            try RepositorySettings.configuration(Data("core.editor\nvim\0".utf8))
        }

        #expect(throws: RepositoryReadError.self) {
            try RepositorySettings.configuration(Data("spooky.commitbodylimit\n80".utf8))
        }
    }
}
