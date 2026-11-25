/* global GRID, branchSticker, discShape */

import {
    SEAT, boughAt, boughStickers, breeze, movedBough, seatLevel, swung,
} from '../bough.js';
import { lowering, zoom } from '../camera.js';
import { ACTS, BEATS, CARDS, PERCH, shown } from '../plan.js';
import { soaring } from '../sky.js';
import {
    EYES, POSES, TWINKLE, breathing, cardBackings, cherryPair, clusterOf, ghost, mixEyes, mixPose, nudged, zoomed,
} from '../stickers.js';
import {
    blinking, easeInOut, easeInOutSine, easeOut, lerp, pulse, span,
} from '../timing.js';

/*
 * 第二幕 “栖枝”：幽灵从满月上飞下来。镜头顺着它的目光往下转，满月升到高处；接着镜头下降、拉远，
 * 樱桃树从画面下方升进来，幽灵叠在满月的身前。它从满月的左下沿飞出来，朝满月左下方的枝头飞下去，
 * 自上而下轻轻落定，抬眼望见枝梢的一对樱桃，眼睛亮成四角星。
 *
 * 此后四张截图一张张亮出来，每换一张它换一个样子：先停在落下的地方；再离开枝面朝樱桃飘过去，
 * 途中开心得水平转一整圈；落在栖枝图标里的位置；最后从枝上飘起来，凑到樱桃跟前。
 *
 * 这一幕是远景：画面连同夜空一起缩小，栖枝图标里的幽灵与樱桃树落在画面的右下角，截图在它上方，见 camera.js；
 * 满月挂在画面左半边的高处、截图的后面，见 sky.js。
 *
 * 幽灵是飘着的：它不迈步、不跳，换地方就离开枝面平平地飘过去。它也很轻：落上去、停着、飘起来，枝都不动。
 * 树是一整棵，站的枝与挂樱桃的细枝同起同停。
 */

/** 这一幕的起止。 */
const { start, end } = ACTS.perch;

/** 镜头降下去之前，樱桃树在落定位置下方多远：这时整棵树都在画面底边以下。 */
const TREE_AWAY = 1100;

/** 幽灵先后停的两处，头顶的 x：落下的地方，与栖枝图标里的位置。 */
const SPOTS = [-470, POSES.perch.top[0]];

/**
 * 从天上朝枝头飞下来的那一程。
 *
 * across 是横着挪到落点上方的起止时刻，from 是开始往下飞的时刻，落到枝上的时刻是 PERCH.land：
 * 横着先到位，最后一段是自上而下落定。lean 是横着挪的途中身子顺着去向倾的角度，依次是头部与下摆。
 */
const DIVE = {
    across: [start + 0.3, start + 1.2],
    from: start + 0.4,
    lean: [-14, -22],
};

/** 落到枝上之后，抬眼望向樱桃用多久。 */
const NOTICE = 0.2;

/**
 * 从落下的地方飘到栖枝图标里的位置的那一程。
 *
 * from 与 to 是起止的时刻；rise 是离开枝面与落回枝面各用多久，height 是途中离枝面多高；
 * lean 是身子顺着去向倾的角度，依次是头部与下摆：下摆拖在后面。
 * turn 是途中水平转一整圈的起止时刻。
 */
const DRIFT = {
    from: BEATS[1].start,
    to: BEATS[2].start + 0.1,
    rise: 0.7,
    height: 70,
    lean: [8, 13],
    turn: [BEATS[1].start + 0.3, BEATS[1].start + 1.3],
};

/** 从枝上飘起来、凑到樱桃跟前用多久。 */
const LIFT_OFF = 0.55;

/** 停稳的时候星星眼眨一下的时刻：刚落下的地方一次，栖枝图标里的位置一次。 */
const TWINKLES = [BEATS[0].start + 0.9, BEATS[2].start + 1];

/**
 * 这一幕在 t 时刻的画面；不在这一幕里时返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{back: string} | null}
 */
export function paintPerch(t) {
    if (t < start || t >= end) {
        return null;
    }

    // 镜头往下降、同时拉远：整棵树从画面下方升进来，镜头停住时落定。
    const away = [0, TREE_AWAY * (1 - lowering(t))];
    const spook = perchingGhost(t);

    // 站着的枝：幽灵在它上面落一片影子。
    const seat = branchSticker({ ...SEAT, line: nudged(SEAT.line, away), shadows: [spook.outline] });

    // 挂着樱桃的细枝；樱桃只随风轻轻摆。
    const bough = movedBough(boughAt(0), away);
    const wind = breeze(t);
    const near = swung(bough.near, bough.knot, wind.near);
    const far = swung(bough.far, bough.knot, wind.far);

    // 从后往前照图标：站着的枝、细枝与叶子、樱桃的叶子与梗、远处的一颗（近处那颗在它上面落一道短影）、近处的一颗、幽灵。
    const cluster = clusterOf([
        seat,
        ...boughStickers(bough),
        ...cherryPair({
            knot: bough.knot,
            near,
            far,
            turn: bough.turn,
            farShadows: [{ shape: discShape(near), dx: 8, dy: -4, opacity: 0.5 }],
        }),
        spook,
    ]);

    const cards = CARDS.map((card) => ({ card, opacity: shown(t, card) }));

    // 截图的贴纸边与投影按成片的大小画，不跟着镜头缩。
    return { back: cardBackings(cards) + zoomed(cluster, zoom(t)) };
}

// MARK: - Private

/**
 * 从天上飞下来、落定、望见樱桃，再朝樱桃飘过去的幽灵。
 *
 * @param {number} t 当前时间
 */
function perchingGhost(t) {
    // 第二张截图出现时离开枝面，朝樱桃平平地飘过去，落在栖枝图标里的位置：起步与收住都不急。
    const drifted = easeInOutSine(span(t, DRIFT.from, DRIFT.to));

    const aloft = easeInOutSine(span(t, DRIFT.from, DRIFT.from + DRIFT.rise))
        * (1 - easeInOutSine(span(t, DRIFT.to - DRIFT.rise, DRIFT.to)));

    const stood = standingAt(lerp(SPOTS[0], SPOTS[1], drifted));

    // 飘着的时候身子顺着去向倾，下摆拖在后面。
    const drifting = {
        ...stood,
        top: [stood.top[0], stood.top[1] - DRIFT.height * aloft],
        lean: [stood.lean[0] + DRIFT.lean[0] * aloft, stood.lean[1] + DRIFT.lean[1] * aloft],
    };

    // 飞下来之前它还在天上：跟着夜空一起升高，在画面上的位置换算回画面缩小之前的坐标。
    const scale = zoom(t);
    const [skyX, skyY] = POSES.midnight.top;
    const sky = [GRID - (GRID - skyX) / scale, GRID - (GRID - skyY + soaring(t)) / scale];

    // 朝枝头飞下去：横着先挪到落点的上方，最后一段自上而下轻轻落定。
    const across = easeInOut(span(t, ...DIVE.across));
    const down = easeInOut(span(t, DIVE.from, PERCH.land));

    // 横着挪的途中身子朝去向倾：半路倾得最多，挪到落点上方时已经摆正。
    const dive = pulse(t, ...DIVE.across) ** 2;
    const arriving = mixPose(POSES.midnight, drifting, down);

    const diving = {
        ...arriving,
        top: [lerp(sky[0], drifting.top[0], across), lerp(sky[1], drifting.top[1], down)],
        lean: [arriving.lean[0] + DIVE.lean[0] * dive, arriving.lean[1] + DIVE.lean[1] * dive],
    };

    // 第四张截图出现时从枝上飘起来，凑到樱桃跟前。
    const lift = BEATS[3].start;
    const drawn = easeInOut(span(t, lift, lift + LIFT_OFF));

    // 飞下来的途中低头望着脚下的枝，落定后抬眼望向樱桃。
    const gazing = easeInOut(span(t, start, start + 0.3));
    const noticed = easeInOut(span(t, PERCH.land, PERCH.land + NOTICE));

    return ghost({
        pose: breathing(mixPose(diving, POSES.eager, drawn), t),
        eyes: noticed > 0 ? mixEyes(EYES.below, EYES.up, noticed) : mixEyes(EYES.front, EYES.below, gazing),

        // 望见樱桃后闭上眼，再睁开时已是四角星：从小放大着亮出来，略大一圈再收回。
        blink: blinking(t, [PERCH.spark - 0.1]),
        lit: easeOut(span(t, PERCH.spark - 0.03, PERCH.spark + 0.12)),
        flare: 0.45 * pulse(t, PERCH.spark, PERCH.spark + 0.45),
        twinkle: blinking(t, TWINKLES, TWINKLE.length),

        // 飘到半路开心得水平转一整圈：眼睛绕着身体转过去，从另一边转回来。
        spin: 360 * easeInOutSine(span(t, ...DRIFT.turn)),
    });
}

/**
 * 停在枝上某处的姿态：与栖枝图标里一样端正，下摆贴着那里的枝。
 *
 * @param {number} x 头顶的 x；取图标里的位置时就是图标里的姿态
 */
function standingAt(x) {
    const rest = POSES.perch;

    return { ...rest, top: [x, rest.top[1] + seatLevel(x) - seatLevel(rest.top[0])] };
}
