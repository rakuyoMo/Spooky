import { ACTS, MIDNIGHT } from '../plan.js';
import { EYES, POSES, breathing, clusterOf, ghost, mixEyes } from '../stickers.js';
import { blinking, easeInOut, span } from '../timing.js';

/*
 * 第一幕 “午夜”：满月挂在天上，一只大幽灵从左下角探到镜头跟前，挡住满月的左下。
 *
 * 构图照午夜的图标：图标里幽灵被底板的左边与下边裁切，成片里裁它的是画面的左边与下边。
 *
 * 全片的第一帧也是视频的封面：这时幽灵望着镜头。它抬眼望向右上的满月，就是图标里的样子，眨一下眼；
 * 名字出现时转过来望着镜头，再眨一下眼，这一幕就结束。
 */

/** 这一幕的起止。 */
const { start, end } = ACTS.midnight;

/**
 * 开场画面静止多久之后才开始轻轻浮动。
 *
 * 平台取第一帧还是稍后的一帧作封面，拿到的都是同一幅画面。
 */
const STILL = 0.7;

/** 几个时刻：抬眼望向满月，两次眨眼，转过来望着镜头。 */
const AT = {
    moon: start + STILL,
    blinks: [start + 1.35, MIDNIGHT.name + 1.6],
    camera: MIDNIGHT.name + 0.2,
};

/**
 * 这一幕在 t 时刻的画面；不在这一幕里时返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{back: string} | null}
 */
export function paintMidnight(t) {
    if (t < start || t >= end) {
        return null;
    }

    // 开场先停着不动，再慢慢浮动起来。
    const calm = easeInOut(span(t, start + STILL, start + STILL + 1));
    const rest = POSES.midnight;

    // 目光先后落在镜头、满月、镜头：从望着镜头的样子挪过去，再挪回来。
    const moon = easeInOut(span(t, AT.moon, AT.moon + 0.3)) * (1 - easeInOut(span(t, AT.camera, AT.camera + 0.3)));

    const spook = ghost({
        pose: breathing({ ...rest, float: rest.float * calm, nod: rest.nod * calm }, t),
        eyes: mixEyes(EYES.front, EYES.up, moon),
        blink: blinking(t, AT.blinks),
    });

    return { back: clusterOf([spook]) };
}
