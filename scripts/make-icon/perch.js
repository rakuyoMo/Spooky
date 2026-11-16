/**
 * 栖枝：夜色渐变里一轮很淡的月亮与几颗小星，一只白色幽灵落在树枝上；树枝从左边伸进来，在右边分成两根细枝，
 * 上面那根的枝头结一颗红橙色的果子，幽灵望着它。App 连着服务器时，果子亮成琥珀色。
 * 不超过 32 px 的尺寸只画放大的幽灵、主枝与果子。深色图标的底板是纯黑，幽灵换成浅米色。
 */

/** 不超过这个像素尺寸时，栖枝只画主体。 */
const COMPACT_PIXELS = 32;

/**
 * 栖枝两种图标的配色：底板自上而下由 plateTop 过渡到 plateBottom，moon 是月亮的不透明度，
 * 幽灵用 ghost、左侧的暗面用 shade、眼睛用 eye，树枝与叶子用 branch。
 *
 * 默认图标是夜色过渡到亮紫的底板上一只白色幽灵；深色图标的底板上下都是纯黑，幽灵换成浅米色。
 */
const PERCH_PALETTES = {
    default: {
        plateTop: '#241D63',
        plateBottom: '#6F60E6',
        moon: 0.1,
        ghost: '#FFFFFF',
        shade: '#DAD4F6',
        eye: '#2A2163',
        branch: '#17113F',
    },
    dark: {
        plateTop: '#000000',
        plateBottom: '#000000',
        moon: 0.07,
        ghost: '#EBE5D5',
        shade: '#CFC6B2',
        eye: '#111111',
        branch: '#3B347A',
    },
};

/** 栖枝的果子：灭着时的红橙色与左上那点高光，亮着时的琥珀色与中心的灯芯。 */
const PERCH_FRUIT_COLORS = {
    unlit: '#F4572F',
    glint: '#FF8B66',
    lit: '#FFB020',
    wick: '#FFF1C9',
};

/** 栖枝的幽灵：头的圆心与半径、下摆各瓣圆心的 y、两侧往外张开的角度、下摆的瓣数与整体往右侧的角度。 */
const PERCH_GHOST = {
    x: 462,
    y: 452,
    radius: 212,
    hem: 704,
    flare: 3.5,
    lobes: 4,
    tilt: 3,
};

/** 栖枝的树枝各段：中线经过的点与起止的宽度。主枝从左边伸进来，在右边分成上下两根细枝，左边另有一根短枝。 */
const PERCH_BRANCHES = [
    { line: [[40, 820], [220, 796], [400, 776], [560, 764], [660, 758]], from: 78, to: 48 },
    { line: [[604, 761], [690, 738], [752, 680], [790, 596], [806, 520]], from: 40, to: 14 },
    { line: [[640, 760], [730, 756], [800, 740], [836, 722]], from: 48, to: 14 },
    { line: [[240, 795], [218, 752], [200, 722]], from: 30, to: 12 },
];

/** 栖枝的叶子：叶柄一头的位置、叶尖的位置与最宽处的宽度。 */
const PERCH_LEAVES = [
    [[834, 723], [894, 688], 34],
    [[770, 652], [846, 626], 34],
    [[797, 566], [742, 522], 32],
    [[204, 730], [170, 664], 34],
    [[214, 748], [146, 728], 30],
];

/** 幽灵望着的果子：圆心与半径。 */
const PERCH_FRUIT = [810, 488, 32];

/** 只画主体时的树枝：只留加粗的主枝与结果子的那根细枝。 */
const PERCH_COMPACT_BRANCHES = [
    { line: [[40, 824], [220, 798], [400, 778], [560, 766], [700, 760], [860, 736]], from: 104, to: 70 },
    { line: [[604, 763], [690, 738], [752, 680], [790, 596], [804, 530]], from: 64, to: 36 },
];

/** 只画主体时的果子：放大。 */
const PERCH_COMPACT_FRUIT = [808, 486, 54];

/** 只画主体时，幽灵、树枝与果子整体放大的中心与倍数。 */
const PERCH_COMPACT_ZOOM = { x: 492, y: 560, scale: 1.12 };

/**
 * 栖枝的入口：画面先铺满一张画布，再整张填进底板；不超过 `COMPACT_PIXELS` 的尺寸画精简的一版。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 */
function paintPerchIcon(context, scale, pixels, style, lit) {
    const palette = PERCH_PALETTES[style];
    const compact = pixels <= COMPACT_PIXELS;
    const scene = paintScene(pixels, (sceneContext) => drawPerch(sceneContext, palette, lit, compact));

    drawPlateScene(context, scale, scene, palette.plateBottom);
}

/**
 * 栖枝的画面，铺满整张画布。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {object} palette 所画图标的配色
 * @param {boolean} lit 幽灵望着的果子是否亮着
 * @param {boolean} compact 是否只画主体
 */
function drawPerch(context, palette, lit, compact) {
    drawPerchBackdrop(context, palette, compact);

    if (!compact) {
        drawPerchBranch(context, palette, lit, PERCH_BRANCHES, PERCH_LEAVES, PERCH_FRUIT);
        drawPerchGhost(context, palette);
        return;
    }

    // 只画主体：幽灵与树枝整体放大，叶子与短枝不画。
    const { x, y, scale } = PERCH_COMPACT_ZOOM;

    context.save();
    context.translate(x, y);
    context.scale(scale, scale);
    context.translate(-x, -y);
    drawPerchBranch(context, palette, lit, PERCH_COMPACT_BRANCHES, [], PERCH_COMPACT_FRUIT);
    drawPerchGhost(context, palette);
    context.restore();
}

/**
 * 栖枝的背景：夜色渐变上一轮很淡的月亮，月亮外几颗小星；只画主体时不画星。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {{plateTop: string, plateBottom: string, moon: number}} palette 所画图标的配色
 * @param {boolean} compact 是否只画主体
 */
function drawPerchBackdrop(context, palette, compact) {
    context.fillStyle = verticalGradient(
        context,
        PLATE_ORIGIN,
        PLATE_ORIGIN + PLATE_SIZE,
        palette.plateTop,
        palette.plateBottom,
    );

    context.fillRect(0, 0, GRID, GRID);

    context.fillStyle = translucent('#FFFFFF', palette.moon);
    context.fill(circle(506, 462, 304));

    if (compact) {
        return;
    }

    context.fillStyle = translucent('#FFFFFF', 0.42);

    for (const [x, y, radius] of [[212, 262, 13], [806, 236, 15], [876, 346, 9]]) {
        context.fill(fourPointStar(x, y, radius));
    }
}

/**
 * 栖枝的树枝、叶子与枝头的果子。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {{branch: string}} palette 所画图标的配色
 * @param {boolean} lit 果子是否亮着
 * @param {{line: number[][], from: number, to: number}[]} branches 树枝的各段
 * @param {Array} leaves 叶子，见 PERCH_LEAVES
 * @param {number[]} fruit 果子的圆心与半径
 */
function drawPerchBranch(context, palette, lit, branches, leaves, fruit) {
    context.fillStyle = palette.branch;

    for (const { line, from, to } of branches) {
        context.fill(beadedTaper(line, from, to));
    }

    for (const [from, to, width] of leaves) {
        context.fill(new Path2D(lensData(from, to, width)));
    }

    const [x, y, radius] = fruit;

    // 亮着的果子外面套两圈平涂的光环。
    if (lit) {
        context.fillStyle = translucent(PERCH_FRUIT_COLORS.lit, 0.16);
        context.fill(circle(x, y, radius * 2.1));
        context.fillStyle = translucent(PERCH_FRUIT_COLORS.lit, 0.3);
        context.fill(circle(x, y, radius * 1.5));
    }

    context.fillStyle = lit ? PERCH_FRUIT_COLORS.lit : PERCH_FRUIT_COLORS.unlit;
    context.fill(circle(x, y, radius));

    // 灭着时左上一点浅色的高光，亮着时中心是浅黄的灯芯。
    context.fillStyle = lit ? PERCH_FRUIT_COLORS.wick : PERCH_FRUIT_COLORS.glint;

    context.fill(lit
        ? circle(x, y, radius * 0.45)
        : circle(x - radius * 0.32, y - radius * 0.32, radius * 0.26));
}

/**
 * 栖枝的幽灵：左侧一道平涂的暗面，两只朴素的椭圆眼睛望向右边的果子。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {{ghost: string, shade: string, eye: string}} palette 所画图标的配色
 */
function drawPerchGhost(context, palette) {
    const { x, y, hem, tilt } = PERCH_GHOST;
    const body = perchGhostBody(PERCH_GHOST);

    // 以下摆的正中为轴往右侧一点。
    context.save();
    context.translate(x, hem);
    context.rotate((tilt * Math.PI) / 180);
    context.translate(-x, -hem);

    context.fillStyle = palette.shade;
    context.fill(body);

    // 亮面是同一个轮廓往右挪一点、下摆拉长，只留下左侧一道暗面。
    context.save();
    context.clip(body);
    context.fillStyle = palette.ghost;
    context.fill(perchGhostBody({ ...PERCH_GHOST, x: x + 34, hem: hem + 120, lobes: 1 }));
    context.restore();

    context.fillStyle = palette.eye;
    context.fill(ellipse(x - 40, y - 12, 29, 42));
    context.fill(ellipse(x + 104, y - 12, 29, 42));
    context.restore();
}

/**
 * 栖枝的幽灵的轮廓：半圆的头，两侧是与头相切、往下摆略微张开的直线，下摆是几瓣朝下的圆弧。
 *
 * @param {{x: number, y: number, radius: number, hem: number, flare: number, lobes: number}} ghost 幽灵的尺寸，见 PERCH_GHOST
 * @returns {Path2D}
 */
function perchGhostBody({ x, y, radius, hem, flare, lobes }) {
    const angle = (flare * Math.PI) / 180;

    // 切点比头的圆心略高；从切点沿张开的方向走到下摆，得到下摆的半宽。
    const run = (hem - y + radius * Math.sin(angle)) / Math.cos(angle);
    const half = radius * Math.cos(angle) + run * Math.sin(angle);
    const lobe = half / lobes;
    const path = new Path2D();

    path.arc(x, y, radius, Math.PI + angle, -angle);
    path.lineTo(x + half, hem);

    for (let index = 0; index < lobes; index += 1) {
        path.arc(x + half - (2 * index + 1) * lobe, hem, lobe, 0, Math.PI);
    }

    path.closePath();
    return path;
}

/**
 * 沿一条平滑的中线、宽度从一头渐变到另一头的带子，由沿线密排的圆叠成。
 *
 * @param {number[][]} line 中线经过的点
 * @param {number} from 起点处的宽度
 * @param {number} to 终点处的宽度
 * @returns {Path2D}
 */
function beadedTaper(line, from, to) {
    const points = catmullRom(line, 60);
    const path = new Path2D();

    points.forEach(([x, y], index) => {
        const radius = (from + (to - from) * (index / (points.length - 1))) / 2;
        path.moveTo(x + radius, y);
        path.arc(x, y, radius, 0, Math.PI * 2);
    });

    return path;
}

/**
 * 四角星：四条边向内凹。
 *
 * @param {number} x 中心的 x
 * @param {number} y 中心的 y
 * @param {number} radius 尖角到中心的距离
 * @returns {Path2D}
 */
function fourPointStar(x, y, radius) {
    const waist = radius * 0.16;
    const path = new Path2D();

    path.moveTo(x, y - radius);
    path.quadraticCurveTo(x + waist, y - waist, x + radius, y);
    path.quadraticCurveTo(x + waist, y + waist, x, y + radius);
    path.quadraticCurveTo(x - waist, y + waist, x - radius, y);
    path.quadraticCurveTo(x - waist, y - waist, x, y - radius);
    path.closePath();
    return path;
}
