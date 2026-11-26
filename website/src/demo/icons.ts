import fetchTemplate from '../../../Sources/Spooky/Resources/FetchTemplate@2x.png?inline';
import forcePushTemplate from '../../../Sources/Spooky/Resources/ForcePushTemplate@2x.png?inline';
import pullTemplate from '../../../Sources/Spooky/Resources/PullTemplate@2x.png?inline';
import pushTemplate from '../../../Sources/Spooky/Resources/PushTemplate@2x.png?inline';

/**
 * 演示窗口的图标：同步按钮共用 App 的模板图，其余界面符号用 SVG 表示。
 * 模板图和线条符号都用 `currentColor`，颜色跟着所在的控件。
 */

/** 18 × 18 网格上的线条图标：1.5 的圆头笔画。 */
const line = (body: string, stroke = 1.5): string =>
    `<svg viewBox="0 0 18 18" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="${stroke}" ` +
    `stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;

/** App 自绘图形的圆环：半径 2.4。 */
const ring = (x: number, y: number): string => `<circle cx="${x}" cy="${y}" r="2.4"/>`;

/** App 自绘图形的实心箭头：尖端朝左。 */
const arrowhead = (x: number, y: number): string =>
    `<polygon points="${x},${y} ${x + 3.6},${y - 2.8} ${x + 3.6},${y + 2.8}" fill="currentColor"/>`;

/** App 自绘的分支图形：左侧的主干连着上下两个圆环，右上的圆环拐过圆角斜着并入主干。 */
const branchShape =
    `${ring(4.6, 3.9)}${ring(13.4, 3.9)}${ring(4.6, 14.1)}` +
    '<path d="M4.6 6.3v5.4M13.4 6.3V7Q13.4 8.1 12.1 8.6L4.6 11.2"/>';

/**
 * 新建分支：分支图形缩到左上，右下角是挖出加号的实心圆角标，角标四周让出一圈空隙。
 *
 * 掩膜里白的留下、黑的挖掉。
 */
const createBranch = (): string =>
    `<svg viewBox="0 0 18 18" aria-hidden="true">` +
    `<mask id="sd-mask-create-branch" maskUnits="userSpaceOnUse" x="0" y="0" width="18" height="18">` +
    `<g transform="scale(.8)" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" ` +
    `stroke-linejoin="round">${branchShape}</g>` +
    `<circle cx="13.32" cy="13.32" r="5.76"/><circle cx="13.32" cy="13.32" r="4.68" fill="#fff"/>` +
    `<path d="M11.37 13.32h3.9M13.32 11.37v3.9" stroke="#000" stroke-width="1.5" stroke-linecap="round"/>` +
    `</mask>` +
    `<rect width="18" height="18" fill="currentColor" mask="url(#sd-mask-create-branch)"/></svg>`;

/** 齿轮：八个齿的外轮廓与中间的圆。 */
const gear = (): string => {
    const points: string[] = [];

    for (let index = 0; index < 32; index += 1) {
        const angle = (index / 32) * Math.PI * 2;
        const tooth = index % 4 < 2 ? 7.2 : 5.6;

        points.push(`${(9 + Math.cos(angle) * tooth).toFixed(2)},${(9 + Math.sin(angle) * tooth).toFixed(2)}`);
    }

    return `<polygon points="${points.join(' ')}"/><circle cx="9" cy="9" r="2.4"/>`;
};

/** 文件图标的纸张：折角的白纸，`marks` 是纸上的记号。 */
const paper = (marks: string): string =>
    '<svg viewBox="0 0 16 18" aria-hidden="true">' +
    '<path d="M2.5 1.5h7.2l3.8 3.8v11.2h-11Z" class="sd-doc-paper"/>' +
    '<path d="M9.7 1.5v3.8h3.8" class="sd-doc-fold"/>' +
    `${marks}</svg>`;

/** 用模板图的透明度着色，让同步按钮随工具栏外观切换。 */
const template = (source: string): string =>
    `<span class="sd-template-icon" aria-hidden="true" style="mask-image:url('${source}')"></span>`;

// MARK: - Icon Table

/** 全部图标，按名字取。 */
export const icons = {
    folder: line(
        '<path d="M.9 5.1a2 2 0 0 1 2-2h3.8l1.9 1.6h6.5a2 2 0 0 1 2 2v6.4a2 2 0 0 1-2 2H2.9a2 2 0 0 1-2-2Z"/>' +
        '<path d="M1.2 6.7h15.3"/>',
        1.3,
    ),
    finder: line(
        '<rect x="1.4" y="1.4" width="15.2" height="15.2" rx="3.5"/>' +
        '<path d="M9.8 1.6Q8 5.3 7.6 9.6l2-.2q-.2 4 .9 7M5.3 5.3v1.9m7.3-1.9v1.9M4.6 11.3q2.8 3.5 8.7.1"/>',
        1.25,
    ),
    terminal: line(
        '<rect x=".85" y="2.65" width="16.3" height="12.7" rx="1.4"/>' +
        '<path d="m3.5 5.7 2.8 2.2-2.8 2.2m4.1.15h3.1"/>',
        1.35,
    ),
    clock: line('<circle cx="9" cy="9" r="7.8"/><path d="M9 4v5H4.8"/>', 1.35),
    tray: line(
        '<path d="m1 10.5 3.1-6.2a1.5 1.5 0 0 1 1.3-.8h7.2a1.5 1.5 0 0 1 1.3.8l3.1 6.2v3.3a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1Z"/>' +
        '<path d="M1.3 10.5h4.5l1.5 1.7h3.4l1.5-1.7h4.5M6 6.2h6M5 8.3h8"/>',
        1.3,
    ),
    pullRequest: line(
        `<path d="M4.2 6.6v5.1M13.8 11.7V6.6Q13.8 4.2 11.4 4.2"/>${ring(4.2, 4.2)}${ring(4.2, 14.1)}${ring(13.8, 14.1)}${arrowhead(9.1, 4.2)}`,
    ),
    review: line('<circle cx="9" cy="9" r="7.8"/><path d="M12.8 6.7H5.3l2.2-2.1M5.2 11.3h7.5l-2.2 2.1"/>', 1.3),
    gear: line(gear(), 1.4),
    branch: line(branchShape),
    createBranch: createBranch(),
    tag: line('<path d="M9.6 2.6h5.2a.6.6 0 0 1 .6.6v5.2l-7.1 7.1a1 1 0 0 1-1.4 0l-4.4-4.4a1 1 0 0 1 0-1.4Z"/><circle cx="12.4" cy="5.6" r="1"/>'),
    globe: line(
        '<circle cx="9" cy="9" r="7.8"/><ellipse cx="9" cy="9" rx="3.4" ry="7.8"/>' +
        '<path d="M2.4 5.1q6.6 2.5 13.2 0m-13.2 7.8q6.6-2.5 13.2 0"/>',
        1.2,
    ),
    house: line('<path d="M2.8 8.6 9 3.4l6.2 5.2M4.5 7.4V15h3.2v-4h2.6v4h3.2V7.4"/>'),
    drive: line(
        '<path d="m1.1 10.2 2.5-5.7c.3-.7.8-1 1.6-1h7.6c.8 0 1.3.3 1.6 1l2.5 5.7"/>' +
        '<rect x=".8" y="9.3" width="16.4" height="5.6" rx="2.2"/><circle cx="14" cy="12.1" r=".7" fill="currentColor" stroke="none"/>',
        1.4,
    ),
    sidebar: line('<rect x="2.25" y="3.5" width="13.5" height="11" rx="2.4"/><path d="M6.7 3.5v11M4 6.4h1M4 8.4h1M4 10.4h1"/>', 1.2),
    more: line('<path d="M4.2 4.5 8.7 9l-4.5 4.5M9.3 4.5 13.8 9l-4.5 4.5"/>', 1.7),
    back: line('<path d="M11.2 3.5 5.7 9l5.5 5.5"/>', 1.7),
    forward: line('<path d="M6.8 3.5 12.3 9l-5.5 5.5"/>', 1.7),
    chevronRight: line('<path d="M7 4.5 11.5 9 7 13.5"/>'),
    chevronDown: line('<path d="M4.5 7 9 11.5 13.5 7"/>'),
    chevronUp: line('<path d="M4.5 11 9 6.5l4.5 4.5"/>'),
    upDown: line('<path d="M5.5 7 9 3.5 12.5 7M5.5 11 9 14.5l3.5-3.5"/>'),
    fetch: template(fetchTemplate),
    pull: template(pullTemplate),
    push: template(pushTemplate),
    forcePush: template(forcePushTemplate),
    trayDown: line(
        '<path d="M5.1 7.1H3.7L1 11v4.1a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V11l-2.7-3.9h-1.4"/>' +
        '<path d="M1 11h4.5l1.7 2.1h3.6l1.7-2.1H17M9 .9v9M6.3 7.2 9 9.9l2.7-2.7"/>',
    ),
    trayUp: line(
        '<path d="M5.1 7.1H3.7L1 11v4.1a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V11l-2.7-3.9h-1.4"/>' +
        '<path d="M1 11h4.5l1.7 2.1h3.6l1.7-2.1H17M9 9.9v-9M6.3 3.6 9 .9l2.7 2.7"/>',
    ),
    refresh: line('<path d="M15.1 10a6.2 6.2 0 1 1-6.2-6.2H12m-3.1-3 3.1 3-3.1 3"/>', 1.6),
    search: line('<circle cx="7.6" cy="7.6" r="4.9"/><path d="m11.3 11.3 4 4"/>', 1.7),
    sliders: line(
        '<path d="M2 4.5h8m3.4 0H16M2 9h2.3m3.4 0H16m-14 4.5h6.3m3.4 0H16"/>' +
        '<circle cx="11.7" cy="4.5" r="1.7"/><circle cx="6" cy="9" r="1.7"/><circle cx="10" cy="13.5" r="1.7"/>',
        1.1,
    ),
    pin: line('<path d="M7 2.5h4M8 2.5v4.2L5.6 9.4h6.8L10 6.7V2.5M9 9.4v6"/>', 1.2),
    returnKey: line('<path d="M14.5 4v4.6a1 1 0 0 1-1 1H4.5M7.4 6.6 4.4 9.6l3 3"/>', 1.2),
    grip: line('<path d="M15.5 8.5 8.5 15.5M15.5 12.5l-3 3"/>', 1),
    noEntry: line('<circle cx="9" cy="9" r="6"/><path d="m4.8 4.8 8.4 8.4"/>', 1.2),
    lineNumbers: line('<path d="M7 5h8.5M7 9h8.5M7 13h8.5M3 4l1-.6V6.2M2.6 8.4c.3-.5 1.7-.6 1.7.3 0 .7-1.7 1.4-1.7 2h1.8M2.6 11.9c.4-.3 1.6-.3 1.6.4s-.8.6-.8.6.9 0 .9.7-1.3.8-1.7.4"/>', 1),
    activity: line('<circle cx="9" cy="9" r="6.5"/><path d="M5.8 6.8h6.4M5.8 9h6.4m-6.4 2.2h4.1"/>', 1.1),
    plus: line('<path d="M9 3.5v11M3.5 9h11"/>', 1.3),
    check: line('<path d="M4.2 9.4 7.4 12.5l6.4-7"/>', 2.2),
    dash: line('<path d="M5 9h8"/>', 2.2),
    commit: line('<circle cx="9" cy="9" r="6.8"/><circle cx="9" cy="9" r="2.4" fill="currentColor"/>'),
    doc: paper(
        '<path d="M4.6 8h6.8M4.6 10h6.8M4.6 12h6.8M4.6 14h4.4" class="sd-doc-line"/>',
    ),
    typescript: paper('<text x="8" y="12.7" fill="#17718b" class="sd-doc-type">TS</text>'),
    markdown: paper('<path d="M6.3 7.8h3.4v2.6h1.7L8 13.5l-3.4-3.1h1.7Z" fill="#43899c"/>'),
    json: paper('<text x="8" y="12.7" fill="#718b26" class="sd-doc-type">{ }</text>'),
} as const;

/** 图标的名字。 */
export type IconName = keyof typeof icons;

/** 服务器文件按扩展名显示类型图标，其他文件用通用文稿。 */
export function fileIcon(path: string): string {
    switch (path.split('.').at(-1)) {
        case 'ts': return icons.typescript;
        case 'md': return icons.markdown;
        case 'json': return icons.json;
        default: return icons.doc;
    }
}
