/* global ARMFUL_PURPLES */

import { ACTS } from '../plan.js';
import {
    EYES, SCENE, castOf, clipped, defsOf, edgeOf, faded, ghost, mixEyes, paintOf, paw, server, twinkling,
} from '../stickers.js';
import { blinking, easeIn, easeInOut, easeOut, easeOutBack, lerp, lerpEach, span, sway } from '../timing.js';

/*
 * 第一幕 “藏身”：一座机柜立在左边，幽灵从它背后歪着身子探出来，一只小手扒着机柜的边。
 *
 * 构图照藏身的图标；机柜只有三层，每层比图标里的高，三层合起来才遮得住藏在背后的幽灵。
 *
 * 全片的第一帧也是视频的封面：这时幽灵只探出半个身子、望着镜头。它被看见后整个缩回机柜背后，
 * 过一会儿再探出来，这一次才探到图标里的样子。
 */

/** 这一幕的起止。 */
const { start, end } = ACTS.hide;

/** 机柜：左边的 x、每层的宽高、层与层的间距、最上面一层的 y 与层数。 */
const CABINET = { left: 132, width: 340, height: 208, pitch: 222, top: 840, tiers: 3 };

/** 机柜的右沿。 */
const CABINET_RIGHT = CABINET.left + CABINET.width;

/** 每层圆角的半径：绘制脚本里服务器的圆角是层高的 0.23 倍。 */
const CORNER = CABINET.height * 0.23;

/** 幽灵的大小，与图标相同。 */
const GHOST_SCALE = 0.92;

/**
 * 幽灵的三个姿态，各是头顶的位置与脊线的倾角：藏在机柜背后；开场时只探出半个身子；再探出来之后，也就是图标里的样子。
 *
 * 开场的姿态里，头探到中线压着机柜右沿的地方，只露一只眼睛；身子比图标里更歪，下摆大半留在机柜背后。
 */
const HIDDEN = { top: [120, 866], lean: [0, 0] };
const GLIMPSE = { top: [550, 866], lean: [22, 9] };
const OUT = { top: [720, 860], lean: [20, 3] };

/**
 * 幽灵只画在这条竖线以右：藏在机柜背后的身子不会从机柜的另一侧露出来。
 *
 * 线在机柜右沿往里一个圆角的地方。这里各层的边是直的，机柜连同贴纸边从上到下没有缺口，
 * 幽灵被裁开的那条边始终压在机柜底下。
 */
const GHOST_LEFT = CABINET_RIGHT - CORNER;

/**
 * 扒着机柜的小手：中线经过的点与两头的粗细，fade 是从根部淡入到手尖的两个 x；
 * slide 是它还没伸出来时往右缩回去的距离。
 */
const PAW = { line: [[548, 1161], [478, 1181], [436, 1179]], from: 104, to: 80, fade: [580, 470], slide: 124 };

/** 几个时刻：开场探出半个身子的幽灵缩回去；小手搭上来，幽灵再探出来，回头望向机柜，缩回去。 */
const AT = {
    duck: start + 0.85,
    paw: start + 1.75,
    peek: start + 2.15,
    look: start + 3.9,
    leave: start + 4.85,
};

/** 这一幕的星星。 */
const STARS = [
    { x: 900, y: 806, size: 24, color: ARMFUL_PURPLES[2], period: 2.6, phase: 0 },
    { x: 566, y: 742, size: 16, color: ARMFUL_PURPLES[1], period: 3.4, phase: 0.4 },
    { x: 948, y: 1560, size: 14, color: ARMFUL_PURPLES[1], period: 3, phase: 0.7 },
    { x: 60, y: 690, size: 12, color: ARMFUL_PURPLES[2], period: 3.8, phase: 0.2 },
];

/**
 * 这一幕在 t 时刻的画面；不在这一幕里时返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{backdrop: string, back: string, front: string} | null}
 */
export function paintHide(t) {
    if (t < start || t >= end) {
        return null;
    }

    // 机柜从第一帧就在，这一幕结束时与文字一起淡出。
    const scenery = 1 - span(t, end - 0.22, end);

    // 幽灵两次探出来的程度。开场时已经探出半个身子，被看见后很快整个缩回去；
    // 再探出来时略冲过头再回来，最后回去时先慢后快。两段在时间上不重叠。
    const caught = 1 - easeIn(span(t, AT.duck, AT.duck + 0.3));

    const again = easeOutBack(span(t, AT.peek, AT.peek + 0.7), 1.3)
        * (1 - easeIn(span(t, AT.leave, AT.leave + 0.4)));

    // 小手：幽灵再探出来之前先搭上机柜的边，幽灵缩回去之后才松开。
    const grip = easeOut(span(t, AT.paw, AT.paw + 0.3))
        * (1 - easeIn(span(t, AT.leave + 0.25, AT.leave + 0.5)));

    // 开场探到半个身子的姿态，再探出来时探到图标里的姿态。
    const spook = t < AT.paw ? hidingGhost(t, GLIMPSE, caught) : hidingGhost(t, OUT, again);
    const hand = grippingPaw(grip);

    const cabinet = Array.from({ length: CABINET.tiers }, (_, index) => server({
        x: CABINET.left,
        y: CABINET.top + index * CABINET.pitch,
        width: CABINET.width,
        height: CABINET.height,
        slot: { x: CABINET.left + 36, width: 96, height: 26 },
        leds: [CABINET.left + 172, CABINET.left + 220],
        ledRadius: 17,
        shadows: [{ shape: hand.outline, dx: -4, dy: 10, opacity: 0.6 * grip }],
    }));

    // 幽灵的投影、贴纸边与成品都裁在 GHOST_LEFT 以右；小手只在机柜上与探出来的身体上才看得见。
    const behind = { x: GHOST_LEFT, y: -200, width: SCENE.width + 400, height: SCENE.height + 400 };

    // 机柜右沿以左，机柜的贴纸边再压到幽灵上面：幽灵的身子与眼睛不会从层与层的缝里露出来。
    const within = { x: -200, y: -200, width: 200 + CABINET_RIGHT, height: SCENE.height + 400 };

    const reach = {
        x: -200,
        y: -200,
        width: 200 + CABINET_RIGHT + lerp(20, 130, again),
        height: SCENE.height + 400,
    };

    const back = defsOf([spook, ...cabinet, hand])
        + castOf(cabinet)
        + clipped(castOf([spook]), behind)
        + edgeOf(cabinet)
        + clipped(edgeOf([spook]) + paintOf([spook]), behind)
        + clipped(edgeOf(cabinet), within)
        + paintOf(cabinet)
        + clipped(faded(paintOf([hand]), grip), reach);

    return {
        backdrop: faded(twinkling(t, STARS), scenery),
        back: faded(back, scenery),
        front: '',
    };
}

// MARK: - Private

/**
 * 从机柜背后探出来的幽灵。
 *
 * @param {number} t 当前时间
 * @param {{top: number[], lean: number[]}} pose 探出来之后的姿态
 * @param {number} out 探出来的程度，0 是藏着，1 是到了 pose
 */
function hidingGhost(t, pose, out) {
    const [x, y] = lerpEach(HIDDEN.top, pose.top, out);
    const [head, hem] = lerpEach(HIDDEN.lean, pose.lean, out);

    // 探在外面时轻轻地浮动；望着前方，开场被看见时眨一下眼，再探出来之后过一会儿回头望向机柜。
    const float = out * 5 * sway(t, 2.8);
    const nod = out * 1.2 * sway(t, 3.6, 0.25);
    const look = easeInOut(span(t, AT.look, AT.look + 0.35));

    return ghost({
        top: [x, y + float],
        scale: GHOST_SCALE,
        lean: [head + nod, hem],
        eyes: mixEyes(EYES.front, EYES.back, look),
        blink: blinking(t, [AT.duck - 0.1, AT.peek + 0.95, AT.look + 0.55]),
    });
}

/**
 * 扒着机柜的小手。
 *
 * @param {number} grip 搭上来的程度，0 是还缩在机柜的边外，1 是图标里的位置
 */
function grippingPaw(grip) {
    const shift = PAW.slide * (1 - grip);
    const [fadeFrom, fadeTo] = PAW.fade;

    return paw(
        PAW.line.map(([x, y]) => [x + shift, y]),
        PAW.from,
        PAW.to,
        [fadeFrom + shift, 0, fadeTo + shift, 0],
    );
}
