/**
 * 采撷：炭黑底板上一轮紫色满月与两颗小星，樱桃枝从右上伸进来、垂下一对樱桃，白色幽灵抬起一只短手搭在近处那颗上。
 * 画法照满怀，见 sticker.js。App 连着服务器时，两只眼睛变成一对亮着深橙的四角星。
 * 深色图标的底板是纯黑，幽灵换成浅米色，树枝、樱桃与叶子压暗一档。
 */

/** 采撷的满月：圆心与半径，与满怀相同。 */
const CHERRY_PICK_MOON = { x: 512, y: 520, radius: 410 };

/** 采撷的两颗小星。 */
const CHERRY_PICK_STARS = [
    { x: 140, y: 190, size: 28, color: ARMFUL_PURPLES[2] },
    { x: 900, y: 830, size: 20, color: ARMFUL_PURPLES[1] },
];

/** 采撷的幽灵：头顶的位置、大小与倾角，见 ghostPose；身子略朝樱桃那边倾。 */
const CHERRY_PICK_GHOST = { top: [404, 290], scale: 0.88, lean: [10, 4] };

/** 采撷的两只眼睛在幽灵自身坐标里的位置，望向右边；远处的一只略小、略高。 */
const CHERRY_PICK_EYES = [{ u: 79, v: 240 }, { u: 197, v: 234, size: 0.92 }];

/**
 * 搭在樱桃上的那只手：从身上顶出来的小鼓包，与身体融成一条轮廓。
 * root 是根部在幽灵自身坐标里的位置，reach 是之后在画面里经过的点，from 与 to 是两头的粗细。
 */
const CHERRY_PICK_HAND = { root: [150, 440], reach: [[650, 668], [706, 612]], from: 120, to: 82 };

/** 采撷的枝：从右上伸进来、往左渐细；中线经过的点与两头的粗细。 */
const CHERRY_PICK_BRANCH = { line: [[1100, 214], [910, 274], [710, 276], [570, 240], [480, 196]], from: 72, to: 22 };

/** 枝上的两片叶子。 */
const CHERRY_PICK_LEAVES = [
    { from: [694, 270], to: [614, 196] },
    { from: [904, 268], to: [964, 180] },
];

/** 梗分叉处的结，压在枝上。 */
const CHERRY_PICK_KNOT = { x: 800, y: 300, radius: 11.5 };

/** 采撷的两颗樱桃：held 是手搭着的那颗，other 是它右上的同伴。 */
const CHERRY_PICK_CHERRIES = {
    held: { x: 730, y: 540, radius: 62 },
    other: { x: 830, y: 512, radius: 55 },
};

/**
 * 采撷的入口：从后往前是枝、叶子、梗、两颗樱桃与幽灵，手搭着的那颗上有手压出的短影。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 眼睛是否亮成四角星
 */
async function paintCherryPickIcon(context, scale, pixels, style, lit) {
    const { held, other } = CHERRY_PICK_CHERRIES;
    const { root, reach, from, to } = CHERRY_PICK_HAND;
    const pose = ghostPose(CHERRY_PICK_GHOST);
    const hand = { line: [pose.place(...root), ...reach], from, to };
    const handShape = (fill) => `<path d="${taperData(hand.line, from, to)}" fill="${fill}"/>`;

    await paintStickerIcon(context, scale, pixels, style, lit, moonMarkup(CHERRY_PICK_MOON, CHERRY_PICK_STARS), [
        branchSticker(CHERRY_PICK_BRANCH),
        ...CHERRY_PICK_LEAVES.map(leafSticker),
        stemSticker({ lines: cherryStemLines(CHERRY_PICK_KNOT, held, other), knot: CHERRY_PICK_KNOT }),
        cherrySticker(other),
        cherrySticker({ ...held, shadows: [{ shape: handShape, dx: 6, dy: -6, opacity: 0.55 }] }),
        ghostSticker({ pose, hands: [hand], eyes: CHERRY_PICK_EYES }),
    ]);
}
