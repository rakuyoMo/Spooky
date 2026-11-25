/* global ARMFUL_PALETTES, ARMFUL_POSE, HIDE_AND_SEEK_COLORS, HIDE_AND_SEEK_EYES, STICKER_GHOST_EYE, SVG_WIDE */
/* global ghostPose, ghostSticker, pawSticker, serverSticker, starsMarkup, stickerId, svgBlurred, taperData */

import { lerp, lerpEach, sway } from './timing.js';

/*
 * 贴纸的画法：幽灵、服务器与小手都交给 App 应用图标的绘制脚本（仓库的 scripts/make-icon/）去画，
 * 这里只把它们按 “投影、贴纸边、成品” 拆开，让幽灵可以相对服务器移动，而整团仍然共用一圈贴纸边。
 *
 * 坐标都是画面坐标：与图标的 1024 网格同一个单位，画面宽 1024、高约 1820，原点在左上角。
 */

/** 成片的像素尺寸。 */
export const STAGE = { width: 1080, height: 1920 };

/** 一个画面单位合多少像素：图标的 1024 网格铺满成片的宽。 */
export const UNIT = STAGE.width / 1024;

/** 画面的范围，画面单位。 */
export const SCENE = { width: 1024, height: STAGE.height / UNIT };

/** 贴纸的配色：默认图标的一套，加上躲猫猫里服务器的颜色。 */
export const palette = { ...ARMFUL_PALETTES.default, ...HIDE_AND_SEEK_COLORS.default };

/** 贴纸边的宽度，与图标相同。 */
export const EDGE = ARMFUL_POSE.edge;

/** 蒙版与滤镜的作用范围：绘制脚本只覆盖 1024 见方的图标，这里放大到整幅竖屏画面。 */
const WIDE = `x="-200" y="-200" width="1424" height="${Math.ceil(SCENE.height) + 400}"`;

/**
 * 幽灵的眼睛，在幽灵自身坐标里；每组依次是画面左边的一只与右边的一只。
 *
 * front 望着前方，right 望向右边，back 是歪着身子回头望向左边，down 低头看着身前。
 */
export const EYES = {
    front: [{ u: -66, v: 236, size: 1, tilt: 0 }, { u: 66, v: 236, size: 1, tilt: 0 }],
    right: HIDE_AND_SEEK_EYES.map((eye) => ({ size: 1, tilt: STICKER_GHOST_EYE.tilt, ...eye })),
    back: [{ u: -130, v: 240, size: 0.92, tilt: -6 }, { u: -18, v: 244, size: 1, tilt: -6 }],
    down: [{ u: -62, v: 262, size: 1, tilt: 0 }, { u: 62, v: 262, size: 1, tilt: 0 }],
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
 * 一只幽灵的贴纸：身体与小手交给绘制脚本的 ghostSticker，眼睛在这里画，才能眨眼。
 *
 * @param {object} options
 * @param {number[]} options.top 头顶在画面里的位置
 * @param {number} options.scale 幽灵的大小，1 是自身坐标的原大
 * @param {number[]} [options.lean] 脊线在头部与下摆处的倾角，度，正值是头往右歪
 * @param {{points: number[][], from: number, to: number}[]} [options.hands]
 *     小手：中线经过的点与两头的粗细，都在幽灵自身坐标里，跟着身体走
 * @param {{u: number, v: number, size: number, tilt: number}[]} options.eyes 眼睛，见 EYES
 * @param {number} [options.blink] 眨眼的程度，0 是睁着，1 是闭上
 * @returns {{defs: string, outline: Function, paint: Function, pose: object, place: Function}}
 *     贴纸，另带姿态 pose 与把自身坐标换成画面坐标的 place
 */
export function ghost({ top, scale, lean = [0, 0], hands = [], eyes, blink = 0 }) {
    const pose = ghostPose({ top, scale, lean });
    const place = (u, v) => smoothPlace(pose, u, v);

    const body = ghostSticker({
        pose,
        hands: hands.map(({ points, from, to }) => ({
            line: points.map(([u, v]) => place(u, v)),
            from: from * scale,
            to: to * scale,
        })),
        eyes: [],
    });

    // 眼睛跟着身体在那里的走向转；眨眼时只压扁竖直的半轴。
    const eyesMarkup = eyes.map(({ u, v, size, tilt }) => {
        const [x, y] = place(u, v);
        const radiusX = STICKER_GHOST_EYE.radiusX * size * scale;
        const radiusY = STICKER_GHOST_EYE.radiusY * size * scale * (1 - 0.9 * blink);

        return `<ellipse cx="${x}" cy="${y}" rx="${radiusX}" ry="${radiusY}" `
            + `transform="rotate(${pose.degrees(v) + tilt} ${x} ${y})" fill="${palette.eye}"/>`;
    }).join('');

    return {
        ...body,
        pose,
        place,
        paint: (colors) => body.paint(colors, false) + eyesMarkup,
    };
}

/**
 * 一台服务器的贴纸，指示灯可以渐渐亮起来。
 *
 * @param {object} options 机身、盘位槽与指示灯，见绘制脚本的 serverSticker
 * @param {number} [glow] 指示灯亮起的程度，0 是灭着，1 是全亮
 */
export function server(options, glow = 0) {
    const dark = serverSticker(options);

    if (glow <= 0) {
        return { ...dark, paint: (colors) => dark.paint(colors, false) };
    }

    // 亮灯的一版叠在灭灯的一版上面：机身的像素相同，只有指示灯跟着不透明度亮起来。
    const lit = serverSticker(options);

    return {
        ...dark,
        paint: (colors) => dark.paint(colors, false) + `<g opacity="${glow}">${lit.paint(colors, true)}</g>`,
    };
}

/**
 * 压在别的东西上的一只小手：渐细的笔画，根部淡入身体。
 *
 * @param {number[][]} line 中线经过的点，画面坐标，从根部到手尖
 * @param {number} from 根部的粗细
 * @param {number} to 手尖的粗细
 * @param {number[]} [fade] 淡入的方向 [x1, y1, x2, y2]，省略时从根部到手尖
 * @returns {{defs: string, outline: Function, paint: Function}}
 */
export function paw(line, from, to, fade = [...line[0], ...line[line.length - 1]]) {
    return pawSticker({ data: taperData(line, from, to), fade });
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
 * @param {number} [edge] 贴纸边的宽度
 */
export function castOf(stickers, edge = EDGE) {
    return svgBlurred(stickerId('cast'), silhouette(stickers, palette.cast, edge), {
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
 * @param {number} [edge] 贴纸边的宽度
 */
export function edgeOf(stickers, edge = EDGE) {
    return silhouette(stickers, palette.edge, edge);
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
 * 举起来的小手，在幽灵自身坐标里：三个点依次是根部、肘部与手尖；
 * tucked 是缩在身体里的样子，raised 是举起来的样子，形状与粗细照探身的图标；
 * waving 是挥手时伸长了举高的样子，手离头远一些，摆到里侧也不会和头连成一片；
 * from 与 to 是两头的粗细。画面左边的一只照此左右翻转。
 */
export const ARM = {
    tucked: [[150, 440], [176, 452], [198, 462]],
    raised: [[190, 428], [304, 404], [372, 322]],
    waving: [[190, 428], [312, 382], [396, 262]],
    from: 134.7,
    to: 86.3,
};

/**
 * 一只小手。
 *
 * @param {number} side 画面右边的一只是 1，左边的一只是 −1
 * @param {number} raise 举起来的程度，0 是缩在身体里，1 是举起来
 * @param {object} [wave] 挥手的姿势，省略时不挥
 * @param {number} [wave.reach] 伸长了举高的程度，0 是举着的样子，1 是挥手的样子
 * @param {number} [wave.shoulder] 上臂绕根部转过的角度，度；正值往外摆，负值往头那一侧摆
 * @param {number} [wave.elbow] 前臂绕肘部转过的角度，度；正负同上
 * @returns {{points: number[][], from: number, to: number}} 小手，见 ghost
 */
export function arm(side, raise, { reach = 0, shoulder = 0, elbow = 0 } = {}) {
    const [root, joint, tip] = ARM.tucked.map((tucked, index) => lerpEach(
        lerpEach(tucked, ARM.raised[index], raise),
        ARM.waving[index],
        reach,
    ));

    // 上臂绕根部转，肘部随之起落；前臂再绕肘部转。两段各转各的，手臂的长短不变。
    const bent = turned(joint, root, shoulder);
    const hand = turned([bent[0] + tip[0] - joint[0], bent[1] + tip[1] - joint[1]], bent, elbow);

    return {
        points: [root, bent, hand].map(([u, v]) => [side * u, v]),
        from: ARM.from * lerp(0.5, 1, raise),
        to: ARM.to * lerp(0.5, 1, raise),
    };
}

/**
 * 一张卡片在画面坐标里的位置、大小与圆角：卡片按成片的像素摆放，贴纸边与投影按画面单位画。
 *
 * @param {{left: number, top: number, crop: number[], radius: number}} card 卡片，见 plan.js 的 CARDS
 * @returns {{x: number, y: number, width: number, height: number, radius: number}}
 */
export function sceneBox({ left, top, crop, radius }) {
    return {
        x: left / UNIT,
        y: top / UNIT,
        width: crop[2] / UNIT,
        height: crop[3] / UNIT,
        radius: radius / UNIT,
    };
}

/** 截图卡片四周贴纸边的宽度：比幽灵与服务器的窄，卡片上的字才是主角。 */
export const CARD_EDGE = 15;

/**
 * 截图卡片四周的贴纸边：只画一圈，卡片身后不垫颜色，卡片淡入淡出时不会透出贴纸边的颜色。
 *
 * @param {{x: number, y: number, width: number, height: number, radius: number}} box 卡片的位置、大小与圆角，画面坐标
 */
export function cardEdge({ x, y, width, height, radius }) {
    const half = CARD_EDGE / 2;

    return `<rect x="${x - half}" y="${y - half}" width="${width + CARD_EDGE}" height="${height + CARD_EDGE}" `
        + `rx="${radius + half}" fill="none" stroke="${palette.edge}" stroke-width="${CARD_EDGE}"/>`;
}

/**
 * 截图卡片落在底板上的投影，与贴纸的投影同样的偏移与模糊。
 *
 * @param {{x: number, y: number, width: number, height: number, radius: number}} box 卡片的位置、大小与圆角，画面坐标
 */
export function cardCast({ x, y, width, height, radius }) {
    const shape = `<rect x="${x - CARD_EDGE}" y="${y - CARD_EDGE}" width="${width + CARD_EDGE * 2}" `
        + `height="${height + CARD_EDGE * 2}" rx="${radius + CARD_EDGE}" fill="${palette.cast}"/>`;

    return svgBlurred(stickerId('card-cast'), shape, { dx: 6, dy: 14, blur: 24, opacity: 0.5 });
}

/**
 * 几颗一明一暗的四角星。
 *
 * @param {number} t 当前时间
 * @param {{x: number, y: number, size: number, color: string, period: number, phase: number}[]} stars
 *     每颗星的中心、从中心到角尖的长度与颜色，以及明暗一个来回的秒数与起始相位
 */
export function twinkling(t, stars) {
    return stars.map(({ period, phase, ...star }) => {
        const opacity = 0.62 + 0.38 * sway(t, period, phase);

        return `<g opacity="${opacity}">${starsMarkup([star])}</g>`;
    }).join('');
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
 * 把一段画面整体淡入并略微放大着落定，像一张贴纸贴上去。
 *
 * @param {string} markup 画面
 * @param {number} amount 0 是还没出现，1 是已经落定
 * @param {number[]} pivot 缩放的中心
 * @param {number} [grow] 刚出现时比落定后大出的比例
 */
export function settle(markup, amount, pivot, grow = 0.06) {
    if (amount <= 0) {
        return '';
    }

    if (amount >= 1) {
        return markup;
    }

    const zoom = 1 + grow * (1 - amount);

    return `<g opacity="${amount}" transform="translate(${pivot}) scale(${zoom}) translate(${-pivot[0]} ${-pivot[1]})">`
        + `${markup}</g>`;
}

/**
 * 把一段画面裁在几个矩形合起来的范围里。
 *
 * @param {string} markup 画面
 * @param {...{x: number, y: number, width: number, height: number, radius?: number}} boxes 矩形，画面坐标
 */
export function clipped(markup, ...boxes) {
    const id = stickerId('clip');

    const shapes = boxes.map(({ x, y, width, height, radius = 0 }) => (
        `<rect x="${x}" y="${y}" width="${width}" height="${height}" rx="${radius}"/>`
    )).join('');

    return `<clipPath id="${id}">${shapes}</clipPath><g clip-path="url(#${id})">${markup}</g>`;
}

/**
 * 画面里一条横线以上的全部范围，比画面大一圈。
 *
 * @param {number} y 横线的 y
 * @returns {{x: number, y: number, width: number, height: number}}
 */
export function above(y) {
    return { x: -200, y: -200, width: SCENE.width + 400, height: y + 200 };
}

/**
 * 把绘制脚本拼出的片段放进竖屏画面：蒙版与滤镜的作用范围从图标的大小放大到整幅画面。
 *
 * @param {string} markup 绘制脚本拼出的 SVG 片段
 */
export function widen(markup) {
    return markup.replaceAll(SVG_WIDE, WIDE);
}

// MARK: - Private

/**
 * 几块贴纸染成一种颜色、往外描粗一圈的剪影。
 */
function silhouette(stickers, color, edge) {
    return `<g stroke="${color}" stroke-width="${edge * 2}" stroke-linejoin="round" stroke-linecap="round">`
        + stickers.map((sticker) => sticker.outline(color)).join('')
        + '</g>';
}

/**
 * 一个点绕另一个点转过一个角度之后的位置。
 *
 * @param {number[]} point 要转的点
 * @param {number[]} pivot 转动的中心
 * @param {number} degrees 转过的角度，度；正值在画面上是顺时针
 */
function turned([x, y], [pivotX, pivotY], degrees) {
    const angle = (degrees * Math.PI) / 180;
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);

    return [
        pivotX + (x - pivotX) * cos - (y - pivotY) * sin,
        pivotY + (x - pivotX) * sin + (y - pivotY) * cos,
    ];
}

/**
 * 幽灵自身坐标里的点在画面里的位置。
 *
 * 绘制脚本的脊线每 2 个单位取一个点，这里在相邻两点之间插值：眼睛与小手沿身体移动时才不会一格一格地跳。
 */
function smoothPlace(pose, u, v) {
    const low = Math.floor(v / 2) * 2;
    const [fromX, fromY] = pose.place(u, low);
    const [toX, toY] = pose.place(u, low + 2);
    const amount = (v - low) / 2;

    return [lerp(fromX, toX, amount), lerp(fromY, toY, amount)];
}
