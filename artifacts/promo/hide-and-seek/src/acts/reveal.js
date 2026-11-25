/* global ARMFUL_PURPLES, SVG_WIDE, beamMarkup, starsMarkup, stickerId, svgBlurred, svgLinear, svgMasked */

import { ACTS, BEAT, BEATS, FINALE, cardNamed, shown } from '../plan.js';
import {
    EYES, SCENE, above, arm, cardCast, cardEdge, castOf, clipped, defsOf, edgeOf, faded, ghost, mixEyes, paintOf,
    paw, sceneBox, server, settle,
} from '../stickers.js';
import { blinking, clamp, easeIn, easeInOut, easeOut, easeOutBack, lerp, pulse, span, sway } from '../timing.js';

/*
 * 第四幕 “显形” 与片尾：底下一台服务器往上投出一束光，截图一张张在光里显出来，
 * 幽灵躲在截图后面、每换一张就换个地方探头；片尾幽灵从服务器里升起来，浮在光里。
 *
 * 构图照显形的图标，光束拉长到贯穿整幅竖屏画面。
 */

/** 这一幕开始的时刻；服务器与光束一直留到全片结束。 */
const { start } = ACTS.reveal;

/** 连上服务器的时刻：服务器贴稳之后灭着灯停一下，才看得出指示灯是这一刻亮起来的。 */
const CONNECT = start + 0.6;

/** 服务器：左上角的位置与宽高。 */
const SERVER = { x: 212, y: 1610, width: 600, height: 136 };

/** 光束：底边左右两端的 x、每往上一个单位两侧各放宽的量、底边与顶边的 y。 */
const BEAM = { base: [372, 652], spread: 0.449, bottom: 1630, top: 300 };

/** 光束亮起时，照到的地方往上渐渐淡出的那一段的高度。 */
const BEAM_FRINGE = 280;

/** 光里往上飘的光点的个数。 */
const MOTE_COUNT = 18;

/** 光点飘到这条横线就完全淡出，不进文字那一带：依次是截图上方有大字时、片尾收尾的一句出现后、名字与网址出现后。 */
const MOTE_CEILING = { captions: 430, line: 520, lockup: 900 };

/** 躲在截图后面探头的幽灵：大小，以及探出来时头顶高出截图上沿的量。 */
const PEEK = { scale: 0.62, rise: 205 };

/** 从截图后面整个升起来、举起双手的幽灵：大小，以及升起来时头顶高出截图上沿的量。 */
const RISEN = { scale: 0.8, rise: 380 };

/** 每张截图停留的这一段里，幽灵探出来与缩回去的时刻，从截图出现算起：截图显出来之后才探头，淡出之前缩回去。 */
const PEEK_AT = { up: 0.42, down: BEAT - 0.5 };

/**
 * 每张截图后面幽灵探头的地方：x 是头顶的 x，lean 是脊线的倾角；
 * gaze 是眼神依次的去向，at 是从截图出现算起的时刻，to 是眼睛相对望着前方时挪开的量；
 * paws 为真时两只小手扒着截图的上沿；raised 为真时不探头，而是整个升起来、举起双手。
 */
const VISITS = {
    commit: { x: 672, lean: [-5, -1], gaze: [{ at: 0.8, to: [-18, 15] }], paws: true },
    history: { x: 452, lean: [5, 1], gaze: [{ at: 0.8, to: [14, 16] }], paws: true },
    sync: { x: 512, raised: true },
    conflict: { x: 512, lean: [0, 0], gaze: [{ at: 0.78, to: [-24, 16] }, { at: 1.3, to: [24, 16] }], paws: false },
};

/** 扒着截图上沿的小手：离脊线的距离与所在的高度（幽灵自身坐标），两头的粗细，以及手尖搭到截图上沿以下多少。 */
const GRIP = { u: 190, v: 262, from: 64, to: 50, reach: 36 };

/** 片尾浮在光里的幽灵：大小、头顶的位置与脊线的倾角，照显形的图标。 */
const FLOATING = { scale: 0.8, top: [500, 962], lean: [6, -3] };

/** 片尾幽灵从服务器里升起来的时刻。 */
const EMERGE = ACTS.finale.start + 0.1;

/** 光束里的光点：每颗在光束里的横向位置、飘完全程的秒数、起始的进度、大小与颜色。 */
const MOTES = motes();

/**
 * 这一幕与片尾在 t 时刻的画面；这一幕开始之前返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{backdrop: string, back: string, front: string} | null}
 */
export function paintReveal(t) {
    if (t < start) {
        return null;
    }

    // 服务器像贴纸一样贴上来，这时指示灯灭着；连上的那一刻指示灯亮起，光束同时自下而上亮起。
    const arrive = easeOut(span(t, start, start + 0.35));
    const on = easeOut(span(t, CONNECT, CONNECT + 0.2));
    const lit = easeOut(span(t, CONNECT, CONNECT + 0.65));

    const unit = server({
        ...SERVER,
        slot: { x: SERVER.x + 70, width: 230, height: 26 },
        leds: [SERVER.x + 454, SERVER.x + 508],
        ledRadius: 17,
    }, on * (0.94 + 0.06 * sway(t, 1.8)));

    const visit = visitingGhost(t) ?? emergingGhost(t);
    const spooks = visit ? [visit.spook] : [];

    // 四张截图各自的贴纸边与投影，跟着截图一起淡入淡出。
    const cards = BEATS.map(({ card }) => {
        const found = cardNamed(card);
        const box = sceneBox(found);

        return { opacity: shown(t, found), cast: cardCast(box), edge: cardEdge(box) };
    });

    // 从后往前：全部投影，全部贴纸边，幽灵，服务器。幽灵压在截图的贴纸边上面、服务器的下面。
    const back = defsOf([unit, ...spooks])
        + castOf([unit])
        + cards.map(({ opacity, cast }) => faded(cast, opacity)).join('')
        + (visit ? clipped(castOf(spooks), ...visit.visible) : '')
        + edgeOf([unit])
        + cards.map(({ opacity, edge }) => faded(edge, opacity)).join('')
        + (visit ? clipped(edgeOf(spooks) + paintOf(spooks), ...visit.visible) : '')
        + paintOf([unit]);

    return {
        backdrop: beam(t, lit),
        back: settle(back, arrive, [SCENE.width / 2, SERVER.y + SERVER.height / 2]),
        front: visit?.front ?? '',
    };
}

// MARK: - Private

/**
 * 躲在当前这张截图后面的幽灵；不在任何一张截图的停留时间里，或者还没探出来时返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{spook: object, visible: object[], front: string} | null}
 *     幽灵的贴纸，它看得见的范围（几个矩形合起来），以及压在截图上面的小手
 */
function visitingGhost(t) {
    const beat = BEATS.find(({ start: from }) => t >= from && t < from + BEAT);

    if (!beat) {
        return null;
    }

    const since = t - beat.start;
    const visit = VISITS[beat.card];
    const box = sceneBox(cardNamed(beat.card));

    // 探头时略冲过头再回来。
    const up = easeOutBack(span(since, PEEK_AT.up, PEEK_AT.up + 0.45), 1.5)
        * (1 - easeIn(span(since, PEEK_AT.down, PEEK_AT.down + 0.26)));

    if (up <= 0.001) {
        return null;
    }

    // 截图上沿以上的部分照常画，以下的部分只画在截图身后：幽灵不会从截图的两侧或底下露出来。
    const visible = [above(box.y), { ...box, radius: 0 }];
    const blink = blinking(since, [1.22]);

    if (visit.raised) {
        // 升起来之后举起双手，缩回去之前先放下。
        const raise = easeOutBack(span(since, PEEK_AT.up + 0.32, PEEK_AT.up + 0.72), 2)
            * (1 - easeIn(span(since, PEEK_AT.down - 0.14, PEEK_AT.down + 0.06)));

        const spook = ghost({
            top: [visit.x, box.y + 30 - (RISEN.rise + 30) * up],
            scale: RISEN.scale,
            lean: [0.8 * sway(t, 3.6), 0],
            hands: [arm(-1, raise), arm(1, raise)],
            eyes: EYES.front,
            blink,
        });

        return { spook, visible, front: '' };
    }

    // 眼神从望着前方出发，依次挪向各处，每次用四分之一秒。
    const [du, dv] = visit.gaze.reduce(([u, v], { at, to }) => {
        const amount = easeInOut(span(since, at, at + 0.25));

        return [lerp(u, to[0], amount), lerp(v, to[1], amount)];
    }, [0, 0]);

    const spook = ghost({
        top: [visit.x, box.y - PEEK.rise * up],
        scale: PEEK.scale,
        lean: [visit.lean[0] + 1.2 * sway(t, 3.2), visit.lean[1]],
        eyes: gazing(du, dv),
        blink,
    });

    // 小手搭上截图的上沿，幽灵缩回去之前松开。
    const grip = visit.paws
        ? easeOut(span(since, PEEK_AT.up + 0.3, PEEK_AT.up + 0.5))
            * (1 - easeIn(span(since, PEEK_AT.down - 0.12, PEEK_AT.down + 0.04)))
        : 0;

    return { spook, visible, front: grippingPaws(spook, box, grip) };
}

/**
 * 片尾从服务器里升起来、浮在光里的幽灵；还没到片尾时返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{spook: object, visible: object[], front: string} | null}
 */
function emergingGhost(t) {
    if (t < EMERGE) {
        return null;
    }

    const up = easeOutBack(span(t, EMERGE, EMERGE + 0.95), 0.9);
    const [x, y] = FLOATING.top;

    // 浮在光里轻轻地起伏；名字出来时转过来望着前方。
    const float = up * 9 * sway(t, 3.2);
    const facing = easeInOut(span(t, FINALE.lockup + 0.25, FINALE.lockup + 0.6));

    const spook = ghost({
        top: [x, lerp(SERVER.y + 44, y, up) + float],
        scale: FLOATING.scale,
        lean: [FLOATING.lean[0] * up + 1.2 * sway(t, 4, 0.3), FLOATING.lean[1] * up],
        eyes: mixEyes(EYES.right, EYES.front, facing),
        blink: blinking(t, [EMERGE + 1.5, FINALE.lockup + 0.12, FINALE.lockup + 1.9]),
    });

    // 只画服务器上沿以上的部分：幽灵像是从服务器里升出来的。
    return { spook, visible: [above(SERVER.y)], front: '' };
}

/**
 * 望向一边的眼睛：从望着前方的位置挪开。
 *
 * @param {number} du 往右挪的量，望向左边时为负
 * @param {number} dv 往下挪的量
 */
function gazing(du, dv) {
    return EYES.front.map((eye) => ({
        ...eye,
        u: eye.u + du,
        v: eye.v + dv,

        // 视线那一侧的眼睛离得远，略小一点，像转过了一点头；随视线挪开的量渐变，不会突然变小。
        size: 1 - 0.05 * clamp((du * Math.sign(eye.u)) / 16),
    }));
}

/**
 * 扒着截图上沿的两只小手，连同它们落在截图上的影子；画在截图的上面。
 *
 * @param {object} spook 幽灵的贴纸
 * @param {{x: number, y: number, width: number, height: number, radius: number}} box 截图的位置与大小
 * @param {number} grip 搭上来的程度，0 是还没伸出来，1 是搭稳了
 */
function grippingPaws(spook, box, grip) {
    if (grip <= 0.001) {
        return '';
    }

    const paws = [-1, 1].map((side) => {
        const [x, y] = spook.place(side * GRIP.u, GRIP.v);
        const tip = lerp(box.y - 18, box.y + GRIP.reach, grip);

        return paw([[x, y], [x + side * 2, (y + tip) / 2], [x + side * 4, tip]], GRIP.from, GRIP.to);
    });

    const shade = svgBlurred(
        stickerId('paw-shade'),
        paws.map((hand) => hand.outline('#000000')).join(''),
        { dx: 0, dy: 9, blur: 10, opacity: 0.5 },
    );

    return faded(clipped(shade, box) + paintOf(paws), grip);
}

/**
 * 光束与光里往上飘的光点。
 *
 * @param {number} t 当前时间
 * @param {number} lit 光束亮起来的程度，0 是还没亮，1 是照到了顶
 */
function beam(t, lit) {
    if (lit <= 0) {
        return '';
    }

    const { base, spread, bottom, top } = BEAM;
    const flare = spread * (bottom - top);

    // 每张截图显出来的那一下，光束跟着亮一亮。
    const flash = Math.max(0, ...BEATS.map(({ start: from }) => pulse(t, from - 0.12, from + 0.5)));
    const glow = 0.78 + 0.22 * flash + 0.03 * sway(t, 2.4);

    const cone = beamMarkup({
        base,
        mouth: [base[0] - flare, base[1] + flare],
        bottom,
        top,
    });

    const light = faded(cone, lit * glow) + faded(floatingMotes(t), lit);

    if (lit >= 1) {
        return light;
    }

    // 光束自下而上亮起：照到的地方往上一段渐渐淡出，没有一条生硬的边。
    const reached = lerp(bottom, top - BEAM_FRINGE, lit);
    const fade = stickerId('beam-fade');

    return svgLinear(fade, [0, reached, 0, reached + BEAM_FRINGE], ['#000000', '#FFFFFF'])
        + svgMasked(stickerId('beam-sweep'), `<rect ${SVG_WIDE} fill="url(#${fade})"/>`, light);
}

/**
 * 光里往上飘的光点：小小的四角星，飘到半程最亮，两头淡出。
 *
 * @param {number} t 当前时间
 */
function floatingMotes(t) {
    const { base, spread, bottom, top } = BEAM;
    const middle = (base[0] + base[1]) / 2;
    const waist = (base[1] - base[0]) / 2;

    // 光点飘到文字那一带之前就淡出：片尾的文字占得更靠下，这条线跟着往下挪。
    const ceiling = MOTE_CEILING.captions
        + (MOTE_CEILING.line - MOTE_CEILING.captions) * easeInOut(span(t, FINALE.line - 0.4, FINALE.line))
        + (MOTE_CEILING.lockup - MOTE_CEILING.line) * easeInOut(span(t, FINALE.lockup - 0.3, FINALE.lockup + 0.2));

    return MOTES.map(({ across, life, offset, size, color, period }) => {
        const travelled = ((t - start) / life + offset) % 1;
        const y = lerp(bottom - 30, top + 80, travelled);
        const x = middle + across * (waist + spread * (bottom - y)) * 0.9;

        const opacity = Math.sin(Math.PI * travelled)
            * (0.55 + 0.45 * sway(t, period, offset))
            * clamp((y - ceiling) / 90);

        return opacity > 0 ? `<g opacity="${opacity}">${starsMarkup([{ x, y, size, color }])}</g>` : '';
    }).join('');
}

/**
 * 生成光点：位置与速度由固定的种子算出，每次渲染都一样。
 */
function motes() {
    let seed = 0x5eed;

    const random = () => {
        seed = (seed * 1664525 + 1013904223) % 4294967296;

        return seed / 4294967296;
    };

    return Array.from({ length: MOTE_COUNT }, (_, index) => ({
        across: random() * 2 - 1,
        life: 7 + random() * 6,
        offset: random(),
        size: 5 + random() * 7,
        color: index % 3 ? '#FFFFFF' : ARMFUL_PURPLES[2],
        period: 1.6 + random() * 1.8,
    }));
}
