// 生成获取、拉取、推送、推送任意版本与强推五个工具栏图标：在无窗口的 WebKit 中运行同目录 make-transfer-icons.js 的 Canvas 绘制，
// 每个图标导出 @1x 与 @2x 两张模板图，如 FetchTemplate.png、FetchTemplate@2x.png。
//
// 用法：swift scripts/make-transfer-icons.swift <输出目录>

import WebKit

/// 图标的边长，单位是 pt。
let points = 18

/// 导出的图标：文件名与传给 renderTransferIcon 的种类。
let icons: [(name: String, kind: String)] = [
    ("FetchTemplate", "fetch"),
    ("PullTemplate", "pull"),
    ("PushTemplate", "push"),
    ("PushToTemplate", "pushTo"),
    ("ForcePushTemplate", "forcePush"),
]

/// 每个图标导出的倍率与文件名后缀。
let variants: [(suffix: String, scale: Int)] = [
    ("", 1),
    ("@2x", 2),
]

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-transfer-icons.swift <output directory>\n".utf8))
    exit(64)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

/// 与本文件同目录的 make-transfer-icons.js 绘制脚本。
let drawing = try String(
    contentsOf: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "make-transfer-icons.js"),
    encoding: .utf8
)

/// 执行绘制脚本的无窗口 WebKit 视图；Canvas 需要页面中的 document，因此先加载一个空白页面。
let webView = WKWebView(frame: .zero)
webView.loadHTMLString("<!doctype html>", baseURL: nil)

while webView.isLoading {
    try await Task.sleep(for: .milliseconds(10))
}

for icon in icons {
    for variant in variants {
        // 以绘制脚本加一句 renderTransferIcon 调用作为函数体执行，取回 PNG 的 data URL。
        let result = try await webView.callAsyncJavaScript(
            drawing + "\nreturn renderTransferIcon(pixels, kind);",
            arguments: ["pixels": points * variant.scale, "kind": icon.kind],
            contentWorld: .page
        )

        guard
            let dataURL = result as? String,
            let comma = dataURL.firstIndex(of: ","),
            let png = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]))
        else {
            FileHandle.standardError.write(Data("renderTransferIcon did not return a PNG data URL\n".utf8))
            exit(1)
        }

        try png.write(to: outputDirectory.appending(path: icon.name + variant.suffix + ".png"))
    }
}
