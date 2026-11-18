/**
 * 午夜：炭黑底板上一轮紫色满月与三颗小星，一只白色的大幽灵从左边探身进来、被底板的左边与下边裁切，望向画面里。
 * 画法照满怀，见 sticker.js。App 连着服务器时，两只眼睛变成一对亮着深橙的四角星。
 * 深色图标的底板是纯黑，幽灵换成浅米色。
 */

/** 午夜的满月：圆心与半径，比画面正中偏右，露在幽灵的右边。 */
const MIDNIGHT_MOON = { x: 560, y: 520, radius: 410 };

/** 午夜的三颗小星，都在画面的右侧；红的一颗与樱桃同色。 */
const MIDNIGHT_STARS = [
    { x: 880, y: 170, size: 30, color: ARMFUL_PURPLES[2] },
    { x: 905, y: 850, size: 24, color: ARMFUL_PALETTES.default.cherry },
    { x: 790, y: 300, size: 16, color: '#FFFFFF' },
];

/** 午夜的幽灵：头顶的位置、大小与倾角，见 ghostPose；头往右歪，身子往左下伸出画面。 */
const MIDNIGHT_GHOST = { top: [455, 118], scale: 1.22, lean: [20, 14] };

/** 午夜的两只眼睛在幽灵自身坐标里的位置，望向右边；远处的一只略小、略高。 */
const MIDNIGHT_EYES = [{ u: 79, v: 240 }, { u: 197, v: 234, size: 0.92 }];

/**
 * 午夜的入口。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 眼睛是否亮成四角星
 */
async function paintMidnightIcon(context, scale, pixels, style, lit) {
    const ghost = ghostSticker({ pose: ghostPose(MIDNIGHT_GHOST), eyes: MIDNIGHT_EYES });

    await paintStickerIcon(context, scale, pixels, style, lit, moonMarkup(MIDNIGHT_MOON, MIDNIGHT_STARS), [ghost]);
}
