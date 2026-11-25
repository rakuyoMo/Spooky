/* global ARMFUL_MOON, CHERRY_PICK_STARS, GRID, PERCH_MOON, PERCH_STARS, moonMarkup */

import { FAR, closing, tilting, zoom } from './camera.js';
import { ACTS, ARMFUL, DURATION, PERCH, PICK } from './plan.js';
import { twinkling, zoomed } from './stickers.js';
import { easeInOut, lerp, presence, span } from './timing.js';

/*
 * 夜空：一轮紫色的满月与几颗小星，全片都在。
 *
 * 满月的圆心与半径照图标，四组都相同。夜空远在天边：它跟着镜头的远近缩放，镜头往下转时在画面里整片升高。
 * 栖枝一幕的远景里，满月挂在画面左半边的高处：幽灵落下的枝头在它的左下方，樱桃在画面的另一边；截图挡住它的上半。
 * 星星跟着各组图标换位置：枝所在的那一角，那一组的图标里就没有星。
 */

/**
 * 远景里满月的圆心在画面上比图标里的位置高出多少，图标单位。
 *
 * 镜头往下转，夜空整片升高；镜头朝樱桃推近时落回图标里的位置。
 */
const SOAR = 140;

/**
 * 镜头拉远、推近时，夜空里横向不动的那条竖线的 x，图标单位。
 *
 * 樱桃树绕画面的右下角缩放；夜空绕这条线缩放，远景里满月因此留在画面的左半边：
 * 幽灵从它身前飞下去，落在它左下方的枝头。
 */
const PIVOT = 270;

/** 星星淡入与淡出各用多久。 */
const STAR_FADE = 0.7;

/** 从第一帧就在的星星的出现时刻，与留到最后一帧的星星的消失时刻：排在全片开始之前与结束之后。 */
const FIRST = -10;
const LAST = DURATION + 10;

/**
 * 左上的那颗星：全片都在，四组图标里的位置与大小略有不同，换幕时跟着挪过去。
 *
 * 依次是午夜、栖枝、采撷、满怀里的样子；from 与 to 是挪过去的起止时刻，period 与 phase 是明暗一个来回的秒数与起始相位。
 * 栖枝里的一颗比图标里的位置高一点：远景里它在第一张截图的身后，整颗被挡住，不在卡片的底边露出半颗。
 */
const CORNER = {
    period: 2.8,
    phase: 0.1,
    stops: [
        { star: ARMFUL_MOON.stars[0] },
        { star: { ...PERCH_STARS[0], y: PERCH_STARS[0].y - 40 }, from: ACTS.perch.start, to: PERCH.halt },
        { star: CHERRY_PICK_STARS[0], from: ACTS.pick.start, to: PICK.close },
        { star: ARMFUL_MOON.stars[0], from: ARMFUL.snap, to: ARMFUL.hug },
    ],
};

/**
 * 其余的星星：中心、从中心到角尖的长度与颜色照各组图标，另有明暗一个来回的秒数与起始相位，以及在画面上的时段 [from, to]。
 *
 * 右上的一颗与樱桃红的一颗是午夜、满怀两组图标里的，樱桃树进画面之前与樱桃抱进怀里之后才在；
 * 其余两颗分别是栖枝与采撷两组图标里的。栖枝的一颗只在远景里出现：它的位置按夜空在远景里挪开之后落在图标里的地方给出。
 */
const STARS = [
    { ...ARMFUL_MOON.stars[2], period: 3.3, phase: 0.6, spans: [[FIRST, ACTS.perch.start + 0.9], [ARMFUL.hug, LAST]] },
    { ...ARMFUL_MOON.stars[1], period: 3, phase: 0.35, spans: [[FIRST, ACTS.perch.start + 0.9], [ARMFUL.hug, LAST]] },
    {
        ...PERCH_STARS[1],
        x: PERCH_STARS[1].x + runFor(FAR),
        y: PERCH_STARS[1].y + riseFor(SOAR, FAR),
        period: 3.6,
        phase: 0.8,
        spans: [[PERCH.halt, ACTS.pick.start + 0.4]],
    },
    { ...CHERRY_PICK_STARS[1], period: 3.1, phase: 0.2, spans: [[ACTS.pick.start + 0.9, ACTS.armful.start + 0.7]] },
];

/**
 * 夜空在 t 时刻的画面。
 *
 * @param {number} t 当前时间
 * @returns {{sky: string, backdrop: string}} 满月单独占一层：镜头不动的时候，这一层不用重画
 */
export function paintSky(t) {
    // 夜空跟着镜头的远近一起缩放。
    const scale = zoom(t);

    // 镜头往下转时夜空整片升高，朝樱桃推近时落回去；横向绕 PIVOT 那条竖线缩放。
    const run = runFor(scale);
    const rise = riseFor(soaring(t), scale);
    const moved = ({ x, y, ...rest }) => ({ ...rest, x: x - run, y: y - rise });

    const stars = STARS.map(({ spans, ...star }) => moved({
        ...star,
        shown: Math.max(...spans.map(([from, to]) => presence(t, from, to, STAR_FADE, STAR_FADE))),
    }));

    return {
        sky: zoomed(moonMarkup(moved(PERCH_MOON), []), scale),
        backdrop: zoomed(twinkling(t, [moved(cornerStar(t)), ...stars]), scale),
    };
}

/**
 * t 时刻满月的圆心在画面上比图标里的位置高出多少，图标单位。
 *
 * @param {number} t 当前时间
 */
export function soaring(t) {
    return SOAR * tilting(t) * (1 - closing(t));
}

// MARK: - Private

/**
 * 夜空在缩小之前要整片升高多少，缩小之后满月的圆心才正好比图标里的位置高出 lift。
 *
 * 画面绕右下角缩小时，满月跟着往右下角靠；这里把靠过去的那一段一并补上，夜空缩小时不动的就是满月所在的高度。
 *
 * @param {number} lift 满月的圆心在画面上高出的量，图标单位
 * @param {number} scale 画面相对图标的倍数
 */
function riseFor(lift, scale) {
    return (lift + (GRID - PERCH_MOON.y) * (1 - scale)) / scale;
}

/**
 * 夜空在缩小之前要整片往左挪多少，缩小之后横向不动的才是 PIVOT 那条竖线。
 *
 * 画面绕右下角缩小时，夜空跟着往右靠；这里把它拉回来。
 *
 * @param {number} scale 画面相对图标的倍数
 */
function runFor(scale) {
    return ((GRID - PIVOT) * (1 - scale)) / scale;
}

/**
 * 左上的那颗星在 t 时刻的样子。
 *
 * @param {number} t 当前时间
 */
function cornerStar(t) {
    const [{ star: first }, ...rest] = CORNER.stops;

    // 从午夜里的样子起，依次挪到后面各组图标里的位置。
    const { x, y, size } = rest.reduce((star, { star: next, from, to }) => {
        const amount = easeInOut(span(t, from, to));

        return {
            x: lerp(star.x, next.x, amount),
            y: lerp(star.y, next.y, amount),
            size: lerp(star.size, next.size, amount),
        };
    }, first);

    return { x, y, size, color: first.color, period: CORNER.period, phase: CORNER.phase };
}
