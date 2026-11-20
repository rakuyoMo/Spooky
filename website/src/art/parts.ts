import type {
    GhostEye,
    GhostOptions,
    GhostPose,
    IconCapture,
    IconGroup,
    IconKit,
    Palette,
    Point,
    Sticker,
} from './kit.ts';
import { type Art, sizeArt } from './markup.ts';
import { clusterLayers } from './scenes.ts';

/*
 * 跟着页面滚动的小幽灵要用到的零件：任意姿势的幽灵、樱桃枝与满月。
 *
 * 零件的配色、贴纸边、投影与眼睛都出自 App 应用图标的绘制脚本；小手与眼睛的预设取自各组图标里幽灵的样子。
 */

/** 幽灵的一只小手，经过的点在幽灵自身坐标里，跟着身体的姿势走。 */
export interface GhostLimb {
    /** 中线经过的点，从根部到手尖：u 是离脊线的距离，往右为正；v 是从头顶沿脊线往下的距离 */
    points: readonly Point[];

    /** 根部的粗细 */
    from: number;

    /** 手尖的粗细 */
    to: number;
}

/** 取自各组图标的小手与眼睛。 */
export interface GhostPresets {
    /** 小手：探身举起的两只、身前抬向右边的一只、采撷搭向樱桃的一只 */
    hands: {
        raised: readonly GhostLimb[];
        lifted: readonly GhostLimb[];
        reaching: readonly GhostLimb[];
    };

    /** 眼睛：探身望着前方、采撷望向右边、栖枝望向右上，以及望向右边的左右翻转 */
    eyes: {
        front: readonly GhostEye[];
        right: readonly GhostEye[];
        left: readonly GhostEye[];
        upward: readonly GhostEye[];
    };
}

/** 画一只幽灵的参数。 */
export interface GhostArtOptions {
    /** 脊线在头部与下摆处的倾角，度，正值是头往右歪；省略时直立 */
    lean?: Point;

    /** 小手，省略时没有 */
    hands?: readonly GhostLimb[];

    /** 眼睛 */
    eyes: readonly GhostEye[];

    /** 眼睛是否亮成四角星 */
    lit?: boolean;

    /** 页面上的显示宽度，CSS 像素 */
    width: number;
}

/** 幽灵的大小，与探身相同：小手与贴纸边的粗细都按这个大小定。 */
const ghostScale = 0.95;

/** 幽灵直立时身体正中离头顶的距离，自身坐标；身体正中落在画面正中。 */
const ghostMiddle = 333;

/** 幽灵画面的范围，相对身体正中：直立、举起双手时四周留出贴纸边；歪身时可以超出。 */
const ghostFrame = [-460, -380, 920, 760] as const;

/** 樱桃枝画面的范围，坐标与采撷的图标相同；枝的粗头可以超出。 */
export const branchFrame = [430, 110, 720, 540] as const;

/** 取出各组图标里幽灵的小手与眼睛。 */
export function ghostPresets(kit: IconKit): GhostPresets {
    const ghostOf = (group: IconGroup): {
        hands: readonly GhostLimb[];
        eyes: readonly GhostEye[];
    } => {
        const options = capturedGhost(kit.capture(group, 'default', false)).options as {
            pose: GhostPose;
            hands?: readonly { line: readonly Point[]; from: number; to: number }[];
            eyes: readonly GhostEye[];
        };

        const hands = (options.hands ?? []).map(({ line, from, to }) => ({
            points: line.map((point) => localPoint(options.pose, point)),
            from,
            to,
        }));

        return { hands, eyes: options.eyes };
    };

    const rise = ghostOf('rise');
    const cherryPick = ghostOf('cherryPick');

    return {
        hands: {
            raised: rise.hands,
            lifted: ghostOf('front').hands,
            reaching: cherryPick.hands,
        },
        eyes: {
            front: rise.eyes,
            right: cherryPick.eyes,
            left: cherryPick.eyes.map((eye) => ({ ...eye, u: -eye.u })),
            upward: ghostOf('perch').eyes,
        },
    };
}

/**
 * 一只幽灵，身体正中落在画面正中；换姿势时画面的范围不变，几张画叠在一起切换不会跳。
 *
 * 分成投影、贴纸边与成品三层，组名都是 `ghost`。
 */
export function ghostArt(kit: IconKit, options: GhostArtOptions): Art {
    const source = kit.capture('cherryPick', 'default', false).palette;
    const palette = { ...source, cast: 'currentColor' };

    // 绘制脚本的蒙版与滤镜只覆盖图标网格外扩一圈的范围，幽灵画在网格正中
    const middle = kit.grid / 2;

    const pose = kit.ghostPose({
        top: [middle, middle - ghostMiddle * ghostScale],
        scale: ghostScale,
        lean: options.lean ?? [0, 0],
    });

    const ghost = kit.ghostSticker({
        pose,
        hands: (options.hands ?? []).map(({ points, from, to }) => ({
            line: points.map(([u, v]) => pose.place(u, v)),
            from,
            to,
        })),
        eyes: options.eyes,
    });

    return {
        ...sizeArt({
            viewBox: poseFrame([middle, middle], ghostScale),
            layers: clusterLayers(kit, palette, options.lit ?? false, [{ name: 'ghost', stickers: [ghost] }]),
        }, options.width),
        cast: source.cast,
    };
}

/**
 * 一组图标里的幽灵：姿势、小手与眼睛原样照搬，见 `posedGhostArt`。
 */
export function iconGhostArt(
    kit: IconKit,
    group: IconGroup,
    options: { lit?: boolean; width: number },
): Art & { centre: Point; scale: number } {
    const capture = kit.capture(group, 'default', false);

    return posedGhostArt(kit, capturedGhost(capture).options as GhostOptions, capture.palette, options);
}

/**
 * 按造贴纸的参数 `ghost` 与配色 `source` 画出的一只幽灵，`lit` 为真时眼睛亮成四角星。
 *
 * 画面见 `poseFrame`，与 `ghostArt` 按同一个显示宽度画出时，两只幽灵的单位长度相同；
 * 返回值另带身体正中在图标网格里的位置与幽灵的大小，别的零件按它们对齐。
 */
export function posedGhostArt(
    kit: IconKit,
    ghost: GhostOptions,
    source: Palette,
    options: { lit?: boolean; width: number },
): Art & { centre: Point; scale: number } {
    const palette = { ...source, cast: 'currentColor' };
    const centre = ghost.pose.place(0, ghostMiddle);

    return {
        ...sizeArt({
            viewBox: poseFrame(centre, ghost.pose.scale),
            layers: clusterLayers(kit, palette, options.lit ?? false, [
                { name: 'ghost', stickers: [kit.ghostSticker(ghost)] },
            ]),
        }, options.width),
        cast: source.cast,
        centre,
        scale: ghost.pose.scale,
    };
}

/**
 * 姿势画面的范围：以身体正中 `centre` 为中心，按幽灵的大小 `scale` 缩放 `ghostFrame`。
 *
 * 几种大小的幽灵按同一个显示宽度画出时，幽灵自身坐标的单位长度相同，叠在一起切换不会忽大忽小。
 */
export function poseFrame(centre: Point, scale: number): [number, number, number, number] {
    const zoom = scale / ghostScale;

    return [
        centre[0] + ghostFrame[0] * zoom,
        centre[1] + ghostFrame[1] * zoom,
        ghostFrame[2] * zoom,
        ghostFrame[3] * zoom,
    ];
}

/**
 * 采撷图标里的樱桃枝：枝与两片叶子一组，`cherries` 为真时再垂下梗与一对樱桃，另成一组 `cherries`。
 *
 * 手搭着的那颗不带手压出的短影。
 */
export function branchArt(kit: IconKit, options: { cherries: boolean; width: number }): Art {
    const capture = kit.capture('cherryPick', 'default', false);
    const palette = { ...capture.palette, cast: 'currentColor' };
    const of = (kind: string): Sticker[] => capture.stickers.filter((sticker) => sticker.kind === kind);

    // 采撷的贴纸从后往前是枝、叶子、梗、远处的樱桃与手搭着的那颗
    const cherries = [
        ...of('stemSticker'),
        ...of('cherrySticker').map((sticker) => {
            const { x, y, radius } = sticker.options as { x: number; y: number; radius: number };

            return kit.cherrySticker({ x, y, radius });
        }),
    ];

    const groups = [
        { name: 'branch', stickers: [...of('branchSticker'), ...of('leafSticker')] },
        ...(options.cherries ? [{ name: 'cherries', stickers: cherries }] : []),
    ];

    return {
        ...sizeArt({
            viewBox: branchFrame,
            layers: clusterLayers(kit, palette, capture.lit, groups),
        }, options.width),
        cast: capture.palette.cast,
    };
}

/** 满怀的满月与三颗小星，一层。 */
export function moonArt(kit: IconKit, options: { width: number }): Art {
    const { moon, stars } = kit.armfulMoon;
    const reach = moon.radius + 80;

    return sizeArt({
        viewBox: [moon.x - reach, moon.y - reach, reach * 2, reach * 2],
        layers: [{ name: 'moon', markup: kit.moon(moon, stars) }],
    }, options.width);
}

/** 一组图标里的幽灵贴纸。 */
function capturedGhost(capture: IconCapture): Sticker {
    const ghost = capture.stickers.find(({ kind }) => kind === 'ghostSticker');

    if (!ghost) {
        throw new Error('这组图标里没有幽灵');
    }

    return ghost;
}

/**
 * 画面里的一点在幽灵自身坐标里的位置：沿脊线找到这一点正好落在身体横截线上的那一处。
 *
 * 脊线按 2 个单位一步，结果的误差在一步之内。
 */
function localPoint(pose: GhostPose, [x, y]: Point): Point {
    let best: Point = [0, 0];
    let nearest = Number.POSITIVE_INFINITY;

    // 脊线延伸到下摆以下，扫到 800 已经越过它的尽头
    for (let v = 0; v <= 800; v += 2) {
        const [spineX, spineY] = pose.place(0, v);
        const angle = (pose.degrees(v) * Math.PI) / 180;
        const dx = x - spineX;
        const dy = y - spineY;

        // 沿脊线的偏离为 0 处，这一点就在 v 处的横截线上
        const along = -dx * Math.sin(angle) + dy * Math.cos(angle);
        const across = dx * Math.cos(angle) + dy * Math.sin(angle);

        if (Math.abs(along) < nearest) {
            nearest = Math.abs(along);
            best = [across / pose.scale, v + along / pose.scale];
        }
    }

    return best;
}
