/* global CHERRY_PICK_BRANCH, CHERRY_PICK_CHERRIES, CHERRY_PICK_KNOT, CHERRY_PICK_LEAVES */
/* global PERCH_CHERRIES, PERCH_KNOT, PERCH_LEAVES, PERCH_SEAT, PERCH_TWIG */
/* global arcLengths, branchSticker, chordSpline, cubicPoints, leafSticker */

import { nudged, turned } from './stickers.js';
import { lerp, lerpEach, sway } from './timing.js';

/*
 * 樱桃树的两根枝：幽灵站的那一根，与挂着一对樱桃的那一根。
 *
 * 挂樱桃的枝在栖枝里是右上角伸进来的一根细枝；采撷里镜头推近，它成了横在幽灵头顶的一根粗枝。
 * 两组图标里的枝、枝上的叶子、梗分叉处的结与两颗樱桃一一对应，这里按推近的程度在两者之间过渡。
 *
 * 图标里枝上各有两片叶子，成片里只有头一片留在枝上；另一片长在樱桃的梗上，跟着樱桃一起摘下来，
 * 画在樱桃那一束里，见 stickers.js 的 sprigAt。
 */

/** 幽灵站的枝往左接长到的 x：远景里画面的左边远在图标的方格之外，枝要一直伸出画面。 */
const SEAT_START = -1000;

/**
 * 幽灵站的枝：栖枝图标里的那一根，左头顺着原来的走向接长，粗细照原来的斜率接着变粗。
 *
 * 图标的方格里面的那一段与图标里的枝相同。
 */
export const SEAT = lengthened(PERCH_SEAT, SEAT_START);

/** 过渡途中，一条中线沿走过的路程均分成多少段。 */
const SEGMENTS = 8;

/**
 * 栖枝里的样子：枝的中线与两头的粗细、枝上的叶子、结、近处与远处的樱桃，
 * 以及樱桃在结上面的那一截转过的角度（见 stickers.js 的 sprigAt）：那一小段梗顺着细枝的梢头。
 */
const AFAR = {
    line: PERCH_TWIG.line,
    from: PERCH_TWIG.from,
    to: PERCH_TWIG.to,
    leaf: PERCH_LEAVES[0],
    knot: PERCH_KNOT,
    near: PERCH_CHERRIES.big,
    far: PERCH_CHERRIES.small,
    turn: 32,
};

/** 采撷里的样子，各项同上：结上面的那一小段梗往上搭在枝上。 */
const CLOSE = {
    line: CHERRY_PICK_BRANCH.line,
    from: CHERRY_PICK_BRANCH.from,
    to: CHERRY_PICK_BRANCH.to,
    leaf: CHERRY_PICK_LEAVES[0],
    knot: CHERRY_PICK_KNOT,
    near: CHERRY_PICK_CHERRIES.held,
    far: CHERRY_PICK_CHERRIES.other,
    turn: -26,
};

/** 两组图标里枝的中线，各自沿路程均分之后的点：过渡时逐点对应。 */
const AFAR_LINE = evenly(AFAR.line);
const CLOSE_LINE = evenly(CLOSE.line);

/** 镜头从栖枝推近到采撷，画面放大的倍数：照两组图标里枝的粗细算出。 */
const PUSH_SCALE = CLOSE.from / AFAR.from;

/** 推近时画面上不动的那一点：照两组图标里结的位置算出，结正好从栖枝里的位置放大到采撷里的位置。 */
const PUSH_CENTER = [
    (CLOSE.knot.x - PUSH_SCALE * AFAR.knot.x) / (1 - PUSH_SCALE),
    (CLOSE.knot.y - PUSH_SCALE * AFAR.knot.y) / (1 - PUSH_SCALE),
];

/**
 * 推近到某个程度时的枝与樱桃。
 *
 * @param {number} closeness 推近的程度，0 是栖枝里的样子，1 是采撷里的样子
 * @returns {{line: number[][], from: number, to: number, leaf: object, knot: object, near: object, far: object, turn: number}}
 */
export function boughAt(closeness) {
    // 两头直接用图标的原样，停住时与图标分毫不差。
    if (closeness <= 0) {
        return AFAR;
    }

    if (closeness >= 1) {
        return CLOSE;
    }

    const disc = (from, to) => ({
        x: lerp(from.x, to.x, closeness),
        y: lerp(from.y, to.y, closeness),
        radius: lerp(from.radius, to.radius, closeness),
    });

    return {
        line: AFAR_LINE.map((point, index) => lerpEach(point, CLOSE_LINE[index], closeness)),
        from: lerp(AFAR.from, CLOSE.from, closeness),
        to: lerp(AFAR.to, CLOSE.to, closeness),
        leaf: {
            from: lerpEach(AFAR.leaf.from, CLOSE.leaf.from, closeness),
            to: lerpEach(AFAR.leaf.to, CLOSE.leaf.to, closeness),
        },
        knot: disc(AFAR.knot, CLOSE.knot),
        near: disc(AFAR.near, CLOSE.near),
        far: disc(AFAR.far, CLOSE.far),
        turn: lerp(AFAR.turn, CLOSE.turn, closeness),
    };
}

/**
 * 幽灵站的枝在某处的高度：中线在那里的 y。
 *
 * 枝几乎是直的，相邻两个点之间按直线算。
 *
 * @param {number} x 枝上一处的 x
 */
export function seatLevel(x) {
    // 落在哪两个点之间；比最后一个点还靠右时取末段。
    const found = SEAT.line.findIndex(([pointX]) => pointX >= x);
    const after = found < 0 ? SEAT.line.length - 1 : Math.max(1, found);
    const [fromX, fromY] = SEAT.line[after - 1];
    const [toX, toY] = SEAT.line[after];

    return lerp(fromY, toY, (x - fromX) / (toX - fromX));
}

/**
 * 镜头推近到某个程度时，树上别的枝跟着放大、挪开之后的样子：与挂樱桃的枝同一个中心、同一个倍数。
 *
 * @param {{line: number[][], from: number, to: number}} branch 栖枝里的一根枝：中线经过的点与两头的粗细
 * @param {number} closeness 推近的程度，0 是栖枝里的样子，1 是采撷里的样子
 * @returns {{line: number[][], from: number, to: number}}
 */
export function pushedIn({ line, from, to }, closeness) {
    const scale = lerp(1, PUSH_SCALE, closeness);

    return {
        line: line.map((point) => lerpEach(PUSH_CENTER, point, scale)),
        from: from * scale,
        to: to * scale,
    };
}

/**
 * 把整根枝连同樱桃一起挪开一段距离。
 *
 * @param {object} bough 枝与樱桃，见 boughAt
 * @param {number[]} offset 挪开的量 [dx, dy]
 */
export function movedBough({ line, leaf, knot, near, far, ...rest }, offset) {
    const disc = ({ x, y, radius }) => ({ x: x + offset[0], y: y + offset[1], radius });
    const [from, to] = nudged([leaf.from, leaf.to], offset);

    return {
        ...rest,
        line: nudged(line, offset),
        leaf: { from, to },
        knot: disc(knot),
        near: disc(near),
        far: disc(far),
    };
}

/**
 * 枝与枝上的叶子的贴纸，从后往前。
 *
 * @param {object} bough 枝与樱桃，见 boughAt
 */
export function boughStickers({ line, from, to, leaf }) {
    return [branchSticker({ line, from, to }), leafSticker(leaf)];
}

/**
 * 一颗樱桃绕着结摆过一个角度之后的位置。
 *
 * @param {{x: number, y: number, radius: number}} cherry 樱桃
 * @param {{x: number, y: number}} knot 梗分叉处的结
 * @param {number} degrees 摆过的角度，度；正值往画面左边摆
 */
export function swung(cherry, knot, degrees) {
    const [x, y] = turned([cherry.x, cherry.y], [knot.x, knot.y], degrees);

    return { ...cherry, x, y };
}

/**
 * 樱桃挂着不动时被风吹出的一点摆动，度；只由全片的时间决定，换幕时接得上。
 *
 * @param {number} t 当前时间
 * @returns {{near: number, far: number}} 近处与远处两颗各自摆过的角度，远处的一颗慢半拍
 */
export function breeze(t) {
    return { near: 1.1 * sway(t, 2.7), far: 1.6 * sway(t, 2.7, -0.13) };
}

/**
 * 平滑穿过各点的曲线上，沿走过的路程均分的点。
 *
 * @param {number[][]} line 曲线依次经过的点
 * @returns {number[][]} 含两端，共 SEGMENTS + 1 个点
 */
export function evenly(line) {
    const dense = [line[0]];

    for (const [start, control1, control2, end] of chordSpline(line, false)) {
        dense.push(...cubicPoints(start, control1, control2, end, 24).slice(1));
    }

    const travelled = arcLengths(dense);
    const total = travelled[travelled.length - 1];

    return Array.from({ length: SEGMENTS + 1 }, (_, index) => {
        const target = (total * index) / SEGMENTS;

        // 落在哪两个采样点之间；最后一个点因舍入可能找不到，取末段。
        const found = travelled.findIndex((length) => length >= target);
        const after = Math.max(1, found < 0 ? dense.length - 1 : found);
        const amount = (target - travelled[after - 1]) / (travelled[after] - travelled[after - 1]);

        return lerpEach(dense[after - 1], dense[after], Math.min(1, amount));
    });
}

// MARK: - Private

/**
 * 把一根枝的起点一头顺着原来的走向接长到 x = start：原来的那一段中线不变，粗细也不变。
 *
 * @param {{line: number[][], from: number, to: number}} branch 枝：中线经过的点与两头的粗细
 * @param {number} start 接长之后起点的 x
 * @returns {{line: number[][], from: number, to: number}}
 */
function lengthened({ line, from, to }, start) {
    const [[firstX, firstY], [nextX, nextY]] = line;

    // 新的起点落在头两个点的连线上：穿过各点的曲线在原来的那一段里走向不变。
    const slope = (nextY - firstY) / (nextX - firstX);
    const head = [start, firstY + slope * (start - firstX)];

    // 粗细沿路程均匀变化：接长的一段照原来每走一个单位变粗的量接着变粗。
    const travelled = arcLengths(line);
    const added = Math.hypot(firstX - head[0], firstY - head[1]);
    const thickening = (from - to) / travelled[travelled.length - 1];

    return { line: [head, ...line], from: from + thickening * added, to };
}
