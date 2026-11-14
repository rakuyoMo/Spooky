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

    /// One-Up 显示新的一侧；切到 One-Up 时先显示旧的一侧。
    @State
    private var showsNew = false

    /// 图片区的大小，用来算放不下时的缩小比例。
    @State
    private var areaSize = CGSize.zero

    /// 动作条、图片区与读取状态。
    var body: some View {
        VStack(spacing: 0) {
            if placement == .top {
                actionBar.frame(height: 30)
                Divider()
            }

            // 工作区里图片区占满动作条以上的空间，变更集里按图片高度排列；图片连同标签与说明在区内竖直居中
            content
                .frame(
                    maxWidth: .infinity,
                    maxHeight: placement == .bottom ? .infinity : nil,
                    alignment: images == nil || failed ? .top : .center
                )
                .background(Color(nsColor: .controlBackgroundColor))
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: {
                    areaSize = $0
                }

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
            let sides = visibleSides(images)
            let scale = scale(of: sides)

            HStack(alignment: .top, spacing: 8) {
                ForEach(sides, id: \.label) {
                    ImageDiffPane(side: $0, scale: scale)
                }
            }
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

    /// 两侧都在时才出现比较方式与 One-Up 的版本切换；两组分段控件用常规尺寸，相隔 7 pt。
    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 7) {
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
        .padding(.horizontal, 20)
    }

    /// 仓库里的图片文件：Git 判定为二进制，扩展名属于图片类型。
    static func isImage(_ file: DiffFile, path: String) -> Bool {
        let pathExtension = path.lastIndex(of: ".").map { String(path[path.index(after: $0)...]) } ?? ""
        return file.isBinary && (UTType(filenameExtension: pathExtension)?.conforms(to: .image) ?? false)
    }

    /// 当前要显示的版本：Two-Up 两侧都显示，One-Up 只显示选中的一侧，单侧图片只有那一侧。
    private func visibleSides(_ images: ImagePair) -> [ImageSide] {
        let old = images.old.map { ImageSide(label: "diff.oldLabel", image: $0) }
        let new = images.new.map { ImageSide(label: "diff.newLabel", image: $0) }

        guard let old, let new else {
            return [old, new].compactMap(\.self)
        }

        return mode == .twoUp ? [old, new] : [showsNew ? new : old]
    }

    /// 像素数当点数显示，放不下时各图按同一比例缩小。
    ///
    /// 横向两边各留 40 pt、图间隔 8 pt；竖向扣除标签与说明占的高度，变更集里图片最高 480 pt。
    private func scale(of sides: [ImageSide]) -> CGFloat {
        let width = sides.reduce(0) { $0 + $1.image.pixels.width }
        let height = sides.map(\.image.pixels.height).max() ?? 0

        guard width > 0, height > 0, areaSize.width > 0 else {
            return 1
        }

        let availableWidth = areaSize.width - 80 - 8 * CGFloat(sides.count - 1)
        let availableHeight = placement == .bottom ? areaSize.height - ImageDiffPane.chromeHeight : 480

        return max(0, min(1, availableWidth / width, availableHeight / height))
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
    /// 标签与说明连同上下边距占的高度：标签 20 + 16 + 20，说明 30 + 18 + 16。
    static let chromeHeight: CGFloat = 56 + 64

    /// 要显示的版本。
    let side: ImageSide

    /// 像素数换成点数后的缩小比例。
    let scale: CGFloat

    /// 竖向依次是上边距、标签、间隔、图片、说明与下边距。
    var body: some View {
        VStack(spacing: 0) {
            Text(AppLocalization.text(side.label))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(height: 16)
                .padding(.top, 20)
                .padding(.bottom, 20)

            Image(nsImage: side.image.image)
                .resizable()
                .interpolation(.high)
                .frame(
                    width: side.image.pixels.width * scale,
                    height: side.image.pixels.height * scale
                )
                .background(CheckerboardView())
                .border(AppPalette.color("general_border_color"), width: 1)

            // 说明在图片下方 30 pt，按自然宽度排，不随图片宽度截断
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize()
                .frame(height: 18)
                .padding(.top, 30)
                .padding(.bottom, 16)
        }
        .accessibilityElement(children: .combine)
    }

    /// 像素尺寸与文件大小。
    private var description: String {
        AppLocalization.text(
            "diff.imageSize",
            Int(side.image.pixels.width),
            Int(side.image.pixels.height),
            ByteCountFormatter.string(fromByteCount: Int64(side.image.data.count), countStyle: .file)
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

            let rows = Int((size.height / square).rounded(.up))
            let columns = Int((size.width / square).rounded(.up))

            for row in 0 ..< rows {
                for column in 0 ..< columns where (row + column).isMultiple(of: 2) {
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

/// 解码后的一侧图片、它的像素尺寸与原始字节。
private struct DecodedImage {
    /// 图片。
    let image: NSImage

    /// 像素尺寸；矢量图等没有像素数的取点数。
    let pixels: CGSize

    /// 原始字节，用于显示文件大小。
    let data: Data

    /// 不能解码的数据视为读取失败。
    init(_ data: Data) throws {
        guard let image = NSImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.image = image
        self.data = data

        // 位图取第一份表示的像素数
        if
            let representation = image.representations.first,
            representation.pixelsWide > 0,
            representation.pixelsHigh > 0
        {
            pixels = CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        } else {
            pixels = image.size
        }
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

    /// 解码后的图片。
    let image: DecodedImage
}
