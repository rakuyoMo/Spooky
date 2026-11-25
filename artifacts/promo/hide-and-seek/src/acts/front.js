/* global ARMFUL_PURPLES */

import { ACTS, FRONT, cardNamed, shown } from '../plan.js';
import {
    EYES, SCENE, cardCast, cardEdge, castOf, defsOf, edgeOf, faded, ghost, paintOf, sceneBox, server, settle, twinkling,
} from '../stickers.js';
import { blinking, easeIn, easeInOut, easeOut, easeOutBack, lerp, lerpEach, pulse, span, sway } from '../timing.js';

/*
 * 第三幕 “身前”：三层的机架整面立在后面，幽灵侧身浮在它前面，一只小手抬向右边的指示灯，指示灯随之亮起。
 *
 * 构图照身前的图标；机架上方先后是添加服务器仓库的对话框与连接状态。
 */

/** 这一幕的起止。 */
const { start, end } = ACTS.front;

/** 机架：左边的 x、每层的宽高与三层各自的 y。 */
const RACK = { left: 132, width: 760, height: 196, tops: [1090, 1300, 1510] };

/** 幽灵的大小，与图标相同。 */
const GHOST_SCALE = 0.9;

/** 幽灵刚从左边飘进来时与停在机架前面时的姿态：头顶的位置与脊线的倾角。 */
const ENTERING = { top: [-340, 1206], lean: [19, 6] };
const FLOATING = { top: [424, 1164], lean: [7, 2] };

/** 幽灵沉出画面时往下走的距离。 */
const SINK = 800;

/**
 * 抬向指示灯的小手，在幽灵自身坐标里：tucked 是缩在身体里的样子，lifted 是抬起来的样子，
 * from 与 to 是两头的粗细；tap 是点一下时手尖多伸出去的量。
 */
const HAND = {
    tucked: [[150, 440], [176, 452], [198, 462]],
    lifted: [[196, 430], [300, 412], [356, 356]],
    from: 128.9,
    to: 84.4,
    tap: [20, -16],
};

/** 抬眼看对话框时，眼睛在幽灵自身坐标里往上挪的量。 */
const GLANCE = 22;

/** 几个时刻：机架贴上来，幽灵飘进来，抬眼看对话框，把目光收回到指示灯上，抬手，沉下去。 */
const AT = {
    rack: start,
    enter: start + 0.3,
    glance: FRONT.dialog + 0.3,
    focus: FRONT.connect - 1.05,
    lift: FRONT.connect - 0.6,
    leave: end - 0.62,
};

/** 这一幕的星星。 */
const STARS = [
    { x: 950, y: 1010, size: 16, color: ARMFUL_PURPLES[1], period: 3.2, phase: 0.5 },
    { x: 66, y: 1040, size: 13, color: ARMFUL_PURPLES[2], period: 2.7, phase: 0.1 },
];

/**
 * 这一幕在 t 时刻的画面；不在这一幕里时返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{backdrop: string, back: string, front: string} | null}
 */
export function paintFront(t) {
    if (t < start || t >= end) {
        return null;
    }

    // 机架像贴纸一样贴上来，这一幕结束时淡出。
    const arrive = easeOut(span(t, AT.rack, AT.rack + 0.35));
    const depart = 1 - span(t, end - 0.2, end);

    const spook = floatingGhost(t);

    // 指示灯自上而下一层层亮起来，亮着之后微微地呼吸。
    const rack = RACK.tops.map((top, index) => {
        const on = easeOut(span(t, FRONT.connect + index * 0.13, FRONT.connect + index * 0.13 + 0.2));
        const breath = 0.94 + 0.06 * sway(t, 1.8, index * 0.2);

        return server({
            x: RACK.left,
            y: top,
            width: RACK.width,
            height: RACK.height,

            // 三台都有盘位槽，下面两台的槽等幽灵飘到机架前面才被挡住。
            // 图标画的是幽灵停下之后的样子，那里只画了最上面一台的槽。
            slot: { x: RACK.left + 88.67, width: 400, height: 37.47 },
            leds: [RACK.left + 608, RACK.left + 672],
            ledRadius: 21,
            shadows: [{ shape: spook.outline, dx: 10, dy: 16, opacity: 0.6 }],
        }, on * breath);
    });

    // 机架上方的两张卡片：各自的贴纸边与投影跟着卡片一起淡入淡出。
    const cards = ['add-server', 'connected'].map((id) => {
        const card = cardNamed(id);
        const box = sceneBox(card);

        return { opacity: shown(t, card), cast: cardCast(box), edge: cardEdge(box) };
    });

    const cluster = [...rack, spook];

    const scenery = defsOf(cluster)
        + castOf(cluster)
        + edgeOf(cluster)
        + paintOf(rack)
        + paintOf([spook]);

    const pivot = [SCENE.width / 2, RACK.tops[1] + RACK.height / 2];

    const back = cards.map(({ opacity, cast }) => faded(cast, opacity)).join('')
        + cards.map(({ opacity, edge }) => faded(edge, opacity)).join('')
        + faded(settle(scenery, arrive, pivot), depart);

    return {
        backdrop: faded(twinkling(t, STARS), arrive * depart),
        back,
        front: '',
    };
}

// MARK: - Private

/**
 * 浮在机架前面的幽灵。
 *
 * @param {number} t 当前时间
 */
function floatingGhost(t) {
    // 从左边飘进来，先快后慢；离开时往下沉出画面。
    const arrived = easeOut(span(t, AT.enter, AT.enter + 0.8));
    const sunk = easeIn(span(t, AT.leave, AT.leave + 0.45));

    const [x, y] = lerpEach(ENTERING.top, FLOATING.top, arrived);
    const [head, hem] = lerpEach(ENTERING.lean, FLOATING.lean, arrived);

    // 停稳之后轻轻地浮动。
    const float = arrived * 6 * sway(t, 3.1);
    const nod = arrived * 1.1 * sway(t, 3.9, 0.3);

    // 抬手：略冲过头再回来；指示灯亮起的那一下，手尖往前点一点。
    const lift = easeOutBack(span(t, AT.lift, AT.lift + 0.42), 1.8) * (1 - sunk);
    const tap = pulse(t, FRONT.connect - 0.08, FRONT.connect + 0.26);

    const hand = {
        points: HAND.tucked.map((tucked, index) => {
            const [u, v] = lerpEach(tucked, HAND.lifted[index], lift);
            const reach = (tap * index) / 2;

            return [u + HAND.tap[0] * reach, v + HAND.tap[1] * reach];
        }),
        from: HAND.from * lerp(0.5, 1, lift),
        to: HAND.to * lerp(0.5, 1, lift),
    };

    // 对话框出现后抬眼看它，抬手之前把目光收回到指示灯上。
    const glance = easeInOut(span(t, AT.glance, AT.glance + 0.3))
        * (1 - easeInOut(span(t, AT.focus, AT.focus + 0.3)));

    return ghost({
        top: [x, y + float + SINK * sunk],
        scale: GHOST_SCALE,
        lean: [head + nod, hem],
        hands: [hand],
        eyes: EYES.right.map((eye) => ({ ...eye, v: eye.v - GLANCE * glance })),
        blink: blinking(t, [AT.glance - 0.05, FRONT.connect + 0.75, FRONT.connect + 2.4]),
    });
}
