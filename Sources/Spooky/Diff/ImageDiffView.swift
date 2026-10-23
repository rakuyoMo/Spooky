import AppKit
import SpookyKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ImageDiffView

/// 图片 Diff：Two-Up 并排显示新旧两张，One-Up 一次显示一张并在 Old / New 间切换；只有一侧时不出现切换。
struct ImageDiffView: View {
    /// 动作条的位置：工作区在图片下方，提交变更集在图片上方。
    enum Placement {
        /// 工作区：图片在上，底部动作条高 40 pt。
        case bottom

        /// 变更集：顶部动作条高 30 pt，图片在下。
        case top
    }

    /// 两种比较方式。
    enum Mode: String, CaseIterable {
        /// 新旧并排。
        case twoUp

        /// 一次一张。
        case oneUp
    }

    /// 动作条位置。
    let placement: Placement

    /// 同一文件同一版本的标识，变化时重新读取。
    let id: String

    /// 读取两侧的原始字节。
    let load: () async throws -> (old: Data?, new: Data?)

    /// 已解码的两侧图片；为空表示还在读取。
    @State
    private var images: ImagePair?

    /// 读取或解码失败。
    @State
    private var failed = false

    /// 当前比较方式。
    @State
    private var mode = Mode.twoUp

    /// One-Up 显示新的一侧。
    @State
    private var showsNew = true

    /// 动作条、图片区与读取状态。
    var body: some View {
        VStack(spacing: 0) {
            if placement == .top {
                actionBar.frame(height: 30)
                Divider()
            }

            // 工作区里图片区占满动作条以上的空间，变更集里按图片高度排列
            content
                .frame(
                    maxWidth: .infinity,
                    maxHeight: placement == .bottom ? .infinity : nil,
                    alignment: .top
                )

            if placement == .bottom {
                Divider()
                actionBar.frame(height: 40)
            }
        }
        .task(id: id) { await reload() }
    }

    /// 读取中、失败与两种比较方式。
    @ViewBuilder
    private var content: some View {
        if failed {
            Text(AppLocalization.text("diff.imageFailed"))
                .foregroundStyle(.secondary)
                .padding(20)
        } else if let images {
            GeometryReader { proxy in
                imageRow(images, width: proxy.size.width)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 20 + 16 + 20 + rowHeight(images) + 18 + 16)
        } else {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(AppLocalization.text("diff.loadingImage"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    /// 两侧都在时才出现比较方式与 One-Up 的版本切换。
    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 12) {
            if let images, images.old != nil, images.new != nil {
                Picker(AppLocalization.text("diff.imageMode"), selection: $mode) {
                    Text(AppLocalization.text("diff.twoUp")).tag(Mode.twoUp)
                    Text(AppLocalization.text("diff.oneUp")).tag(Mode.oneUp)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                if mode == .oneUp {
                    Picker(AppLocalization.text("diff.imageSide"), selection: $showsNew) {
                        Text(AppLocalization.text("diff.old")).tag(false)
                        Text(AppLocalization.text("diff.new")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }

            Spacer(minLength: 0)
        }
        .controlSize(.small)
        .padding(.horizontal, 20)
    }

    /// 仓库里的图片文件：Git 判定为二进制，扩展名属于图片类型。
    static func isImage(_ file: DiffFile, path: String) -> Bool {
        let pathExtension = path.lastIndex(of: ".").map { String(path[path.index(after: $0)...]) } ?? ""
        return file.isBinary && (UTType(filenameExtension: pathExtension)?.conforms(to: .image) ?? false)
    }

    /// 按比较方式排出一张或两张图片，并排时每张可用宽度为一半减去间距与边距。
    @ViewBuilder
    private func imageRow(_ images: ImagePair, width: Double) -> some View {
        let sides = visibleSides(images)
        let paneWidth = sides.count == 2 ? width / 2 - 4 - 80 : width - 80

        HStack(alignment: .top, spacing: 8) {
            ForEach(sides, id: \.label) { side in
                ImageDiffPane(
                    label: side.label,
                    image: side.image,
                    data: side.data,
                    maxWidth: max(40, paneWidth)
                )
            }
        }
    }

    /// 当前要显示的版本：Two-Up 两侧都显示，One-Up 只显示选中的一侧，单侧图片只有那一侧。
    private func visibleSides(_ images: ImagePair) -> [ImageSide] {
        let old = images.old.map { ImageSide(label: "diff.oldLabel", image: $0.image, data: $0.data) }
        let new = images.new.map { ImageSide(label: "diff.newLabel", image: $0.image, data: $0.data) }

        guard let old, let new else {
            return [old, new].compactMap(\.self)
        }

        return mode == .twoUp ? [old, new] : [showsNew ? new : old]
    }

    /// 图片区高度取两侧中较高的一张，最高 480 pt。
    private func rowHeight(_ images: ImagePair) -> Double {
        let heights = [images.old, images.new].compactMap { $0?.image.size.height }
        return min(480, heights.max() ?? 0)
    }

    /// 读取字节并解码；任何一侧解码失败都按读取失败处理。
    private func reload() async {
        images = nil
        failed = false

        do {
            let contents = try await load()
            let old = try contents.old.map(DecodedImage.init)
            let new = try contents.new.map(DecodedImage.init)

            guard !Task.isCancelled else {
                return
            }

            images = ImagePair(old: old, new: new)
            failed = old == nil && new == nil
        } catch {
            guard !Task.isCancelled else {
                return
            }

            failed = true
        }
    }
}

// MARK: - ImageDiffPane

/// 一侧图片：顶部标签、衬棋盘格并描边的图片与底部的尺寸说明。
private struct ImageDiffPane: View {
    /// 顶部标签的资源键。
    let label: String

    /// 图片。
    let image: NSImage

    /// 原始字节，用于显示文件大小。
    let data: Data

    /// 可用宽度。
    let maxWidth: Double

    /// 竖向依次是上边距、标签、间隔、图片、说明与下边距。
    var body: some View {
        VStack(spacing: 0) {
            Text(AppLocalization.text(label))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(height: 16)
                .padding(.top, 20)
                .padding(.bottom, 20)

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: min(maxWidth, image.size.width), maxHeight: min(480, image.size.height))
                .background(CheckerboardView())
                .border(AppPalette.color("general_border_color"), width: 1)

            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(height: 18)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: maxWidth)
        .accessibilityElement(children: .combine)
    }

    /// 像素尺寸与文件大小。
    private var description: String {
        let pixels = image.representations.first.map { ($0.pixelsWide, $0.pixelsHigh) }
            ?? (Int(image.size.width), Int(image.size.height))

        return AppLocalization.text(
            "diff.imageSize",
            pixels.0,
            pixels.1,
            ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        )
    }
}

// MARK: - CheckerboardView

/// 透明图片下方的棋盘格，每格 8 pt。
private struct CheckerboardView: View {
    /// 白底上交错绘制灰格。
    var body: some View {
        Canvas { context, size in
            let square = 8.0
            let background = AppPalette.color("repository_diff_image_checkerboard_background_color")
            let tile = AppPalette.color("repository_diff_image_checkerboard_square_color")

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))

            for row in 0 ..< Int((size.height / square).rounded(.up)) {
                for column in 0 ..< Int((size.width / square).rounded(.up)) where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: Double(column) * square,
                        y: Double(row) * square,
                        width: square,
                        height: square
                    )

                    context.fill(Path(rect), with: .color(tile))
                }
            }
        }
    }
}

// MARK: - DecodedImage

/// 解码后的一侧图片与它的原始字节。
private struct DecodedImage {
    /// 图片。
    let image: NSImage

    /// 原始字节。
    let data: Data

    /// 不能解码的数据视为读取失败。
    init(_ data: Data) throws {
        guard let image = NSImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.image = image
        self.data = data
    }
}

// MARK: - ImagePair

/// 旧、新两侧，新增或删除的图片只有一侧。
private struct ImagePair {
    /// 旧版。
    let old: DecodedImage?

    /// 新版。
    let new: DecodedImage?
}

// MARK: - ImageSide

/// 一个待显示的版本。
private struct ImageSide {
    /// 顶部标签的资源键，同时作为标识。
    let label: String

    /// 图片。
    let image: NSImage

    /// 原始字节。
    let data: Data
}
