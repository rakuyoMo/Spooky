/**
 * 栖枝：炭黑底板上一轮紫色满月与两颗小星，白色幽灵坐在一根横着的树枝上，右上角伸进来的细枝垂下一对樱桃，就在它眼前。
 * 画法照满怀，见 sticker.js。App 连着服务器时，两只眼睛变成一对亮着深橙的四角星。
 * 深色图标的底板是纯黑，幽灵换成浅米色，树枝、樱桃与叶子压暗一档。
 */

/** 栖枝的满月：圆心与半径，与满怀相同。 */
const PERCH_MOON = { x: 512, y: 520, radius: 410 };

/** 栖枝的两颗小星。 */
const PERCH_STARS = [
    { x: 150, y: 180, size: 28, color: ARMFUL_PURPLES[2] },
    { x: 905, y: 700, size: 18, color: ARMFUL_PURPLES[1] },
];

/** 栖枝的幽灵：头顶的位置、大小与倾角，见 ghostPose；坐得端正，略往后仰。 */
const PERCH_GHOST = { top: [392, 236], scale: 0.98, lean: [-5, 3] };

/** 栖枝的两只眼睛在幽灵自身坐标里的位置，望向右上；远处的一只略小、略高。 */
const PERCH_EYES = [{ u: 76, v: 212 }, { u: 190, v: 204, size: 0.92 }];

/** 幽灵坐着的枝：从左到右横穿画面，右头略翘；中线经过的点与两头的粗细。 */
const PERCH_SEAT = { line: [[-80, 894.15], [300, 880.15], [640, 860.15], [1100, 820.15]], from: 96, to: 72 };

/** 垂下樱桃的细枝：从右上角伸进来，梢头在梗分叉的结上。 */
const PERCH_TWIG = { line: [[1100, 86], [1050, 120], [940, 168], [866, 234]], from: 46, to: 20 };

/** 细枝上的两片叶子。 */
const PERCH_LEAVES = [
    { from: [890, 200], to: [790, 158] },
    { from: [974, 146], to: [940, 56] },
];

/** 梗分叉处的结。 */
const PERCH_KNOT = { x: 866, y: 236, radius: 11.5 };

/** 栖枝的两颗樱桃：大果在近处，小果在它的右下、被它挡住一角。 */
const PERCH_CHERRIES = {
    big: { x: 792, y: 410, radius: 64 },
    small: { x: 892, y: 444, radius: 56 },
};

/**
 * 栖枝的入口：从后往前是幽灵坐着的枝、细枝、叶子、梗、小果、大果与幽灵。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 眼睛是否亮成四角星
 */
async function paintPerchIcon(context, scale, pixels, style, lit) {
    const { big, small } = PERCH_CHERRIES;
    const ghost = ghostSticker({ pose: ghostPose(PERCH_GHOST), eyes: PERCH_EYES });

    await paintStickerIcon(context, scale, pixels, style, lit, moonMarkup(PERCH_MOON, PERCH_STARS), [
        branchSticker({ ...PERCH_SEAT, shadows: [ghost.outline] }),
        branchSticker(PERCH_TWIG),
        ...PERCH_LEAVES.map(leafSticker),
        stemSticker({ lines: cherryStemLines(PERCH_KNOT, big, small), knot: PERCH_KNOT }),
        cherrySticker({ ...small, shadows: [{ shape: discShape(big), dx: 8, dy: -4, opacity: 0.5 }] }),
        cherrySticker(big),
        ghost,
    ]);
}
