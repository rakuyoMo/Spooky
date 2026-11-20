import { siteLocales } from './locales.ts';

/** 截图的两种外观，与 `screenshots/<语言>/<外观>/` 的目录名一致。 */
export const appearances = ['light', 'dark'] as const;

/** 截图的一种外观。 */
export type Appearance = (typeof appearances)[number];

/**
 * 截图的三种边框。
 *
 * - `window`：整窗，图自带透明圆角，网页加阴影
 * - `dialog`：按 sheet 边框裁的对话框，四角用圆角盖住
 * - `closeup`：矩形裁剪的特写
 */
export const screenshotFrames = ['window', 'dialog', 'closeup'] as const;

/** 截图的一种边框。 */
export type ScreenshotFrame = (typeof screenshotFrames)[number];

/** 一张截图文件的像素尺寸。 */
export interface ScreenshotSize {
    width: number;
    height: number;
}

/** 全部截图文件的尺寸，以 `<语言>/<外观>/<名字>` 为键。 */
export type ScreenshotManifest = Record<string, ScreenshotSize>;

/** 截图组件里给读屏软件的文字，按页面的语言取。 */
export interface ScreenshotTexts {
    /** 放大按钮的说明 */
    open: string;

    /** 关闭放大视图的按钮的说明 */
    close: string;
}

/** 一处截图引用。 */
export interface ScreenshotRequest {
    /** 画面的名字，即文件名去掉 `.webp` */
    name: string;

    /** 替代文本，写清画面里有什么 */
    alt: string;

    /** 边框 */
    frame: string;

    /** 图注；不写时不显示 */
    caption?: string | undefined;

    /**
     * 编号标注：空格分隔的 `x,y`，各是相对于图宽、图高的百分比（0–100），如 `14,40 52,6`。
     *
     * 依次显示为 1、2、3… 的圆点，叠在图上并随图缩放，放大视图里同样显示；不写时没有标注。
     */
    markers?: string | undefined;

    /** 只输出两张图本身，不带图注与放大，外面的版式由调用方决定 */
    bare?: boolean | undefined;

    /** 出错时写进错误信息的位置，如页面的文件路径 */
    where: string;
}

/** 截图上的一个编号标注的位置，相对于图宽、图高的百分比。 */
interface ScreenshotMarker {
    x: number;
    y: number;
}

/** 截图文件在站点上的地址前缀；文件原样发布在这里。 */
export const screenshotUrlBase = '/screenshots/';

/** 对话框截图四角的圆角半径，以截图的像素计；按百分比写进样式，图缩放时跟着缩放。 */
const dialogCornerRadius = 40;

/** 截图按 2× 拍摄，网页上按一半的尺寸显示。 */
const pixelRatio = 2;

/**
 * 生成截图的 HTML：浅色、暗色两张都写进页面，由样式按 `<html data-theme>` 只显示一张。
 *
 * 名字、替代文本、边框或标注不合规，或这个画面缺了哪种语言、哪种外观的图时抛出错误。
 */
export function screenshotHtml(
    manifest: ScreenshotManifest,
    localeCode: string,
    request: ScreenshotRequest,
    texts: ScreenshotTexts,
): string {
    const { name, alt, frame, caption, markers, bare, where } = request;

    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name)) {
        throw new Error(`${where}: 截图的名字 “${name}” 只能用小写英文、数字与连字符`);
    }

    if (alt.trim() === '') {
        throw new Error(`${where}: 截图 “${name}” 没有写替代文本`);
    }

    if (!isScreenshotFrame(frame)) {
        throw new Error(`${where}: 截图 “${name}” 的边框 “${frame}” 不是 ${screenshotFrames.join('、')} 之一`);
    }

    assertComplete(manifest, name, where);

    const points = parseMarkers(markers, name, where);

    const images = markedHtml(
        appearances
            .map((appearance) => imageHtml(manifest, { localeCode, appearance, name, alt, frame }))
            .join(''),
        points,
    );

    if (bare) {
        return images;
    }

    const captionHtml = caption ? `<figcaption>${escapeHtml(caption)}</figcaption>` : '';

    // 放大视图里的图同样懒加载：对话框关着时不显示，打开前不会下载
    return [
        `<figure class="spooky-screenshot" data-frame="${frame}">`,
        `<button type="button" class="spooky-screenshot-open" aria-haspopup="dialog">`,
        images,
        `<span class="sr-only">${escapeHtml(texts.open)}</span>`,
        `</button>`,
        captionHtml,
        `<dialog class="spooky-screenshot-dialog" aria-label="${escapeHtml(alt)}">`,
        `<form method="dialog"><button class="spooky-screenshot-close" aria-label="${escapeHtml(texts.close)}">×</button></form>`,
        images,
        `</dialog>`,
        `</figure>`,
    ].join('');
}

/** 截图的边框是否是认识的三种之一。 */
function isScreenshotFrame(frame: string): frame is ScreenshotFrame {
    return (screenshotFrames as readonly string[]).includes(frame);
}

/** 核对一个画面在全部语言与外观下都有图；缺了的全部列进错误信息。 */
function assertComplete(manifest: ScreenshotManifest, name: string, where: string) {
    const missing = siteLocales.flatMap(({ code }) =>
        appearances
            .map((appearance) => `${code}/${appearance}/${name}`)
            .filter((key) => !(key in manifest)),
    );

    if (missing.length > 0) {
        const files = missing.map((key) => `${key}.webp`).join('、');

        throw new Error(`${where}: 截图 “${name}” 缺少 ${files}`);
    }
}

/**
 * 解析编号标注：空格分隔的 `x,y`，两个数都在 0–100 之间。
 *
 * 不写时没有标注；写了却是空的，或有一项不是这个形式时抛出错误。
 */
function parseMarkers(markers: string | undefined, name: string, where: string): ScreenshotMarker[] {
    if (markers === undefined) {
        return [];
    }

    const tokens = markers.trim().split(/\s+/).filter((token) => token !== '');

    if (tokens.length === 0) {
        throw new Error(`${where}: 截图 “${name}” 的标注是空的`);
    }

    return tokens.map((token) => {
        const match = /^(\d+(?:\.\d+)?),(\d+(?:\.\d+)?)$/.exec(token);
        const x = Number(match?.[1]);
        const y = Number(match?.[2]);

        if (!match || x > 100 || y > 100) {
            throw new Error(`${where}: 截图 “${name}” 的标注 “${token}” 不是 “x,y” 形式、0–100 之间的百分比`);
        }

        return { x, y };
    });
}

/**
 * 给图加上编号标注：图与标注层包在一个和图一样大的容器里，标注按百分比定位。
 *
 * 标注只是视觉上的指引，对读屏软件隐藏；各区域的说明写在替代文本与图后的编号列表里。没有标注时原样返回。
 */
function markedHtml(images: string, markers: ScreenshotMarker[]): string {
    if (markers.length === 0) {
        return images;
    }

    // 编号画在 SVG 里，圆点缩放时数字跟着缩放
    const items = markers
        .map(({ x, y }, index) =>
            [
                `<span class="spooky-screenshot-marker" style="left: ${x}%; top: ${y}%">`,
                `<svg viewBox="0 0 24 24" focusable="false">`,
                `<circle cx="12" cy="12" r="10.5"/>`,
                `<text x="12" y="12">${index + 1}</text>`,
                `</svg>`,
                `</span>`,
            ].join(''),
        )
        .join('');

    return [
        `<span class="spooky-screenshot-marked">`,
        images,
        `<span class="spooky-screenshot-markers" aria-hidden="true">${items}</span>`,
        `</span>`,
    ].join('');
}

/** 一张截图的 `<img>`。 */
function imageHtml(
    manifest: ScreenshotManifest,
    image: {
        localeCode: string;
        appearance: Appearance;
        name: string;
        alt: string;
        frame: ScreenshotFrame;
    },
): string {
    const { localeCode, appearance, name, alt, frame } = image;
    const key = `${localeCode}/${appearance}/${name}`;
    const size = manifest[key];

    if (!size) {
        throw new Error(`没有截图 ${key}.webp`);
    }

    // 对话框的圆角按图的宽高折成百分比，图缩小时圆角跟着缩小，四角不会露出来
    const radiusX = percent(dialogCornerRadius, size.width);
    const radiusY = percent(dialogCornerRadius, size.height);
    const style = frame === 'dialog' ? ` style="border-radius: ${radiusX} / ${radiusY}"` : '';

    return [
        `<img class="spooky-screenshot-image"`,
        ` data-appearance="${appearance}" data-frame="${frame}"`,
        ` src="${screenshotUrlBase}${key}.webp"`,
        ` width="${Math.round(size.width / pixelRatio)}"`,
        ` height="${Math.round(size.height / pixelRatio)}"`,
        ` alt="${escapeHtml(alt)}" loading="lazy" decoding="async"${style}>`,
    ].join('');
}

/** 把像素值折成相对于边长的百分比，保留四位小数。 */
function percent(value: number, length: number): string {
    return `${Number(((value / length) * 100).toFixed(4))}%`;
}

/** 转义写进 HTML 文本与属性值的字符。 */
function escapeHtml(text: string): string {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
}
