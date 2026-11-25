/* global ARMFUL_KNOT, ARMFUL_LEAF, ARMFUL_LIT, ARMFUL_PALETTES, ARMFUL_POSE, ARMFUL_SPARKLES, ARMFUL_TAPERS */
/* global CHERRY_PICK_EYES, CHERRY_PICK_GHOST, GRID, MIDNIGHT_GHOST, PERCH_EYES, PERCH_GHOST */
/* global STICKER_BRANCH_COLORS, STICKER_GHOST_EYE, SVG_WIDE */
/* global cherrySticker, cherryStemLines, discShape, ghostPose, ghostSticker, leafSticker, sparkleData, starsMarkup */
/* global stickerId, svgBlurred, svgLinear, svgStops, taperData */

import { clamp, lerp, lerpEach, sway } from './timing.js';

/*
 * 贴纸的画法：满月、幽灵、树枝与樱桃都交给 App 应用图标的绘制脚本（仓库的 scripts/make-icon/）去画，
 * 这里只把它们按 “投影、贴纸边、成品” 拆开，让幽灵、树枝与樱桃可以各自移动，而整团仍然共用一圈贴纸边。
 *
 * 坐标都是图标坐标：图标的 1024 网格贴着成片的底边铺满整宽，原点在这个方格的左上角，方格以上的画面 y 为负。
 * 四组图标的构图因此原样搬进成片，不用换算。栖枝一幕是远景，画好之后整幅再缩小，见 zoomed 与 camera.js。
 */

/** 成片的像素尺寸。 */
const STAGE = { width: 1080, height: 1920 };

/** 一个图标单位合多少像素：图标的 1024 网格铺满成片的宽。 */
const UNIT = STAGE.width / GRID;

/** 画面的范围，图标单位。 */
export const SCENE = { width: GRID, height: STAGE.height / UNIT };

/** 图标的方格上方还有多高的画面，图标单位：画面最上面一行的 y 是 −DROP。 */
export const DROP = SCENE.height - GRID;

/** 贴纸的配色：默认图标的一套，加上树枝的颜色。 */
export const palette = { ...ARMFUL_PALETTES.default, ...STICKER_BRANCH_COLORS.default };

/** 贴纸边的宽度，与图标相同。 */
const EDGE = ARMFUL_POSE.edge;

/**
 * 幽灵的眼睛，在幽灵自身坐标里；每组依次是画面左边的一只与右边的一只。
 *
 * up 望向右上，是午夜与栖枝里的样子；right 望向右边，是采撷里的样子；front 望着镜头；below 低着头，望向画面下方。
 */
export const EYES = {
    up: PERCH_EYES.map((eye) => ({ size: 1, tilt: STICKER_GHOST_EYE.tilt, ...eye })),
    right: CHERRY_PICK_EYES.map((eye) => ({ size: 1, tilt: STICKER_GHOST_EYE.tilt, ...eye })),
    front: [{ u: -22, v: 232, size: 1, tilt: 2 }, { u: 104, v: 230, size: 0.96, tilt: 2 }],
    below: [{ u: 4, v: 268, size: 1, tilt: 2 }, { u: 128, v: 264, size: 0.96, tilt: 2 }],
};

/**
 * 幽灵在前三组图标里的姿态：头顶的位置、大小与倾角都照图标，另加停住时轻轻浮动的幅度 float 与点头的幅度 nod。
 *
 * 午夜里它从左下角探身进来，栖枝里站在枝上，采撷里朝樱桃那边倾着身子。
 * eager 不在图标里：是栖枝一幕末尾的样子，从枝上飘起来、身子朝樱桃探过去，采撷一幕从它接着走。
 */
export const POSES = {
    midnight: { ...MIDNIGHT_GHOST, float: 4, nod: 0.7 },
    perch: { ...PERCH_GHOST, float: 1.6, nod: 0.5 },
    eager: {
        top: [PERCH_GHOST.top[0] + 52, PERCH_GHOST.top[1] - 118],
        scale: PERCH_GHOST.scale,
        lean: [PERCH_GHOST.lean[0] + 15, PERCH_GHOST.lean[1] + 4],
        float: 4,
        nod: 0.5,
    },
    pick: { ...CHERRY_PICK_GHOST, float: 4, nod: 0.8 },
};

/**
 * 两组眼睛之间的过渡。
 *
 * @param {{u: number, v: number, size: number, tilt: number}[]} from 起始的一组
 * @param {{u: number, v: number, size: number, tilt: number}[]} to 结束的一组
 * @param {number} amount 0 取 from，1 取 to
 */
export function mixEyes(from, to, amount) {
    return from.map((eye, index) => ({
        u: lerp(eye.u, to[index].u, amount),
        v: lerp(eye.v, to[index].v, amount),
        size: lerp(eye.size, to[index].size, amount),
        tilt: lerp(eye.tilt, to[index].tilt, amount),
    }));
}

/**
 * 两个姿态之间的过渡。
 *
 * 姿态除了绘制脚本 ghostPose 的三项（头顶的位置 top、大小 scale、脊线在头部与下摆处的倾角 lean），
 * 还带着停住时轻轻浮动的幅度 float 与点头的幅度 nod。
 *
 * @param {{top: number[], scale: number, lean: number[], float: number, nod: number}} from 起始的姿态
 * @param {{top: number[], scale: number, lean: number[], float: number, nod: number}} to 结束的姿态
 * @param {number} amount 0 取 from，1 取 to
 */
export function mixPose(from, to, amount) {
    return {
        top: lerpEach(from.top, to.top, amount),
        scale: lerp(from.scale, to.scale, amount),
        lean: lerpEach(from.lean, to.lean, amount),
        float: lerp(from.float, to.float, amount),
        nod: lerp(from.nod, to.nod, amount),
    };
}

/**
 * 把一个姿态交给绘制脚本算出脊线，顺带加上轻轻的浮动与点头。
 *
 * 浮动与点头只由全片的时间决定：一幕结束时与下一幕开始时，同一个姿态落在同一个位置。
 *
 * @param {{top: number[], scale: number, lean: number[], float: number, nod: number}} pose 姿态
 * @param {number} t 当前时间
 * @returns {{scale: number, place: Function, degrees: Function}} 绘制脚本的姿态
 */
export function breathing({ top, scale, lean, float, nod }, t) {
    return ghostPose({
        top: [top[0], top[1] + float * sway(t, 3.1)],
        scale,
        lean: [lean[0] + nod * sway(t, 3.9, 0.3), lean[1]],
    });
}

/**
 * 四角星眨一下：上下两个角尖略微收短再伸回去，左右两个角尖不动。
 *
 * shrink 是上下最多收掉的比例，length 是这一下的时长。
 */
export const TWINKLE = { shrink: 0.12, length: 0.2 };

/**
 * 一只幽灵的贴纸：身体与小手交给绘制脚本的 ghostSticker，眼睛在这里画，才能眨眼、才能渐渐亮成四角星。
 *
 * 竖椭圆的眼睛眨眼时上下压扁；四角星眨眼时只把上下两个角尖略微收短，见 TWINKLE。
 *
 * @param {object} options
 * @param {{scale: number, place: Function, degrees: Function}} options.pose 姿态，见 breathing
 * @param {{line: number[][], from: number, to: number}[]} [options.hands]
 *     小手：中线经过的点（图标坐标）与两头的粗细
 * @param {{u: number, v: number, size: number, tilt: number}[]} options.eyes 眼睛，见 EYES
 * @param {number} [options.blink] 竖椭圆眨眼的程度，0 是睁着，1 是闭上
 * @param {number} [options.lit] 眼睛亮成四角星的程度，0 是竖椭圆，1 是四角星
 * @param {number} [options.twinkle] 四角星眨一下的程度，0 是原样，1 是上下收到最短
 * @param {number} [options.flare] 四角星比平时大出的比例，亮起的那一下用
 * @param {number} [options.spin] 水平转身转过的角度，度：身体的轮廓不变，眼睛贴着身体绕过去，见 eyesAround
 * @returns {{defs: string, outline: Function, paint: Function, pose: object, place: Function}}
 *     贴纸，另带姿态 pose 与把自身坐标换成图标坐标的 place
 */
export function ghost({ pose, hands = [], eyes, blink = 0, lit = 0, twinkle = 0, flare = 0, spin = 0 }) {
    const place = (u, v) => smoothPlace(pose, u, v);
    const body = ghostSticker({ pose, hands, eyes: [] });

    // 眼睛跟着身体在那里的走向转；转身时绕到身侧的眼睛变窄。
    const marks = eyesAround(eyes, spin).map(({ u, v, size, tilt, width }) => {
        const [x, y] = place(u, v);

        return {
            x,
            y,
            radiusX: STICKER_GHOST_EYE.radiusX * size * width * pose.scale,
            radiusY: STICKER_GHOST_EYE.radiusY * size * pose.scale,
            turn: pose.degrees(v) + tilt,
            width,
        };
    });

    // 竖椭圆眨眼时只压扁竖直的半轴。
    const ovals = marks.map((mark) => ({ ...mark, radiusY: mark.radiusY * (1 - 0.9 * blink) }));

    // 四角星亮起时整颗从小放大；眨一下时只收短上下两个角尖。
    const grow = lerp(0.45, 1, lit) * (1 + flare);
    const squint = 1 - TWINKLE.shrink * twinkle;

    return {
        ...body,
        pose,
        place,
        paint: (colors) => body.paint(colors, false)
            + faded(ovalEyes(ovals), 1 - lit)
            + faded(sparkleEyes(marks, pose.scale * grow, grow, squint), lit),
    };
}

/** 樱桃挂着时两根梗两头的粗细，与绘制脚本的 stemSticker 相同。 */
export const STEM = { from: 13.6, to: 11.6 };

/**
 * 一束樱桃在结上面的那一截，照满怀的图标：一小段梗，顶上长着一片叶子。
 *
 * stalk 是那一小段梗的中线经过的点，从顶上到结；from 与 to 是它两头的粗细；leaf 是叶柄一头与叶尖。
 * 位置都是放到画面上之后相对结的。
 */
const SPRIG = {
    stalk: ARMFUL_TAPERS.stemTop.line.map(besideKnot),
    from: ARMFUL_TAPERS.stemTop.from * ARMFUL_POSE.scale,
    to: ARMFUL_TAPERS.stemTop.to * ARMFUL_POSE.scale,
    leaf: [ARMFUL_LEAF.from, ARMFUL_LEAF.to].map(besideKnot),
};

/**
 * 一束樱桃在结上面的那一截：从结上长出的一小段梗，与长在它顶上的那片叶子。
 *
 * 樱桃挂在枝上时，这一截绕着结转一个角度，那一小段梗搭在枝上；摘下来抱进怀里，转回满怀图标里的朝向。
 *
 * @param {{x: number, y: number}} knot 梗分叉处的结
 * @param {number} degrees 相对满怀图标里的朝向转过的角度，度；正值在画面上是顺时针
 * @returns {{stalk: {line: number[][], from: number, to: number}, leaf: {from: number[], to: number[]}}}
 */
export function sprigAt(knot, degrees) {
    const put = (offset) => {
        const [dx, dy] = turned(offset, [0, 0], degrees);

        return [knot.x + dx, knot.y + dy];
    };

    const [from, to] = SPRIG.leaf.map(put);

    return {
        stalk: { line: SPRIG.stalk.map(put), from: SPRIG.from, to: SPRIG.to },
        leaf: { from, to },
    };
}

/**
 * 一束樱桃的梗的贴纸：几根渐细的梗与分叉处的结，沿 shade 由浅到深。
 *
 * 画法照绘制脚本的 stemSticker，只是每根各有粗细，渐变的起止由调用的一方给出。
 *
 * @param {{line: number[][], from: number, to: number}[]} tapers 各根梗的中线与两头的粗细
 * @param {{x: number, y: number, radius: number}} knot 分叉处的结
 * @param {number[]} shade 渐变的起点与终点 [x1, y1, x2, y2]
 * @returns {{defs: string, outline: Function, paint: Function}}
 */
export function stemsSticker(tapers, knot, shade) {
    const id = stickerId('stems');

    const shape = (fill) => tapers
        .map(({ line, from, to }) => `<path d="${taperData(line, from, to)}" fill="${fill}"/>`)
        .join('') + discShape(knot)(fill);

    return {
        defs: '',
        outline: shape,
        paint: (colors) => svgLinear(id, shade, colors.stem) + shape(`url(#${id})`),
    };
}

/**
 * 樱桃挂着时梗的渐变的起止：从两根梗的最高处竖直往下到最低处，与绘制脚本的 stemSticker 相同。
 *
 * 结上面的一小段在起点以上，取的是最浅的颜色。
 *
 * @param {number[][][]} lines 垂到两颗樱桃上的两根梗的中线经过的点
 * @param {{x: number}} knot 分叉处的结
 * @returns {number[]} [x1, y1, x2, y2]
 */
export function hangingShade(lines, knot) {
    const ys = lines.flat().map(([, y]) => y);

    return [knot.x, Math.min(...ys), knot.x, Math.max(...ys)];
}

/**
 * 挂在枝上的一束樱桃：结上面那一截的叶子，梗（两根垂到樱桃上，一小段搭在枝上），远处的一颗与近处的一颗，从后往前。
 *
 * @param {object} options
 * @param {{x: number, y: number, radius: number}} options.knot 梗分叉处的结
 * @param {{x: number, y: number, radius: number}} options.near 近处的樱桃
 * @param {{x: number, y: number, radius: number}} options.far 远处的樱桃
 * @param {number} options.turn 结上面的那一截转过的角度，见 sprigAt
 * @param {object[]} [options.nearShadows] 落在近处那颗上的短影，见绘制脚本的 cherrySticker
 * @param {object[]} [options.farShadows] 落在远处那颗上的短影
 * @returns {object[]} 四块贴纸
 */
export function cherryPair({ knot, near, far, turn, nearShadows = [], farShadows = [] }) {
    const { stalk, leaf } = sprigAt(knot, turn);
    const lines = cherryStemLines(knot, near, far);
    const hanging = lines.map((line) => ({ line, ...STEM }));

    return [
        leafSticker(leaf),
        stemsSticker([...hanging, stalk], knot, hangingShade(lines, knot)),
        cherrySticker({ ...far, shadows: farShadows }),
        cherrySticker({ ...near, shadows: nearShadows }),
    ];
}

/**
 * 几块贴纸用到的滤镜定义：投影、贴纸边与成品都引用它们，每帧只给出一次。
 *
 * @param {object[]} stickers 贴纸
 */
export function defsOf(stickers) {
    return stickers.map(({ defs }) => defs).join('');
}

/**
 * 几块贴纸落在底板上的投影。
 *
 * @param {object[]} stickers 贴纸
 */
export function castOf(stickers) {
    return svgBlurred(stickerId('cast'), silhouette(stickers, palette.cast), {
        dx: 6,
        dy: 14,
        blur: 24,
        opacity: 0.5,
    });
}

/**
 * 几块贴纸四周的贴纸边：剪影往外描粗一圈。
 *
 * @param {object[]} stickers 贴纸
 */
export function edgeOf(stickers) {
    return silhouette(stickers, palette.edge);
}

/**
 * 几块贴纸的成品，从后往前。
 *
 * @param {object[]} stickers 贴纸
 */
export function paintOf(stickers) {
    return stickers.map((sticker) => sticker.paint(palette, false)).join('');
}

/**
 * 共用一圈贴纸边的一团贴纸：投影、贴纸边与成品，从后往前。
 *
 * @param {object[]} stickers 贴纸，从后往前
 */
export function clusterOf(stickers) {
    return defsOf(stickers) + castOf(stickers) + edgeOf(stickers) + paintOf(stickers);
}

/**
 * 几张截图卡片的投影与贴纸边，各自跟着卡片一起淡入淡出；投影都垫在贴纸边的后面。
 *
 * @param {{card: {left: number, top: number, crop: number[], radius: number}, opacity: number}[]} cards
 *     卡片（见 plan.js 的 CARDS）与它此刻的不透明度
 */
export function cardBackings(cards) {
    const frames = cards.map(({ card, opacity }) => ({ box: sceneBox(card), opacity }));

    return frames.map(({ box, opacity }) => faded(cardCast(box), opacity)).join('')
        + frames.map(({ box, opacity }) => faded(cardEdge(box), opacity)).join('');
}

/**
 * 几颗一明一暗的四角星。
 *
 * @param {number} t 当前时间
 * @param {{x: number, y: number, size: number, color: string, period: number, phase: number, shown?: number}[]} stars
 *     每颗星的中心、从中心到角尖的长度与颜色，明暗一个来回的秒数与起始相位，以及这颗星显出来的程度（省略为 1）
 */
export function twinkling(t, stars) {
    return stars.map(({ period, phase, shown = 1, ...star }) => faded(
        starsMarkup([star]),
        shown * (0.62 + 0.38 * sway(t, period, phase)),
    )).join('');
}

/**
 * 给一段画面整体设不透明度；完全透明时不画，完全不透明时不包一层。
 *
 * @param {string} markup 画面
 * @param {number} opacity 不透明度
 */
export function faded(markup, opacity) {
    if (opacity <= 0) {
        return '';
    }

    return opacity >= 1 ? markup : `<g opacity="${opacity}">${markup}</g>`;
}

/**
 * 把绘制脚本拼出的片段放进竖屏画面：蒙版与滤镜的作用范围从图标的大小放大到整幅画面。
 *
 * @param {string} markup 绘制脚本拼出的 SVG 片段
 */
export function widen(markup) {
    return markup.replaceAll(SVG_WIDE, wideRegion(1));
}

/**
 * 镜头拉远之后的画面：整段画面绕画面的右下角缩到 scale 倍，贴纸边、投影与柔边跟着一起缩。
 *
 * @param {string} markup 绘制脚本拼出的 SVG 片段，按图标坐标画
 * @param {number} scale 画面相对图标的倍数，1 是原大，见 camera.js 的 zoom
 */
export function zoomed(markup, scale) {
    if (scale === 1) {
        return markup;
    }

    // 右下角不动：图标坐标 (GRID, GRID) 缩放前后落在同一处。
    const shift = GRID * (1 - scale);

    // 画面缩小之后，同样大的一块画面对应的图标坐标范围更大：蒙版与滤镜的作用范围跟着放大。
    const wide = markup.replaceAll(SVG_WIDE, wideRegion(scale));

    return `<g transform="translate(${shift} ${shift}) scale(${scale})">${wide}</g>`;
}

/**
 * 把几个点一起挪开一段距离。
 *
 * @param {number[][]} points 点
 * @param {number[]} offset 挪开的量 [dx, dy]
 */
export function nudged(points, [dx, dy]) {
    return points.map(([x, y]) => [x + dx, y + dy]);
}

/**
 * 一个点绕另一个点转过一个角度之后的位置。
 *
 * @param {number[]} point 要转的点
 * @param {number[]} pivot 转动的中心
 * @param {number} degrees 转过的角度，度；正值在画面上是顺时针
 */
export function turned([x, y], [pivotX, pivotY], degrees) {
    const angle = (degrees * Math.PI) / 180;
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);

    return [
        pivotX + (x - pivotX) * cos - (y - pivotY) * sin,
        pivotY + (x - pivotX) * sin + (y - pivotY) * cos,
    ];
}

// MARK: - Private

/**
 * 满怀图标里结旁边的一个点，放到画面上之后相对结的位置：那一团放上去时整团转一点、再缩小。
 *
 * @param {number[]} point 满怀自己坐标里的点
 * @returns {number[]} [dx, dy]
 */
function besideKnot([x, y]) {
    const { degrees, scale } = ARMFUL_POSE;

    return turned([(x - ARMFUL_KNOT.x) * scale, (y - ARMFUL_KNOT.y) * scale], [0, 0], degrees);
}

/**
 * 蒙版与滤镜的作用范围：盖住整幅竖屏画面，四周各多出 200 个图标单位。
 *
 * 绘制脚本的范围只覆盖 1024 见方的图标。画面缩到 scale 倍时，这一圈换算回缩小之前的坐标。
 *
 * @param {number} scale 画面相对图标的倍数，见 zoomed
 * @returns {string} SVG 的 x、y、width 与 height 四个属性
 */
function wideRegion(scale) {
    const margin = 200;
    const width = GRID + margin;
    const height = Math.ceil(SCENE.height) + margin;

    // 右下角在画面右下角之外 margin 处，缩放前后不动；左上角按缩小的倍数往外推。
    const left = GRID - width / scale;
    const top = GRID - height / scale;

    return `x="${left}" y="${top}" width="${(width + margin) / scale}" height="${(height + margin) / scale}"`;
}

/**
 * 一张卡片在图标坐标里的位置、大小与圆角：卡片按成片的像素摆放，贴纸边与投影按图标单位画。
 *
 * @param {{left: number, top: number, crop: number[], radius: number}} card 卡片，见 plan.js 的 CARDS
 * @returns {{x: number, y: number, width: number, height: number, radius: number}}
 */
function sceneBox({ left, top, crop, radius }) {
    return {
        x: left / UNIT,
        y: top / UNIT - DROP,
        width: crop[2] / UNIT,
        height: crop[3] / UNIT,
        radius: radius / UNIT,
    };
}

/** 截图卡片四周贴纸边的宽度：比幽灵与樱桃的窄，卡片上的字才是主角。 */
const CARD_EDGE = 15;

/**
 * 截图卡片四周的贴纸边：只画一圈，卡片身后不垫颜色，卡片淡入淡出时不会透出贴纸边的颜色。
 *
 * @param {{x: number, y: number, width: number, height: number, radius: number}} box 卡片的位置、大小与圆角，图标坐标
 */
function cardEdge({ x, y, width, height, radius }) {
    const half = CARD_EDGE / 2;

    return `<rect x="${x - half}" y="${y - half}" width="${width + CARD_EDGE}" height="${height + CARD_EDGE}" `
        + `rx="${radius + half}" fill="none" stroke="${palette.edge}" stroke-width="${CARD_EDGE}"/>`;
}

/**
 * 截图卡片落在底板上的投影，与贴纸的投影同样的偏移与模糊。
 *
 * @param {{x: number, y: number, width: number, height: number, radius: number}} box 卡片的位置、大小与圆角，图标坐标
 */
function cardCast({ x, y, width, height, radius }) {
    const shape = `<rect x="${x - CARD_EDGE}" y="${y - CARD_EDGE}" width="${width + CARD_EDGE * 2}" `
        + `height="${height + CARD_EDGE * 2}" rx="${radius + CARD_EDGE}" fill="${palette.cast}"/>`;

    return svgBlurred(stickerId('card-cast'), shape, { dx: 6, dy: 14, blur: 24, opacity: 0.5 });
}

/**
 * 几块贴纸染成一种颜色、往外描粗一圈的剪影。
 */
function silhouette(stickers, color) {
    return `<g stroke="${color}" stroke-width="${EDGE * 2}" stroke-linejoin="round" stroke-linecap="round">`
        + stickers.map((sticker) => sticker.outline(color)).join('')
        + '</g>';
}

/**
 * 竖椭圆的眼睛。
 *
 * @param {{x: number, y: number, radiusX: number, radiusY: number, turn: number}[]} marks 每只眼睛的中心、两个半轴与转过的角度
 */
function ovalEyes(marks) {
    return marks.map(({ x, y, radiusX, radiusY, turn }) => (
        `<ellipse cx="${x}" cy="${y}" rx="${radiusX}" ry="${radiusY}" `
        + `transform="rotate(${turn} ${x} ${y})" fill="${palette.eye}"/>`
    )).join('');
}

/**
 * 亮成四角星的眼睛：自上而下由浅琥珀到深橙，四周一圈光，画法照绘制脚本的 ghostSticker。
 *
 * @param {{x: number, y: number, radiusX: number, radiusY: number, turn: number, width: number}[]} marks
 *     每只眼睛的中心、两个半轴与转过的角度，以及横向相对平时的宽窄：变窄时修圆角尖的描边跟着变细
 * @param {number} scale 修圆角尖的描边相对图标里的粗细：幽灵的大小乘上四角星的大小
 * @param {number} grow 四角星相对图标里的大小
 * @param {number} squint 上下两个角尖到中心的距离相对平时的比例，眨一下时略小于 1
 */
function sparkleEyes(marks, scale, grow, squint) {
    const id = stickerId('eyes');

    // 四角星：同色的圆头描边把四个角尖修圆。
    const stars = (fill) => marks.map(({ x, y, radiusX, radiusY, turn, width }) => {
        const data = sparkleData(
            x,
            y,
            radiusX * ARMFUL_SPARKLES.reachX * grow,
            radiusY * ARMFUL_SPARKLES.reachY * grow * squint,
        );

        return `<path d="${data}" transform="rotate(${turn} ${x} ${y})" fill="${fill}" stroke="${fill}" `
            + `stroke-width="${ARMFUL_SPARKLES.rounding * scale * width}" stroke-linejoin="round"/>`;
    }).join('');

    return svgBlurred(`${id}-glow`, stars(ARMFUL_LIT.eyeGlow), { blur: 16, opacity: 0.75 })
        + `<linearGradient id="${id}-fill" x1="0" y1="0" x2="0" y2="1">${svgStops(ARMFUL_LIT.eye)}</linearGradient>`
        + stars(`url(#${id}-fill)`);
}

/**
 * 幽灵水平转身时眼睛绕着转的那一圈，在自身坐标里的半径：比身体在眼睛那个高度的半宽略小，
 * 眼睛转到身侧时正好收进轮廓里面。
 */
const GIRTH = 236;

/**
 * 幽灵水平转过一个角度之后的两只眼睛：贴着身体绕过去，转到背面的不画。
 *
 * 一只眼睛的高低与大小只看它转到了离正面多远的地方：正好落在没转身时两只眼睛的位置上，就是那两只的样子；
 * 再往身侧去越来越窄，转到画面左半边时倾角反过来。转满一整圈与没转身时分毫不差。
 *
 * @param {{u: number, v: number, size: number, tilt: number}[]} eyes 没转身时的两只眼睛，都在身体的右半边
 * @param {number} degrees 转过的角度，度；正值时眼睛先往画面右边绕过去
 * @returns {{u: number, v: number, size: number, tilt: number, width: number}[]}
 *     看得见的眼睛；width 是横向相对平时的宽窄
 */
function eyesAround(eyes, degrees) {
    if (degrees % 360 === 0) {
        return eyes.map((eye) => ({ ...eye, width: 1 }));
    }

    // 没转身时两只眼睛各在离正面多远的地方，度；靠里的一只与靠外的一只。
    const angles = eyes.map(({ u }) => (Math.asin(u / GIRTH) * 180) / Math.PI);
    const inner = angles[0] <= angles[1] ? 0 : 1;
    const outer = 1 - inner;

    return eyes.flatMap((eye, index) => {
        // 这只眼睛此刻转到了哪里：0 正对镜头，正值在画面右边，到 ±90 就绕到了背面。
        const side = ((((angles[index] + degrees + 180) % 360) + 360) % 360) - 180;

        if (Math.abs(side) >= 90) {
            return [];
        }

        const outward = clamp((Math.abs(side) - angles[inner]) / (angles[outer] - angles[inner]));
        const radians = (side * Math.PI) / 180;

        return [{
            u: GIRTH * Math.sin(radians),
            v: lerp(eyes[inner].v, eyes[outer].v, outward),
            size: lerp(eyes[inner].size, eyes[outer].size, outward),
            tilt: eye.tilt * clamp(side / angles[inner], -1, 1),

            // 比靠外那只眼睛更靠身侧时，按看过去的斜度收窄，到身侧收成一条线。
            width: clamp(Math.cos(radians) / Math.cos((angles[outer] * Math.PI) / 180)),
        }];
    });
}

/**
 * 幽灵自身坐标里的点在画面里的位置。
 *
 * 绘制脚本的脊线每 2 个单位取一个点，这里在相邻两点之间插值：眼睛沿身体移动时才不会一格一格地跳。
 */
function smoothPlace(pose, u, v) {
    const low = Math.floor(v / 2) * 2;
    const [fromX, fromY] = pose.place(u, low);
    const [toX, toY] = pose.place(u, low + 2);
    const amount = (v - low) / 2;

    return [lerp(fromX, toX, amount), lerp(fromY, toY, amount)];
}
