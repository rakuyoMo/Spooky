import type { CherryOptions, GhostEye, GhostOptions, GhostPose, IconKit, Palette, Point } from './kit.ts';
import { type Art, renderArt, sizeArt } from './markup.ts';
import {
    branchArt,
    branchFrame,
    ghostArt,
    type GhostPresets,
    ghostPresets,
    iconGhostArt,
    moonArt,
    posedGhostArt,
    poseFrame,
} from './parts.ts';
import { armfulFrame, clusterLayers, displayWidths, frontFrame, frontStickers, revealFrame } from './scenes.ts';

/*
 * 跟着页面滚动的小幽灵用到的画：各个姿势与姿势之间的过渡画、另画的眼睛、樱桃枝、扒着窗口边的小手、亮起来的指示灯与满月。
 *
 * 这些画不放进页面的 HTML，构建时写成一份 JSON，页面的脚本启动后再取。
 * 每张姿势的画面都以幽灵身体正中为中心、显示宽度相同，换姿势时只换显示哪一张，位置与大小都不跳。
 * 眼睛不画在姿势里，另成两只叠在上面：每张姿势记下眼睛望向各处时的位置，由页面的脚本按滚动的距离把眼睛挪过去。
 */

/** 姿势的名字。 */
export type TrailPoseName = 'rise' | 'front' | 'hide' | 'float' | 'reveal' | 'spot' | 'reach' | 'armful';

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

/** 姿势原大显示时的一只眼睛，坐标是姿势画面里的 CSS 像素。 */
export interface TrailEye {
    /** 中心的 x */
    x: number;

    /** 中心的 y */
    y: number;

    /** 顺时针转的度数 */
    angle: number;

    /** 相对近处那只的大小 */
    size: number;
}

/**
 * 收进 JSON 的一张姿势的画：身体与小手，以及眼睛望向各处时的位置。
 *
 * `eyes` 是三行三列的九格，自上而下是望向上方、平视、望向下方，自左而右是望向左边、前方、右边；
 * 每格是两只眼睛，从左到右。页面在相邻的格之间插值。
 */
export interface TrailPose extends TrailPart {
    /** 望向各处时的两只眼睛 */
    eyes: readonly (readonly TrailEye[])[];
}

/** 另画的一只眼睛：平时的竖椭圆与亮着时的四角星，中心都在原点，单位是姿势画面里的 CSS 像素。 */
export interface TrailEyeArt {
    /** 竖椭圆 */
    oval: string;

    /** 四份四角星，id 各不相同：两只眼睛各一份，演示窗口里做完一步时亮一下的再各一份 */
    sparkles: readonly string[];

    /** 以原点为中心、边长为它两倍的正方形装得下眼睛与四周的光 */
    radius: number;
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
    poses: Record<TrailPoseName, TrailPose>;

    /** 两个姿势之间按先后排好的过渡画；键是 “换出去的姿势>换进来的姿势”，倒过来换时倒着用 */
    morphs: Partial<Record<`${TrailPoseName}>${TrailPoseName}`, readonly TrailPose[]>>;

    /** 另画的眼睛 */
    eye: TrailEyeArt;

    /**
     * 挂着樱桃的枝，枝与樱桃各自分层；`offset` 是原大时画面左上角相对 “够樱桃” 那一刻幽灵身体正中的位置，
     * `cherry` 是那对樱桃的正中相对同一点的位置
     */
    branch: TrailPart & { offset: Point; cherry: Point };

    /**
     * 扒着窗口边的小手与它落在窗口上的影子，画面与 “藏身” 相同；原大时 `edge` 是窗口的边离画面左边的距离，
     * `slide` 是小手还没伸出来时往右缩回的距离
     */
    paw: TrailPart & { edge: number; slide: number };

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

/** 亮着的眼睛四周那圈光：图标网格里模糊的标准差与整圈的不透明度，与绘制脚本画亮着的眼睛时相同。 */
const eyeGlow = { blur: 16, opacity: 0.75 };

/** 望向上方与下方时眼睛沿脊线挪动的距离，自身坐标；望向下方时两只眼睛另往脊线收拢到这个比例。 */
const gazeShift = { up: -22, down: 26, narrow: 0.94 };

/** 飞向服务器时手慢慢伸出：从飘着到身前一共分这么多步，中间的几步各画一张。 */
const liftSteps = 8;

/** 手收在身体里时中线经过的点，自身坐标，从根部到手尖：整只手都在身体的轮廓以内。 */
const tuckedHand: readonly Point[] = [[150, 440], [176, 452], [198, 462]];

/** 扒着窗口边的小手还没伸出来时往右缩回的距离，“藏身” 图标网格里的值。 */
const pawSlide = 124;

/** 小手落在窗口上的影子：挪开的量、模糊的标准差与不透明度，与绘制脚本画它落在机柜上的影子时相同。 */
const pawCast = { dx: -4, dy: 10, blur: 14, opacity: 0.6 };

/** 由绘制脚本画出跟着滚动的小幽灵用到的全部画。 */
export function createTrailArt(kit: IconKit): TrailArt {
    const presets = ghostPresets(kit);
    const rise = iconGhostArt(kit, 'rise', { width: poseWidth });
    const { ghost: frontGhost, palette: frontPalette } = frontStickers(kit);
    const front = posedGhostArt(kit, frontGhost, frontPalette, { width: poseWidth });
    const hide = iconGhostArt(kit, 'hide', { width: poseWidth });
    const reveal = iconGhostArt(kit, 'reveal', { width: poseWidth });
    const reach = iconGhostArt(kit, 'cherryPick', { width: poseWidth });
    const float = ghostArt(kit, { width: poseWidth });
    const spot = ghostArt(kit, { hands: presets.hands.lifted, width: poseWidth });
    const unit = (poseWidth / rise.viewBox[2]) * rise.scale;
    const armful = armfulPose(kit, poseWidth);

    // 望着屏幕前照探身，望向右边照采撷，望向左边是它的左右翻转；图标里的幽灵望着哪边，那一边照图标自己的眼睛
    const gazes = { front: presets.eyes.front, right: presets.eyes.right, left: presets.eyes.left };

    // 每个姿势的 id 加上各自的前缀，几个姿势叠在同一页上不重复
    const posed = (
        name: TrailPoseName,
        art: Art,
        pose: GhostPose,
        own: Partial<Record<Gaze, readonly GhostEye[]>> = {},
    ): TrailPose => ({
        ...trailPart(art, `trail-${name}-`),
        eyes: eyeGrid(kit, art, pose, { ...gazes, ...own }),
    });

    // 枝与 “够樱桃” 的幽灵同在采撷的图标网格里，按幽灵的单位长度缩放后两者正好对上
    const branchZoom = unit / reach.scale;
    const branch = branchArt(kit, { cherries: true, width: branchFrame[2] * branchZoom });
    const cherry = cherryCentre(kit);

    return {
        unit,
        size: [poseWidth, (poseWidth * rise.viewBox[3]) / rise.viewBox[2]],
        poses: {
            rise: posed('rise', rise, rise.ghost.pose, { front: rise.ghost.eyes }),
            front: posed('front', front, frontGhost.pose, { left: frontGhost.eyes }),
            hide: posed('hide', hide, hide.ghost.pose, { left: hide.ghost.eyes }),
            float: posed('float', float, float.pose),
            reveal: posed('reveal', reveal, reveal.ghost.pose, { right: reveal.ghost.eyes }),
            spot: posed('spot', spot, spot.pose),
            reach: posed('reach', reach, reach.ghost.pose, { right: reach.ghost.eyes }),
            armful: { ...trailPart(armful.art, 'trail-armful-'), eyes: armful.eyes },
        },
        morphs: {
            'float>front': liftedHands(kit, presets, frontGhost, frontPalette).map(({ art, pose }, index) => ({
                ...trailPart(art, `trail-lift-${index}-`),
                eyes: eyeGrid(kit, art, pose, { ...gazes, left: frontGhost.eyes }),
            })),
        },
        eye: eyeArt(kit, float),
        branch: {
            ...trailPart(branch, 'trail-branch-'),
            offset: [
                (branchFrame[0] - reach.centre[0]) * branchZoom,
                (branchFrame[1] - reach.centre[1]) * branchZoom,
            ],
            cherry: [(cherry[0] - reach.centre[0]) * branchZoom, (cherry[1] - reach.centre[1]) * branchZoom],
        },
        paw: {
            ...trailPart(pawArt(kit, hide.viewBox, poseWidth), 'trail-paw-'),
            edge: ((windowEdge - hide.viewBox[0]) * unit) / hide.scale,
            slide: (pawSlide * unit) / hide.scale,
        },
        lamps: trailPart(lampsArt(kit), 'trail-lamps-'),
        moon: moonPart(kit),
        anchors: anchors(kit, rise, front, reveal, armful),
        plateCast: kit.capture('rise', 'default', false).palette.cast,
    };
}

/**
 * 满怀做成一个姿势：画面以身体正中为中心，单位长度与别的姿势相同；眼睛亮着，画在满怀自己身上。
 *
 * 身体正中取轮廓锚点外接框的中心，按整团的姿态放到画面上；另画的眼睛落到满怀时，各个方向都移到满怀自己的眼睛上。
 */
function armfulPose(
    kit: IconKit,
    width: number,
): { art: Art; centre: Point; scale: number; eyes: TrailPose['eyes'] } {
    const { body, pose } = kit.armfulGhost;
    const xs = body.map(([x]) => x);
    const ys = body.map(([, y]) => y);
    const local: Point = [(Math.min(...xs) + Math.max(...xs)) / 2, (Math.min(...ys) + Math.max(...ys)) / 2];
    const centre = placeArmful(local, pose);
    const palette = { ...kit.capture('armful', 'default', true).palette, cast: 'currentColor' };
    const viewBox = poseFrame(centre, pose.scale);
    const zoom = width / viewBox[2];

    const eyes = kit.armfulEyes.ovals
        .map(({ x, y, radiusX }): TrailEye => {
            const [placedX, placedY] = placeArmful([x, y], pose);

            return {
                x: (placedX - viewBox[0]) * zoom,
                y: (placedY - viewBox[1]) * zoom,
                angle: kit.armfulEyes.tilt + pose.degrees,
                size: radiusX / kit.ghostEye.radiusX,
            };
        })
        .toSorted((a, b) => a.x - b.x);

    return {
        art: sizeArt({
            viewBox,
            layers: [{ name: 'ghost', group: 'ghost', markup: kit.armfulCluster(palette, true) }],
        }, width),
        centre,
        scale: pose.scale,
        eyes: Array.from({ length: 9 }, () => eyes),
    };
}

/** 眼睛望向的三个方向：屏幕前、左边、右边。 */
type Gaze = 'front' | 'left' | 'right';

/**
 * 一张姿势的画里，眼睛望向各处时的位置：按幽灵的姿态摆到身上，换算成画面里的 CSS 像素，每格的两只从左到右排好。
 *
 * 望向左边、前方、右边各照 `gazes` 里的一组；望向上方与下方时把这一组沿脊线挪开，见 `gazeShift`。
 * 两只眼睛按左右的次序一一对应：换方向时左边那只挪到左边那只的新位置，不会交叉。
 */
function eyeGrid(
    kit: IconKit,
    art: Art,
    pose: GhostPose,
    gazes: Record<Gaze, readonly GhostEye[]>,
): TrailPose['eyes'] {
    const [left, top, width] = art.viewBox;
    const zoom = art.width / width;

    const place = ({ u, v, size = 1, tilt = kit.ghostEye.tilt }: GhostEye): TrailEye => {
        const [x, y] = pose.place(u, v);

        return { x: (x - left) * zoom, y: (y - top) * zoom, angle: pose.degrees(v) + tilt, size };
    };

    const rows = [
        { shift: gazeShift.up, narrow: 1 },
        { shift: 0, narrow: 1 },
        { shift: gazeShift.down, narrow: gazeShift.narrow },
    ];

    return rows.flatMap(({ shift, narrow }) =>
        [gazes.left, gazes.front, gazes.right].map((eyes) =>
            eyes
                .map((eye) => place({ ...eye, u: eye.u * narrow, v: eye.v + shift }))
                .toSorted((a, b) => a.x - b.x),
        ),
    );
}

/**
 * 另画的一只眼睛，中心在原点：页面的脚本按滚动的距离给它定位置、转角与大小。
 *
 * 与绘制脚本画的眼睛相同：平时是纯色的竖椭圆；亮着时换成四角星，自上而下由浅琥珀到深橙，四周一圈光。
 * 尺寸按直立的那只幽灵 `upright` 从图标网格换算成姿势画面里的像素。
 */
function eyeArt(kit: IconKit, upright: Art & { pose: GhostPose }): TrailEyeArt {
    const { radiusX, radiusY } = kit.ghostEye;
    const { reachX, reachY, rounding, colors, glow, data } = kit.sparkle;
    const color = kit.capture('cherryPick', 'default', false).palette['eye'] as string;
    const zoom = upright.width / upright.viewBox[2];
    const unit = zoom * upright.pose.scale;
    const halfX = radiusX * unit;
    const halfY = radiusY * unit;
    const path = data(0, 0, halfX * reachX, halfY * reachY);

    // 四周的光模糊到三倍标准差处已看不出
    const radius = Math.ceil(Math.max(halfX * reachX, halfY * reachY) + rounding * unit + 3 * eyeGlow.blur * zoom);

    // 四角星：同色的圆头描边把四个角尖修圆
    const star = (fill: string): string =>
        `<path d="${path}" fill="${fill}" stroke="${fill}" stroke-width="${rounding * unit}" stroke-linejoin="round"/>`;

    const sparkle = (index: number): string =>
        kit.svg.blurred(`glow-${index}`, star(glow), { blur: eyeGlow.blur * zoom, opacity: eyeGlow.opacity })
        + kit.svg.linear(`fill-${index}`, [0, -halfY * reachY, 0, halfY * reachY], colors)
        + star(`url(#fill-${index})`);

    const part = trailPart({
        viewBox: [-radius, -radius, 2 * radius, 2 * radius],
        width: 2 * radius,
        layers: [
            { name: 'oval', markup: `<ellipse rx="${halfX}" ry="${halfY}" fill="${color}"/>` },
            ...[0, 1, 2, 3].map((index) => ({ name: `sparkle-${index}`, markup: sparkle(index) })),
        ],
    }, 'trail-eye-');

    return {
        oval: part.layers[0]?.markup ?? '',
        sparkles: part.layers.slice(1).map(({ markup }) => markup),
        radius,
    };
}

/**
 * 从飘着到身前之间的几张：身子从直立渐渐歪到身前的样子，手从收在身体里渐渐伸到指着指示灯，越伸越粗。
 *
 * `ghost` 是示意图里左右翻过来的那只，手在脊线左侧；返回的几张按先后排好，各带画出它的姿态。
 */
function liftedHands(
    kit: IconKit,
    presets: GhostPresets,
    ghost: GhostOptions,
    palette: Palette,
): { art: Art; pose: GhostPose }[] {
    const options = ghost.pose.options;
    const [lifted] = presets.hands.lifted;

    if (!options || !lifted) {
        throw new Error('没能取出身前的幽灵与它的手');
    }

    return Array.from({ length: liftSteps - 1 }, (_, index) => {
        const t = (index + 1) / liftSteps;
        const pose = kit.ghostPose({
            top: options.top,
            scale: options.scale,
            lean: [options.lean[0] * t, options.lean[1] * t],
        });

        // 预设的手是没翻过来时的样子，翻到脊线左侧时 u 取负
        const line = lifted.points.map(([u, v], point): Point => {
            const [fromU, fromV] = tuckedHand[point] ?? [u, v];

            return pose.place(-(fromU + (u - fromU) * t), fromV + (v - fromV) * t);
        });
        const thickness = 0.5 + 0.5 * t;
        const hand = { line, from: lifted.from * thickness, to: lifted.to * thickness };

        return { art: posedGhostArt(kit, { pose, hands: [hand], eyes: [] }, palette, { width: poseWidth }), pose };
    });
}

/** 采撷图标里那对樱桃的正中，图标网格里的坐标。 */
function cherryCentre(kit: IconKit): Point {
    const cherries = kit.capture('cherryPick', 'default', false).stickers
        .filter(({ kind }) => kind === 'cherrySticker')
        .map(({ options }) => options as CherryOptions);

    if (cherries.length === 0) {
        throw new Error('采撷图标里没有樱桃');
    }

    return [
        cherries.reduce((sum, { x }) => sum + x, 0) / cherries.length,
        cherries.reduce((sum, { y }) => sum + y, 0) / cherries.length,
    ];
}

/**
 * “藏身” 里扒着机柜边的那只小手：页面上它叠在窗口上面，幽灵在窗口后面。
 *
 * 小手压在窗口上，画法与图标里压在机柜上时相同：成品的根部淡入身体，身下落一片影子。
 */
function pawArt(kit: IconKit, viewBox: Art['viewBox'], width: number): Art {
    const { palette, stickers } = kit.capture('hide', 'default', false);
    const paw = stickers.filter(({ kind }) => kind === 'pawSticker');
    const shape = (fill: string): string => paw.map((sticker) => sticker.outline(fill)).join('');

    // 影子只画在小手以外：小手淡入淡出到一半时是半透明的，影子不从它身上透出来
    const shadow = kit.svg.masked(
        'paw-outside',
        `<rect ${kit.svg.wide} fill="#fff"/>${shape('#000')}`,
        kit.svg.blurred('paw-cast', shape('currentColor'), pawCast),
    );

    return sizeArt({
        viewBox,
        layers: [
            { name: 'paw-shadow', group: 'paw', markup: shadow },
            {
                name: 'paw',
                group: 'paw',
                markup: paw.map((sticker) => sticker.defs + sticker.paint(palette, false)).join(''),
            },
        ],
    }, width);
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
