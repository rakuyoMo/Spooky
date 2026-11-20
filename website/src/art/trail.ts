import type { GhostEye, IconKit, Point } from './kit.ts';
import { type Art, renderArt, sizeArt } from './markup.ts';
import {
    branchArt,
    branchFrame,
    ghostArt,
    type GhostLimb,
    ghostPresets,
    iconGhostArt,
    moonArt,
    posedGhostArt,
    poseFrame,
} from './parts.ts';
import { armfulFrame, clusterLayers, displayWidths, frontFrame, frontStickers, revealFrame } from './scenes.ts';

/*
 * 跟着页面滚动的小幽灵用到的画：各个姿势、樱桃枝、扒着窗口边的小手、亮起来的指示灯与满月。
 *
 * 这些画不放进页面的 HTML，构建时写成一份 JSON，页面的脚本启动后再取。
 * 每个姿势的画面都以幽灵身体正中为中心、显示宽度相同，换姿势时只换显示哪一张，位置与大小都不跳。
 */

/** 姿势的名字。 */
export type TrailPoseName =
    | 'rise'
    | 'front'
    | 'hide'
    | 'hideLit'
    | 'float'
    | 'right'
    | 'left'
    | 'reveal'
    | 'spot'
    | 'reach'
    | 'armful';

/** 一层画所在的一档：投影、贴纸边与成品分开叠放，页面上的机架夹在幽灵的贴纸边与成品之间。 */
export type TrailTier = 'shadow' | 'edge' | 'paint';

/** 收进 JSON 的一层。 */
export interface TrailLayer {
    /** 层名 */
    name: string;

    /** 一起显隐的几层共用的组名 */
    group?: string;

    /** 所在的一档 */
    tier: TrailTier;

    /** 这一层的 SVG 片段，id 已经加上整页唯一的前缀 */
    markup: string;
}

/** 收进 JSON 的一幅画。 */
export interface TrailPart {
    /** 画面的范围：左、上、宽、高 */
    viewBox: readonly [number, number, number, number];

    /** 原大显示时的宽度，CSS 像素 */
    width: number;

    /** 各层，从后往前 */
    layers: readonly TrailLayer[];
}

/** 页面上一幅静止的画里幽灵所在的位置。 */
export interface TrailAnchor {
    /** 身体正中占画面宽与高的比例 */
    centre: Point;

    /** 画面每宽 1 px，幽灵自身坐标的一个单位有多少 px */
    unit: number;
}

/** 跟着滚动的小幽灵用到的全部画，写进 JSON。 */
export interface TrailArt {
    /** 姿势原大显示时，幽灵自身坐标的一个单位有多少 CSS 像素 */
    unit: number;

    /** 姿势画面原大显示时的宽与高 */
    size: Point;

    /** 各个姿势 */
    poses: Record<TrailPoseName, TrailPart>;

    /** 挂着樱桃的枝；`offset` 是原大时画面左上角相对 “够樱桃” 那一刻幽灵身体正中的位置 */
    branch: TrailPart & { offset: Point };

    /** 扒着窗口边的小手，画面与 “藏身” 相同；`edge` 是原大时窗口的边离画面左边的距离 */
    paw: TrailPart & { edge: number };

    /**
     * 示意图里那组机架亮着指示灯的成品，画面与显示宽度同示意图里的服务器。
     *
     * 两层：`rack` 是亮着灯的机架，`shade` 的机身上另落着幽灵的影子，幽灵停在机架身前时才显示。
     */
    lamps: TrailPart;

    /** 满怀背后的满月；`centre` 是月亮中心占满怀画面宽与高的比例 */
    moon: TrailPart & { centre: Point };

    /** 首页顶部的图标、示意图里的服务器、冲突向导旁的显形与收尾的满怀里，幽灵各在哪里 */
    anchors: { hero: TrailAnchor; server: TrailAnchor; reveal: TrailAnchor; armful: TrailAnchor };

    /** 图标底板上投影的颜色：幽灵还在底板上时投影用它 */
    plateCast: string;
}

/** 姿势原大显示时的宽度，CSS 像素；幽灵缩小着画最清楚，这个宽度按页面上最大的那只定。 */
const poseWidth = 184;

/**
 * 窗口的边落在 “藏身” 图标网格里的 x：机柜的右边在 472，往幽灵那边挪一点，幽灵多藏起一些，小手的根部仍在窗口外。
 */
const windowEdge = 500;

/** 由绘制脚本画出跟着滚动的小幽灵用到的全部画。 */
export function createTrailArt(kit: IconKit): TrailArt {
    const presets = ghostPresets(kit);
    const rise = iconGhostArt(kit, 'rise', { width: poseWidth });
    const { ghost: frontGhost, palette: frontPalette } = frontStickers(kit);
    const front = posedGhostArt(kit, frontGhost, frontPalette, { width: poseWidth });
    const hide = iconGhostArt(kit, 'hide', { width: poseWidth });
    const reveal = iconGhostArt(kit, 'reveal', { width: poseWidth });
    const reach = iconGhostArt(kit, 'cherryPick', { lit: true, width: poseWidth });
    const unit = (poseWidth / rise.viewBox[2]) * rise.scale;
    const armful = armfulPose(kit, poseWidth);

    // 飘着的幽灵不带小手，眼睛望向去的方向
    const glide = (eyes: readonly GhostEye[], extra: { hands?: readonly GhostLimb[]; lit?: boolean } = {}): Art =>
        ghostArt(kit, { eyes, ...extra, width: poseWidth });

    const poses = {
        rise,
        front,
        hide,
        hideLit: iconGhostArt(kit, 'hide', { lit: true, width: poseWidth }),
        float: glide(presets.eyes.front),
        right: glide(presets.eyes.right),
        left: glide(presets.eyes.left),
        reveal,
        spot: glide(presets.eyes.right, { hands: presets.hands.lifted, lit: true }),
        reach,
        armful: armful.art,
    };

    // 枝与 “够樱桃” 的幽灵同在采撷的图标网格里，按幽灵的单位长度缩放后两者正好对上
    const branchZoom = unit / reach.scale;
    const branch = branchArt(kit, { cherries: true, width: branchFrame[2] * branchZoom });

    return {
        unit,
        size: [poseWidth, (poseWidth * rise.viewBox[3]) / rise.viewBox[2]],
        poses: Object.fromEntries(
            Object.entries(poses).map(([name, art]) => [name, trailPart(art, `trail-${name}-`)]),
        ) as Record<TrailPoseName, TrailPart>,
        branch: {
            ...trailPart(branch, 'trail-branch-'),
            offset: [
                (branchFrame[0] - reach.centre[0]) * branchZoom,
                (branchFrame[1] - reach.centre[1]) * branchZoom,
            ],
        },
        paw: {
            ...trailPart(pawArt(kit, hide.viewBox, poseWidth), 'trail-paw-'),
            edge: ((windowEdge - hide.viewBox[0]) * unit) / hide.scale,
        },
        lamps: trailPart(lampsArt(kit), 'trail-lamps-'),
        moon: moonPart(kit),
        anchors: anchors(kit, rise, front, reveal, armful),
        plateCast: kit.capture('rise', 'default', false).palette.cast,
    };
}

/**
 * 满怀做成一个姿势：画面以身体正中为中心，单位长度与别的姿势相同；眼睛亮着。
 *
 * 身体正中取轮廓锚点外接框的中心，按整团的姿态放到画面上。
 */
function armfulPose(kit: IconKit, width: number): { art: Art; centre: Point; scale: number } {
    const { body, pose } = kit.armfulGhost;
    const xs = body.map(([x]) => x);
    const ys = body.map(([, y]) => y);
    const local: Point = [(Math.min(...xs) + Math.max(...xs)) / 2, (Math.min(...ys) + Math.max(...ys)) / 2];
    const centre = placeArmful(local, pose);
    const palette = { ...kit.capture('armful', 'default', true).palette, cast: 'currentColor' };

    return {
        art: sizeArt({
            viewBox: poseFrame(centre, pose.scale),
            layers: [{ name: 'ghost', group: 'ghost', markup: kit.armfulCluster(palette, true) }],
        }, width),
        centre,
        scale: pose.scale,
    };
}

/**
 * “藏身” 里扒着机柜边的那只小手，单独成一团：页面上它叠在窗口上面，幽灵在窗口后面。
 */
function pawArt(kit: IconKit, viewBox: Art['viewBox'], width: number): Art {
    const capture = kit.capture('hide', 'default', false);
    const paw = capture.stickers.filter(({ kind }) => kind === 'pawSticker');
    const palette = { ...capture.palette, cast: 'currentColor' };

    return sizeArt({ viewBox, layers: clusterLayers(kit, palette, false, [{ name: 'paw', stickers: paw }]) }, width);
}

/**
 * 示意图里那组机架亮着指示灯的成品：盖在原来的机架上淡入，就是灯亮起来；另一层的机身上落着幽灵的影子。
 */
function lampsArt(kit: IconKit): Art {
    const { palette, bare, shaded } = frontStickers(kit);

    const layers = clusterLayers(kit, { ...palette, cast: 'currentColor' }, true, [
        { name: 'rack', stickers: bare },
        { name: 'shade', stickers: shaded },
    ]);

    return sizeArt({
        viewBox: frontFrame,
        layers: layers.filter(({ name }) => name === 'rack' || name === 'shade'),
    }, displayWidths.server);
}

/**
 * 满怀图标里的满月，按收尾那幅满怀的比例画出。
 */
function moonPart(kit: IconKit): TrailPart & { centre: Point } {
    const { moon } = kit.armfulMoon;
    const zoom = displayWidths.armful / armfulFrame[2];
    const art = moonArt(kit, { width: 1 });

    return {
        ...trailPart(moonArt(kit, { width: art.viewBox[2] * zoom }), 'trail-moon-'),
        centre: [(moon.x - armfulFrame[0]) / armfulFrame[2], (moon.y - armfulFrame[1]) / armfulFrame[3]],
    };
}

/** 一只幽灵在图标网格里的位置与大小。 */
interface Placed {
    /** 身体正中 */
    centre: Point;

    /** 幽灵的大小 */
    scale: number;
}

/**
 * 四幅静止的画里幽灵所在的位置：顶部图标的画面缩进了底板，示意图里的服务器、显形与收尾的满怀各按自己的画面范围。
 *
 * 顶部图标里是探身的幽灵，示意图的服务器前是左右翻过来的身前的幽灵。
 */
function anchors(kit: IconKit, rise: Placed, front: Placed, reveal: Placed, armful: Placed): TrailArt['anchors'] {
    const { origin, size } = kit.plate;
    const inset = size / kit.grid;

    // 幽灵在一幅不带底板的画里的位置，第二个参数是那幅画的画面范围
    const within = (
        { centre, scale }: Placed,
        [x, y, width, height]: readonly [number, number, number, number],
    ): TrailAnchor => ({
        centre: [(centre[0] - x) / width, (centre[1] - y) / height],
        unit: scale / width,
    });

    return {
        hero: {
            centre: [(origin + rise.centre[0] * inset) / kit.grid, (origin + rise.centre[1] * inset) / kit.grid],
            unit: (rise.scale * inset) / kit.grid,
        },
        server: within(front, frontFrame),
        reveal: within(reveal, revealFrame),
        armful: within(armful, armfulFrame),
    };
}

/** 满怀的一点放到画面上：绕中心转、缩放，再平移。 */
function placeArmful([x, y]: Point, pose: IconKit['armfulGhost']['pose']): Point {
    const angle = (pose.degrees * Math.PI) / 180;
    const dx = (x - pose.pivot[0]) * pose.scale;
    const dy = (y - pose.pivot[1]) * pose.scale;

    return [
        pose.shift[0] + pose.pivot[0] + dx * Math.cos(angle) - dy * Math.sin(angle),
        pose.shift[1] + pose.pivot[1] + dx * Math.sin(angle) + dy * Math.cos(angle),
    ];
}

/** 一幅画收进 JSON：id 加上前缀、数字收短，每层按层名记下所在的一档。 */
function trailPart(art: Art, prefix: string): TrailPart {
    const { viewBox, width, layers } = renderArt(art, prefix);

    return {
        viewBox,
        width,
        layers: layers.map(({ name, group, markup }) => ({
            name,
            ...(group ? { group } : {}),
            tier: tierOf(name),
            markup,
        })),
    };
}

/** 层名的后缀说明它在哪一档。 */
function tierOf(name: string): TrailTier {
    if (name.endsWith('-shadow')) {
        return 'shadow';
    }

    return name.endsWith('-edge') ? 'edge' : 'paint';
}
