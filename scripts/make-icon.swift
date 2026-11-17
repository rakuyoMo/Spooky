// 生成 Spooky 的七组应用图标：在无窗口的 WebKit 中运行 make-icon/ 目录下的 Canvas 绘制，
// 为每组的默认图标与深色图标的指示灯灭着、亮着两版各导出全部尺寸，再由 iconutil 合成二十八份 .icns。
//
// 用法：swift scripts/make-icon.swift <输出目录>

import WebKit

/// 七组图标：.icns 文件名的前缀，传给 renderIcon 的图标组，以及 make-icon/ 目录下这一组的绘制脚本；满怀的三组共用一个脚本。
let groups: [(prefix: String, group: String, script: String)] = [
    ("AppIconArmful", "armful", "armful.js"),
    ("AppIconArmfulPlain", "armfulPlain", "armful.js"),
    ("AppIconArmfulPurple", "armfulPurple", "armful.js"),
    ("AppIconPerch", "perch", "perch.js"),
    ("AppIconCherryPick", "cherryPick", "cherry-pick.js"),
    ("AppIconServerGhost", "serverGhost", "server-ghost.js"),
    ("AppIconMidnight", "midnight", "midnight.js"),
]

/// 每组的四版：接在前缀后面的文件名后缀，以及传给 renderIcon 的样式与指示灯是否亮着。
let versions: [(suffix: String, style: String, lit: Bool)] = [
    ("", "default", false),
    ("Connected", "default", true),
    ("Dark", "dark", false),
    ("DarkConnected", "dark", true),
]

/// 要生成的二十八份图标：.icns 的文件名，以及传给 renderIcon 的图标组、样式与指示灯是否亮着。
let icons = groups.flatMap { group in
    versions.map { (name: group.prefix + $0.suffix, group: group.group, style: $0.style, lit: $0.lit) }
}

/// iconset 需要的文件名与像素尺寸。
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-icon.swift <output directory>\n".utf8))
    exit(64)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

/// 与本文件同目录的 make-icon/ 目录，放着各组的绘制脚本与它们共用的 kit.js。
let scriptDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appending(path: "make-icon", directoryHint: .isDirectory)

/// 绘制脚本的文件名：kit.js 在前，各组的脚本依次接在后面，几组共用的只接一次。
let scripts = groups.reduce(into: ["kit.js"]) { scripts, group in
    if !scripts.contains(group.script) {
        scripts.append(group.script)
    }
}

/// 绘制脚本：合成一份执行。
let drawing = try scripts
    .map { try String(contentsOf: scriptDirectory.appending(path: $0), encoding: .utf8) }
    .joined(separator: "\n")

/// 执行绘制脚本的无窗口 WebKit 视图；Canvas 需要页面中的 document，因此先加载一个空白页面。
let webView = WKWebView(frame: .zero)
webView.loadHTMLString("<!doctype html>", baseURL: nil)

while webView.isLoading {
    try await Task.sleep(for: .milliseconds(10))
}

for icon in icons {
    let output = outputDirectory.appending(path: icon.name + ".icns")
    let iconset = FileManager.default.temporaryDirectory
        .appending(path: "Spooky-" + UUID().uuidString + ".iconset")
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: false)

    // 每个尺寸都以绘制脚本加一句 renderIcon 调用作为函数体执行，取回 PNG 的 data URL。
    for variant in variants {
        let result = try await webView.callAsyncJavaScript(
            drawing + "\nreturn renderIcon(pixels, group, style, lit);",
            arguments: [
                "pixels": variant.pixels,
                "group": icon.group,
                "style": icon.style,
                "lit": icon.lit,
            ],
            contentWorld: .page
        )

        guard
            let dataURL = result as? String,
            let comma = dataURL.firstIndex(of: ","),
            let png = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]))
        else {
            FileHandle.standardError.write(Data("renderIcon did not return a PNG data URL\n".utf8))
            try? FileManager.default.removeItem(at: iconset)
            exit(1)
        }

        try png.write(to: iconset.appending(path: variant.name + ".png"))
    }

    // iconutil 按文件名识别各尺寸，合成单个 .icns；临时 iconset 合成后即删除。
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
    try process.run()
    process.waitUntilExit()
    try? FileManager.default.removeItem(at: iconset)

    // 一份合成失败就停下，不再生成后面的图标。
    guard process.terminationStatus == 0 else {
        exit(process.terminationStatus)
    }
}
