import { ACTS, PERCH, PICK } from './plan.js';
import { easeInOut, lerp, span } from './timing.js';

/*
 * 镜头的俯仰与远近：全片只有栖枝一幕是远景。
 *
 * 栖枝一幕开头，镜头先顺着幽灵的目光往下转，夜空在画面里升高；接着一边下降一边拉远，
 * 夜空、幽灵与樱桃树一起缩小，樱桃树从画面下方升进来，上方让给截图。采撷一幕开头再朝樱桃推近，夜空落回原处。
 * 镜头拉远、推近时，画面的右下角不动：远景里，栖枝图标里的幽灵与樱桃树落在画面的右下角；
 * 夜空缩放时不动的是满月所在的高度与画面左半边的一条竖线，远景里满月留在画面的左半边，见 sky.js。
 */

/** 远景里画面相对图标的倍数。 */
export const FAR = 0.54;

/** 栖枝一幕开头，镜头往下转用多久：比下降、拉远先到位。 */
const TILT = 0.6;

/**
 * 栖枝一幕开头镜头往下转的程度：0 是午夜里的样子，1 是转到位，夜空升到远景里的高度。
 *
 * @param {number} t 当前时间
 */
export const tilting = (t) => easeInOut(span(t, ACTS.perch.start, ACTS.perch.start + TILT));

/**
 * 栖枝一幕开头镜头降下去、拉远的程度：0 是午夜里的样子，1 是镜头停住、整棵树落定。
 *
 * @param {number} t 当前时间
 */
export const lowering = (t) => easeInOut(span(t, ACTS.perch.start, PERCH.halt));

/**
 * 采撷一幕开头镜头朝樱桃推近的程度：0 是栖枝一幕末尾的样子，1 是采撷里的样子。
 *
 * @param {number} t 当前时间
 */
export const closing = (t) => easeInOut(span(t, ACTS.pick.start, PICK.close));

/**
 * t 时刻画面相对图标的倍数：1 是图标的 1024 网格铺满成片的宽。
 *
 * @param {number} t 当前时间
 */
export const zoom = (t) => lerp(lerp(1, FAR, lowering(t)), 1, closing(t));
