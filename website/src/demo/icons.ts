/**
 * 演示窗口的图标，全部是自绘的 SVG：分支、新建分支、拉取请求与获取 / 拉取 / 推送 / 安全强推按 App 自己的图形画，
 * 其余是同样笔画的线条图标。图标只用 `currentColor`，颜色跟着所在的文字。
 */

/** 18 × 18 网格上的线条图标：1.5 的圆头笔画。 */
const line = (body: string, extra = ''): string =>
    `<svg viewBox="0 0 18 18" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.5" ` +
    `stroke-linecap="round" stroke-linejoin="round"${extra}>${body}</svg>`;

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

// MARK: - Transfer

/** 设计网格的边长与箭头的几何，单位都是网格。 */
const grid = 100;
const stroke = 7.5;
const fill = 0.96;
const radius = 30;
const body = 16;
const headWidth = 48;
const headLength = 24;
const tailAngle = (68 * Math.PI) / 180;
const headAngle = (135 * Math.PI) / 180;

/** 安全强推的角标：圆心、半径，与挖开箭头时角标外多留的一圈空隙。 */
const badge = { x: 77, y: 77, radius: 20, gap: 5 };

/** 角标里的感叹号：竖条的宽与高，竖条与下方方点的间距；方点的边长与竖条同宽。 */
const mark = { width: 6, height: 14, gap: 5.5 };

/**
 * 弧形块状箭头：尖角为直角的箭头朝左下，等宽的箭身沿圆弧拱向右上，尾端平切。
 *
 * 获取只描轮廓，拉取是实心的，推送把拉取转 180°；安全强推在推送的右下角加一枚挖出感叹号的实心圆角标。
 */
const transferArrow = (kind: 'fetch' | 'pull' | 'push' | 'forcePush'): string => {
    const center = grid / 2;
    const inner = radius - body / 2;
    const outer = radius + body / 2;
    const radial = [Math.cos(headAngle), -Math.sin(headAngle)] as const;
    const forward = [-Math.sin(headAngle), -Math.cos(headAngle)] as const;
    const base = [center + radial[0] * radius, center + radial[1] * radius] as const;
    const outerCorner = [base[0] + (radial[0] * headWidth) / 2, base[1] + (radial[1] * headWidth) / 2];
    const innerCorner = [base[0] - (radial[0] * headWidth) / 2, base[1] - (radial[1] * headWidth) / 2];
    const tip = [base[0] + forward[0] * headLength, base[1] + forward[1] * headLength];
    const on = (angle: number, distance: number) => [
        center + Math.cos(angle) * distance,
        center - Math.sin(angle) * distance,
    ];

    // 外接框：箭头的三个角加上两条圆弧的采样点
    const samples = [outerCorner, innerCorner, tip];

    for (let step = 0; step <= 64; step += 1) {
        const angle = tailAngle + ((headAngle - tailAngle) * step) / 64;

        samples.push(on(angle, outer), on(angle, inner));
    }

    const xs = samples.map((point) => point[0] ?? 0);
    const ys = samples.map((point) => point[1] ?? 0);
    const width = Math.max(...xs) - Math.min(...xs);
    const height = Math.max(...ys) - Math.min(...ys);
    const fit = (grid * fill - stroke) / Math.max(width, height);
    const middle = [(Math.max(...xs) + Math.min(...xs)) / 2, (Math.max(...ys) + Math.min(...ys)) / 2];
    const f = (point: number[]) => `${(point[0] ?? 0).toFixed(2)} ${(point[1] ?? 0).toFixed(2)}`;

    const d =
        `M${f(on(tailAngle, outer))}A${outer} ${outer} 0 0 0 ${f(on(headAngle, outer))}` +
        `L${f(outerCorner)}L${f(tip)}L${f(innerCorner)}` +
        `A${inner} ${inner} 0 0 1 ${f(on(tailAngle, inner))}Z`;

    const rotate = kind === 'fetch' || kind === 'pull' ? '' : ' rotate(180)';
    const transform =
        `translate(${center} ${center})${rotate} scale(${fit.toFixed(4)}) ` +
        `translate(${(-(middle[0] ?? 0)).toFixed(2)} ${(-(middle[1] ?? 0)).toFixed(2)})`;
    const arrow = (paint: string): string =>
        `<path d="${d}" transform="${transform}" ${paint} ` +
        `stroke-width="${(stroke / fit).toFixed(3)}" stroke-linejoin="round"/>`;

    if (kind !== 'forcePush') {
        const paint = kind === 'fetch' ? 'fill="none"' : 'fill="currentColor"';

        return `<svg viewBox="0 0 100 100" aria-hidden="true">${arrow(`${paint} stroke="currentColor"`)}</svg>`;
    }

    // 掩膜里白的留下、黑的挖掉：先挖掉角标连同一圈空隙下面的箭头，放上角标，再从角标里挖出感叹号
    const left = badge.x - mark.width / 2;
    const top = badge.y - (mark.height + mark.gap + mark.width) / 2;
    const dot = top + mark.height + mark.gap;

    return (
        `<svg viewBox="0 0 100 100" aria-hidden="true">` +
        `<mask id="sd-mask-force-push" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">` +
        arrow('fill="#fff" stroke="#fff"') +
        `<circle cx="${badge.x}" cy="${badge.y}" r="${badge.radius + badge.gap}"/>` +
        `<circle cx="${badge.x}" cy="${badge.y}" r="${badge.radius}" fill="#fff"/>` +
        `<path d="M${left} ${top}h${mark.width}v${mark.height}h${-mark.width}Z` +
        `M${left} ${dot}h${mark.width}v${mark.width}h${-mark.width}Z"/>` +
        `</mask>` +
        `<rect width="100" height="100" fill="currentColor" mask="url(#sd-mask-force-push)"/></svg>`
    );
};

// MARK: - Icon Table

/** 全部图标，按名字取。 */
export const icons = {
    folder: line('<path d="M2.5 5v8.5A1.5 1.5 0 0 0 4 15h10a1.5 1.5 0 0 0 1.5-1.5v-7A1.5 1.5 0 0 0 14 5H8.6L7.1 3H4A1.5 1.5 0 0 0 2.5 4.5Z"/><path d="M2.5 7.2h13"/>'),
    finder: line('<rect x="2.25" y="2.25" width="13.5" height="13.5" rx="3.2"/><path d="M9.1 2.4Q7.9 6 7.6 9.4h1.6Q9 12.6 9.4 15.6M5.9 5.9v1.5M12.3 5.9v1.5M5.2 11.5q3.8 2.6 7.6 0"/>'),
    terminal: line('<rect x="2.25" y="3.25" width="13.5" height="11.5" rx="2.2"/><path d="m5.6 7 2.3 2-2.3 2M9.8 11.4h2.8"/>'),
    clock: line('<circle cx="9" cy="9" r="6.8"/><path d="M9 5v4.2l2.6 1.6"/>'),
    tray: line('<path d="M2.5 10.5 4.6 4h8.8l2.1 6.5V14a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1Z"/><path d="M2.5 10.5h3.8l.9 1.7h3.6l.9-1.7h3.8M6 6.6h6M5.4 8.6h7.2"/>'),
    pullRequest: line(
        `<path d="M4.2 6.6v5.1M13.8 11.7V6.6Q13.8 4.2 11.4 4.2"/>${ring(4.2, 4.2)}${ring(4.2, 14.1)}${ring(13.8, 14.1)}${arrowhead(9.1, 4.2)}`,
    ),
    review: line('<circle cx="9" cy="9" r="6.8"/><path d="M5.6 7.3h6.6l-1.9-1.9M12.4 10.7H5.8l1.9 1.9"/>'),
    gear: line(gear(), ' stroke-width="1.4"'),
    branch: line(branchShape),
    createBranch: createBranch(),
    tag: line('<path d="M9.6 2.6h5.2a.6.6 0 0 1 .6.6v5.2l-7.1 7.1a1 1 0 0 1-1.4 0l-4.4-4.4a1 1 0 0 1 0-1.4Z"/><circle cx="12.4" cy="5.6" r="1"/>'),
    globe: line('<circle cx="9" cy="9" r="6.8"/><ellipse cx="9" cy="9" rx="3" ry="6.8"/><path d="M2.4 9h13.2"/>'),
    house: line('<path d="M2.8 8.6 9 3.4l6.2 5.2M4.5 7.4V15h3.2v-4h2.6v4h3.2V7.4"/>'),
    drive: line('<path d="M2.6 9.4 4.5 4.6h9l1.9 4.8v3.4a1.2 1.2 0 0 1-1.2 1.2H3.8a1.2 1.2 0 0 1-1.2-1.2Z"/><path d="M2.6 9.4h12.8"/><circle cx="12.6" cy="11.6" r=".5" fill="currentColor"/>'),
    back: line('<path d="M11.2 3.5 5.7 9l5.5 5.5"/>', ' stroke-width="1.7"'),
    forward: line('<path d="M6.8 3.5 12.3 9l-5.5 5.5"/>', ' stroke-width="1.7"'),
    chevronRight: line('<path d="M7 4.5 11.5 9 7 13.5"/>'),
    chevronDown: line('<path d="M4.5 7 9 11.5 13.5 7"/>'),
    chevronUp: line('<path d="M4.5 11 9 6.5l4.5 4.5"/>'),
    upDown: line('<path d="M5.5 7 9 3.5 12.5 7M5.5 11 9 14.5l3.5-3.5"/>'),
    fetch: transferArrow('fetch'),
    pull: transferArrow('pull'),
    push: transferArrow('push'),
    forcePush: transferArrow('forcePush'),
    trayDown: line('<path d="M2.5 10.5V14a1 1 0 0 0 1 1h11a1 1 0 0 0 1-1v-3.5h-3.8l-.9 1.7H7.2l-.9-1.7Z"/><path d="M9 2.5v6.2M6.6 6.4 9 8.8l2.4-2.4"/>'),
    trayUp: line('<path d="M2.5 10.5V14a1 1 0 0 0 1 1h11a1 1 0 0 0 1-1v-3.5h-3.8l-.9 1.7H7.2l-.9-1.7Z"/><path d="M9 8.8V2.6M6.6 5 9 2.6 11.4 5"/>'),
    refresh: line('<path d="M14.6 9.6a5.7 5.7 0 1 1-1.8-4.4"/><path d="M13.4 1.9l-.4 3.4-3.4-.3"/>'),
    search: line('<circle cx="7.6" cy="7.6" r="4.9"/><path d="m11.3 11.3 4 4"/>', ' stroke-width="1.7"'),
    sliders: line('<path d="M2.5 4.5h13M2.5 9h13M2.5 13.5h13"/><circle cx="11.5" cy="4.5" r="1.7" fill="var(--sd-bar, #fff)"/><circle cx="6" cy="9" r="1.7" fill="var(--sd-bar, #fff)"/><circle cx="10" cy="13.5" r="1.7" fill="var(--sd-bar, #fff)"/>', ' stroke-width="1.2"'),
    pin: line('<path d="M7 2.5h4M8 2.5v4.2L5.6 9.4h6.8L10 6.7V2.5M9 9.4v6"/>', ' stroke-width="1.2"'),
    returnKey: line('<path d="M14.5 4v4.6a1 1 0 0 1-1 1H4.5M7.4 6.6 4.4 9.6l3 3"/>', ' stroke-width="1.2"'),
    grip: line('<path d="M15.5 8.5 8.5 15.5M15.5 12.5l-3 3"/>', ' stroke-width="1"'),
    noEntry: line('<circle cx="9" cy="9" r="6"/><path d="m4.8 4.8 8.4 8.4"/>', ' stroke-width="1.2"'),
    lineNumbers: line('<path d="M7 5h8.5M7 9h8.5M7 13h8.5M3 4l1-.6V6.2M2.6 8.4c.3-.5 1.7-.6 1.7.3 0 .7-1.7 1.4-1.7 2h1.8M2.6 11.9c.4-.3 1.6-.3 1.6.4s-.8.6-.8.6.9 0 .9.7-1.3.8-1.7.4"/>', ' stroke-width="1"'),
    activity: line('<circle cx="9" cy="9" r="6.5"/><path d="M5.8 7.4h6.4M5.8 10.6h6.4"/>', ' stroke-width="1.1"'),
    plus: line('<path d="M9 3.5v11M3.5 9h11"/>', ' stroke-width="1.3"'),
    check: line('<path d="M4.2 9.4 7.4 12.5l6.4-7"/>', ' stroke-width="2.2"'),
    dash: line('<path d="M5 9h8"/>', ' stroke-width="2.2"'),
    commit: line('<circle cx="9" cy="9" r="6.8"/><circle cx="9" cy="9" r="2.4" fill="currentColor"/>'),
    doc: paper(
        '<path d="M4.6 8h6.8M4.6 10h6.8M4.6 12h6.8M4.6 14h4.4" class="sd-doc-line"/>',
    ),
    code: paper(
        '<path d="M9.8 7.6 6.8 10h2.6l-3 2.6" fill="none" stroke="#f08a24" stroke-width="1.4" ' +
            'stroke-linecap="round" stroke-linejoin="round"/>',
    ),
} as const;

/** 图标的名字。 */
export type IconName = keyof typeof icons;

/** 按文件名取文件图标：代码文件带橙色记号，其余是普通文稿。 */
export function fileIcon(path: string): string {
    return /\.(ts|js|tsx|jsx|swift)$/.test(path) ? icons.code : icons.doc;
}
