/* global CHERRY_PICK_HAND, GRID, branchSticker, discShape, starsMarkup, taperData */

import {
    SEAT, boughAt, boughStickers, breeze, pushedIn, swung,
} from '../bough.js';
import { closing, zoom } from '../camera.js';
import { ACTS, PICK } from '../plan.js';
import {
    EYES, POSES, TWINKLE, breathing, cherryPair, clusterOf, faded, ghost, mixEyes, mixPose, zoomed,
} from '../stickers.js';
import {
    blinking, clamp, easeOut, easeOutBack, lerp, lerpEach, pulse, ringing, span,
} from '../timing.js';

/*
 * 第三幕 “采撷”：镜头从远景朝樱桃推近，站过的枝退出画面，幽灵已经凑在樱桃跟前；它抬起一只短手，搭在近处那颗樱桃上。
 *
 * 构图照采撷的图标；标题在图标的方格上方。
 */

/** 这一幕的起止。 */
const { start, end } = ACTS.pick;

/** 镜头推近的途中，幽灵往上浮起的高度。 */
const LIFT = 40;

/** 小手还缩在身体里时，肘部与手尖在幽灵自身坐标里的位置。 */
const TUCKED = [[176, 452], [198, 462]];

/** 小手搭上樱桃的那一下，手尖与樱桃一起挪开的量。 */
const PAT = [7, -9];

/**
 * 小手搭上去的那一下，远处那颗樱桃荡开的幅度（度）、一个来回的秒数与衰减。
 *
 * 这一幕结束之前它必须已经停住：满怀一幕从停住的样子接着走。
 */
const NUDGE = { degrees: 6.5, period: 0.6, decay: 8 };

/** 小手搭上去的那一下，樱桃旁冒出的一颗小星：相对近处那颗樱桃的位置、往上飘的距离与最大的时候从中心到角尖的长度。 */
const SPARK = { offset: [88, -84], drift: 34, size: 24 };

/** 抬手的时刻。 */
const REACH = PICK.touch - 0.48;

/**
 * 这一幕在 t 时刻的画面；不在这一幕里时返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{back: string} | null}
 */
export function paintPick(t) {
    if (t < start || t >= end) {
        return null;
    }

    const closeness = closing(t);
    const pat = pulse(t, PICK.touch - 0.03, PICK.touch + 0.3);
    const { spook, hand, reach } = reachingGhost(t, closeness, pat);

    // 手搭上去之后，近处那颗跟着手走，不再随风摆；远处那颗被这一下带得荡开一点。
    const bough = boughAt(closeness);
    const wind = breeze(t);
    const loose = swung(bough.near, bough.knot, wind.near * (1 - clamp(reach)));
    const near = { ...loose, x: loose.x + PAT[0] * pat, y: loose.y + PAT[1] * pat };
    const nudge = NUDGE.degrees * ringing(t, PICK.touch + 0.06, NUDGE.period, NUDGE.decay);
    const far = swung(bough.far, bough.knot, wind.far + nudge);

    const handShape = (fill) => `<path d="${taperData(hand.line, hand.from, hand.to)}" fill="${fill}"/>`;

    // 从后往前照图标：枝与叶子、樱桃的叶子与梗、远处的一颗、近处的一颗（上面有手压出的短影）、幽灵；
    // 站过的枝退出画面之前垫在最后面。
    const cluster = [
        ...leavingSeat(closeness, spook),
        ...boughStickers(bough),
        ...cherryPair({
            knot: bough.knot,
            near,
            far,
            turn: bough.turn,
            nearShadows: [{ shape: handShape, dx: 6, dy: -6, opacity: 0.55 * clamp(reach) }],
            farShadows: [{ shape: discShape(near), dx: 8, dy: -4, opacity: 0.5 * (1 - closeness) }],
        }),
        spook,
    ];

    // 镜头从远景推到图标的大小：贴纸边与投影跟着画面一起放大。
    return { back: zoomed(clusterOf(cluster) + spark(t, near), zoom(t)) };
}

// MARK: - Private

/**
 * 凑在樱桃跟前、抬手搭在樱桃上的幽灵。
 *
 * @param {number} t 当前时间
 * @param {number} closeness 镜头推近的程度，0 是栖枝一幕末尾的样子，1 是采撷里的样子
 * @param {number} pat 小手搭上去那一下按下的程度
 * @returns {{spook: object, hand: {line: number[][], from: number, to: number}, reach: number}}
 *     幽灵的贴纸、搭在樱桃上的那只手，以及手伸出去的程度
 */
function reachingGhost(t, closeness, pat) {
    // 镜头推近的途中往上浮起一点。
    const mixed = mixPose(POSES.eager, POSES.pick, closeness);
    const top = [mixed.top[0], mixed.top[1] - LIFT * Math.sin(Math.PI * closeness)];
    const pose = breathing({ ...mixed, top }, t);

    // 抬手：从缩在身体里的样子伸到图标里的位置，略冲过头再回来；根部跟着身体，手尖留在樱桃上。
    const reach = easeOutBack(span(t, REACH, PICK.touch), 1.4);
    const thickness = lerp(0.5, 1, clamp(reach));

    const hand = {
        line: [
            pose.place(...CHERRY_PICK_HAND.root),
            ...CHERRY_PICK_HAND.reach.map((point, index) => {
                const [x, y] = lerpEach(pose.place(...TUCKED[index]), point, reach);

                // 按下去时手尖挪得最多，肘部只跟着挪一半。
                const share = (index + 1) / CHERRY_PICK_HAND.reach.length;

                return [x + PAT[0] * pat * share, y + PAT[1] * pat * share];
            }),
        ],
        from: CHERRY_PICK_HAND.from * thickness,
        to: CHERRY_PICK_HAND.to * thickness,
    };

    const spook = ghost({
        pose,
        hands: [hand],
        eyes: mixEyes(EYES.up, EYES.right, closeness),
        lit: 1,

        // 小手搭上樱桃的那一下，星星眼眨一下。
        twinkle: blinking(t, [PICK.touch], TWINKLE.length),
    });

    return { spook, hand, reach };
}

/**
 * 镜头推近时跟着放大、往下退出画面的那根站过的枝；整根退到画面底边以下之后不再画。
 *
 * @param {number} closeness 镜头推近的程度
 * @param {object} spook 幽灵的贴纸，在枝上落一片影子
 * @returns {object[]} 一块贴纸，或者没有
 */
function leavingSeat(closeness, spook) {
    const seat = pushedIn(SEAT, closeness);
    const reach = Math.max(seat.from, seat.to);

    // 连同贴纸边与投影都出了画面才算退出去。
    if (seat.line.every(([, y]) => y - reach > GRID)) {
        return [];
    }

    return [branchSticker({ ...seat, shadows: [spook.outline] })];
}

/**
 * 小手搭上去的那一下，樱桃旁冒出的一颗小星：往上飘着变大又变小。
 *
 * @param {number} t 当前时间
 * @param {{x: number, y: number}} near 近处的樱桃
 */
function spark(t, near) {
    const life = span(t, PICK.touch, PICK.touch + 0.6);

    if (life <= 0 || life >= 1) {
        return '';
    }

    const swell = Math.sin(Math.PI * life);

    return faded(starsMarkup([{
        x: near.x + SPARK.offset[0],
        y: near.y + SPARK.offset[1] - SPARK.drift * easeOut(life),
        size: SPARK.size * swell,
        color: '#FFFFFF',
    }]), swell);
}
