/* global ARMFUL_PURPLES, branchMarkSticker */

import { ACTS } from '../plan.js';
import {
    EYES, SCENE, above, arm, castOf, clipped, defsOf, edgeOf, faded, ghost, paintOf, server, settle, twinkling,
} from '../stickers.js';
import { blinking, easeIn, easeInOut, easeOut, easeOutBack, lerp, span, sway } from '../timing.js';

/*
 * 第二幕 “探身”：幽灵正面从两层的机架后升起来，举起两只小手；机架上有分支符号。
 *
 * 构图照探身的图标，也就是默认的应用图标。
 */

/** 这一幕的起止。 */
const { start, end } = ACTS.rise;

/** 机架：左边的 x、每层的宽高与两层各自的 y。 */
const RACK = { left: 172, width: 680, height: 150, tops: [1290, 1454] };

/** 幽灵的大小，与图标相同。 */
const GHOST_SCALE = 0.95;

/** 幽灵头顶的 x，以及藏在机架后面与升起来之后头顶的 y。 */
const GHOST = { x: 512, hidden: RACK.tops[0] + 36, risen: RACK.tops[0] - 406 };

/**
 * 幽灵看得见的范围：机架上沿以上，加上机架左右两侧；机架背后的身子与眼睛，不会从两层之间的缝里或机架底下露出来，
 * 举到机架两侧的小手也不会被上沿那条线切平。
 */
const GHOST_VISIBLE = [
    above(RACK.tops[0]),
    { x: -200, y: -200, width: 200 + RACK.left, height: SCENE.height + 400 },
    { x: RACK.left + RACK.width, y: -200, width: SCENE.width, height: SCENE.height + 400 },
];

/** 几个时刻：机架贴上来，幽灵升起来，举手，挥手，沉回去。 */
const AT = {
    rack: start,
    rise: start + 0.45,
    arms: start + 0.8,
    wave: start + 1.6,
    leave: start + 4.3,
};

/**
 * 挥手，挥的是画面右边的一只。
 *
 * shoulder 与 elbow 是上臂与前臂来回摆的幅度，度；lag 是前臂比上臂慢的秒数，肘部先动、手跟在后面；
 * period 是摆一个来回的秒数，turns 是来回的次数；
 * tilt 是挥手时头往另一侧歪的角度，rock 是身子跟着手晃的角度，hop 是身子往上提的距离；
 * rest 是另一只手放低之后还举着的程度。
 */
const WAVE = {
    shoulder: 5,
    elbow: 15,
    lag: 0.06,
    period: 0.46,
    turns: 2.5,
    tilt: -1.8,
    rock: 0.7,
    hop: 5,
    rest: 0.9,
};

/** 这一幕的星星。 */
const STARS = [
    { x: 130, y: 904, size: 28, color: ARMFUL_PURPLES[2], period: 2.8, phase: 0.1 },
    { x: 900, y: 884, size: 18, color: ARMFUL_PURPLES[1], period: 3.3, phase: 0.6 },
    { x: 80, y: 1560, size: 13, color: ARMFUL_PURPLES[1], period: 3.7, phase: 0.3 },
    { x: 962, y: 1684, size: 15, color: ARMFUL_PURPLES[2], period: 3, phase: 0.8 },
];

/**
 * 这一幕在 t 时刻的画面；不在这一幕里时返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{backdrop: string, back: string, front: string} | null}
 */
export function paintRise(t) {
    if (t < start || t >= end) {
        return null;
    }

    // 机架像贴纸一样贴上来，这一幕结束时淡出。
    const arrive = easeOut(span(t, AT.rack, AT.rack + 0.35));
    const depart = 1 - span(t, end - 0.2, end);

    const spook = risingGhost(t);
    const rack = rackStickers();

    const back = defsOf([spook, ...rack])
        + castOf(rack)
        + clipped(castOf([spook]), ...GHOST_VISIBLE)
        + edgeOf(rack)
        + clipped(edgeOf([spook]) + paintOf([spook]), ...GHOST_VISIBLE)
        + paintOf(rack);

    const pivot = [SCENE.width / 2, RACK.tops[1]];

    return {
        backdrop: faded(twinkling(t, STARS), arrive * depart),
        back: faded(settle(back, arrive, pivot), depart),
        front: '',
    };
}

// MARK: - Private

/**
 * 从机架后面升起来的幽灵。
 *
 * @param {number} t 当前时间
 */
function risingGhost(t) {
    // 升起来时略冲过头再回来，沉回去时先慢后快。
    const up = easeOutBack(span(t, AT.rise, AT.rise + 0.65), 1.4)
        * (1 - easeIn(span(t, AT.leave, AT.leave + 0.4)));

    const raise = easeOutBack(span(t, AT.arms, AT.arms + 0.45), 2)
        * (1 - easeIn(span(t, AT.leave - 0.15, AT.leave + 0.2)));

    // 升起来之后轻轻地浮动。
    const float = up * 6 * sway(t, 3);

    // 挥手：右手伸长了举高、来回摆，另一只手放低一点；头往另一侧歪一点，身子慢半拍跟着手晃。
    const since = t - AT.wave;
    const poised = wavePoise(since);

    const waving = {
        reach: poised,
        shoulder: WAVE.shoulder * waveSwing(since),
        elbow: WAVE.elbow * waveSwing(since - WAVE.lag),
    };

    const tilt = WAVE.tilt * poised + WAVE.rock * waveSwing(since - WAVE.lag * 2);

    return ghost({
        top: [GHOST.x, lerp(GHOST.hidden, GHOST.risen, up) + float - WAVE.hop * poised],
        scale: GHOST_SCALE,
        lean: [0.8 * sway(t, 3.8, 0.2) * up + tilt, 0],
        hands: [arm(-1, raise * lerp(1, WAVE.rest, poised)), arm(1, raise, waving)],
        eyes: EYES.front,
        blink: blinking(t, [AT.wave - 0.1, AT.wave + 1.95, AT.leave - 0.5]),
    });
}

/**
 * 两层的机架与画在上面的分支符号：主干竖贯两台服务器，支线从右上方汇入。
 */
function rackStickers() {
    const [upper, lower] = RACK.tops;
    const trunk = RACK.left + 104;
    const twig = RACK.left + 212;

    const units = RACK.tops.map((top) => server({
        x: RACK.left,
        y: top,
        width: RACK.width,
        height: RACK.height,
        slot: { x: RACK.left + 304, width: 210, height: 26 },
        leds: [RACK.left + 572, RACK.left + 622],
        ledRadius: 17,
    }));

    const mark = branchMarkSticker({
        trunk: [[trunk, upper + 75], [trunk, lower + 75]],
        twig: [[twig, upper + 75], [twig, upper + 142], [trunk, upper + 118], [trunk, lower + 44]],
        nodes: [[trunk, upper + 75], [trunk, lower + 75], [twig, upper + 75]],
    });

    return [...units, mark];
}

/**
 * 摆出挥手姿势的程度：先把手伸长了举高，摆完再放回举着的姿势。
 *
 * @param {number} since 从开始挥手算起的秒数
 * @returns {number} 0 是举着的姿势，1 是挥手的姿势
 */
function wavePoise(since) {
    const swinging = WAVE.period * WAVE.turns;

    return easeInOut(span(since, 0, 0.3))
        * (1 - easeInOut(span(since, 0.1 + swinging, 0.5 + swinging)));
}

/**
 * 挥手时摆到哪儿：手举到一半就开始摆，头一下往头那一侧，最后一下收小。
 *
 * @param {number} since 从开始挥手算起的秒数
 * @returns {number} −1 是摆到头那一侧的尽头，1 是摆到外侧的尽头
 */
function waveSwing(since) {
    const swinging = WAVE.period * WAVE.turns;
    const elapsed = since - 0.15;

    if (elapsed <= 0 || elapsed >= swinging) {
        return 0;
    }

    const strength = easeOut(span(elapsed, 0, 0.15))
        * (1 - easeInOut(span(elapsed, swinging - 0.35, swinging)));

    return -Math.sin((2 * Math.PI * elapsed) / WAVE.period) * strength;
}
