import type { GhostOptions, IconKit, Palette, Point, ServerOptions, Sticker } from './kit.ts';
import { type Art, type ArtLayer, sizeArt } from './markup.ts';

/*
 * 首页与 404 页上的几幅画，都由 App 应用图标的绘制脚本画出。
 *
 * 一团贴纸拆成几层时，每组各出投影、贴纸边与成品三层，叠放的次序是全部投影、全部贴纸边、全部成品：
 * 贴纸边都是同一种颜色，压在一起看不出先后，静止时与整团一起画的样子相同，而每组的三层可以一起挪开。
 */

/** 共用一圈贴纸边、可以单独移动的一组贴纸。 */
export interface StickerGroup {
    /** 组名，各层的名字由它加上后缀 */
    name: string;

    /** 这一组的贴纸，从后往前 */
    stickers: readonly Sticker[];
}

/** 首页与 404 页上的几幅画。 */
export interface SiteArt {
    /** 首页顶部的应用图标：底板、幽灵与机架分层 */
    hero: Art;

    /** 示意图里的服务器：左右翻过来的身前，三层的机架与浮在它身前的幽灵，机身上的影子与幽灵同组，不带底板 */
    server: Art;

    /** 示意图里的 Mac，与服务器同样的贴纸画法和比例 */
    mac: Art;

    /** 冲突向导旁的服务器：往上投出一束光，幽灵在光里浮着；光束与亮着指示灯的机身各成一层，不带底板 */
    reveal: Art;

    /** 首页收尾的抱着樱桃的幽灵 */
    armful: Art;

    /** 404 页举着双手的幽灵 */
    ghost: Art;
}

/** 带圆角的矩形：Mac 的机身、底座、屏幕与凹口都按它画。 */
interface RoundedBox {
    /** 左上角的 x */
    x: number;

    /** 左上角的 y */
    y: number;

    /** 宽 */
    width: number;

    /** 高 */
    height: number;

    /** 圆角半径 */
    radius: number;
}

/**
 * 各幅画在页面上的显示宽度，CSS 像素。
 *
 * 示意图里的服务器与 Mac 同宽，收尾的满怀与显形按画面范围与服务器取同一个比例，几幅画的贴纸边一样粗。
 */
export const displayWidths = { hero: 128, server: 160, reveal: 179, armful: 154, ghost: 104 };

/** 不带底板的画面上，探身的机架与幽灵所占的范围；投影可以超出这个范围。 */
export const riseFrame = [90, 120, 844, 780] as const;

/**
 * 不带底板的画面上，身前的机架所占的范围，与 `riseFrame` 一样大。
 *
 * 机架的底边与 Mac 的底边落在同一条线上；幽灵的下摆垂到画面的下边之外。
 */
export const frontFrame = [90, 42, 844, 780] as const;

/** 不带底板的画面上，显形的光束、幽灵与服务器所占的范围：光束的顶边最宽，服务器在最下面。 */
export const revealFrame = [40, 60, 944, 900] as const;

/** 抱着樱桃的幽灵这一团所占的范围。 */
export const armfulFrame = [118, 92, 812, 812] as const;

/**
 * Mac 的形体，画在 `riseFrame` 里；底边与示意图里那组机架的底边落在同一条线上，见 `frontFrame`。
 *
 * 屏幕一圈是机身的紫色，里面的屏幕画着一扇小窗口：三颗窗口按钮、几行提交与一条分支线；
 * 每行提交的 `shade` 是那一行文字色块在 `kit.colors.purples` 里的序号。
 */
const macShape = {
    lid: { x: 196, y: 404, width: 632, height: 420, radius: 44 },
    screen: { inset: 30, radius: 18 },
    base: { x: 120, y: 824, width: 784, height: 46, radius: 23 },
    notch: { width: 128, height: 14 },
    windowButtons: ['#FF6159', '#FFBD2E', '#28C941'],
    rows: [
        { y: 576, width: 300, shade: 2 },
        { y: 636, width: 236, shade: 1 },
        { y: 696, width: 270, shade: 1 },
        { y: 756, width: 196, shade: 0 },
    ],
} as const;

/** 由绘制脚本画出首页与 404 页上的几幅画。 */
export function createSiteArt(kit: IconKit): SiteArt {
    const rise = kit.capture('rise', 'default', false);
    const ghost = rise.stickers.filter(({ kind }) => kind === 'ghostSticker');
    const rack = rise.stickers.filter(({ kind }) => kind !== 'ghostSticker');
    const groups = [{ name: 'ghost', stickers: ghost }, { name: 'rack', stickers: rack }];

    const inset = (markup: string): string => {
        const { origin, size } = kit.plate;

        return `<g transform="translate(${origin} ${origin}) scale(${size / kit.grid})">${markup}</g>`;
    };

    const hero = {
        viewBox: [0, 0, kit.grid, kit.grid] as const,
        layers: [
            { name: 'plate', markup: plateMarkup(kit, rise.palette, inset(rise.background)) },
            ...clusterLayers(kit, rise.palette, rise.lit, groups).map((layer) => ({
                ...layer,
                markup: inset(layer.markup),
            })),
        ],
    };

    // 不带底板的几幅画直接落在页面上，投影写成 currentColor，由页面按主题换色
    const page = { ...rise.palette, cast: 'currentColor' };
    const cast = rise.palette.cast;

    // 收尾的满怀是幽灵摘到樱桃之后的样子，眼睛亮成四角星
    const armful = kit.capture('armful', 'default', true);

    // 宽度是各幅画在页面上的显示宽度；图标的画面缩进了底板，滤镜所在的坐标比 viewBox 小一圈
    return {
        hero: sizeArt(hero, displayWidths.hero, kit.plate.size / kit.grid),
        server: { ...sizeArt({ viewBox: frontFrame, layers: frontLayers(kit) }, displayWidths.server), cast },
        mac: {
            ...sizeArt({
                viewBox: riseFrame,
                layers: clusterLayers(kit, page, rise.lit, [{ name: 'mac', stickers: [macSticker(kit)] }]),
            }, displayWidths.server),
            cast,
        },
        reveal: { ...sizeArt({ viewBox: revealFrame, layers: revealLayers(kit) }, displayWidths.reveal), cast },
        armful: {
            ...sizeArt({
                viewBox: armfulFrame,
                layers: [{
                    name: 'ghost',
                    group: 'ghost',
                    markup: kit.armfulCluster({ ...armful.palette, cast: 'currentColor' }, armful.lit),
                }],
            }, displayWidths.armful),
            cast: armful.palette.cast,
        },
        ghost: {
            ...sizeArt({
                viewBox: [riseFrame[0], riseFrame[1], riseFrame[2], 700],
                layers: clusterLayers(kit, page, rise.lit, [{ name: 'ghost', stickers: ghost }]),
            }, displayWidths.ghost),
            cast,
        },
    };
}

/**
 * 一团贴纸拆成的层：先是各组的投影，再是各组的贴纸边，最后是各组的成品。
 *
 * 投影与贴纸边都交给绘制脚本的 `stickerClusterMarkup` 画，只是让剪影在另一种颜色下画成空的。
 */
export function clusterLayers(
    kit: IconKit,
    palette: Palette,
    lit: boolean,
    groups: readonly StickerGroup[],
): ArtLayer[] {
    const silhouettes = (stickers: readonly Sticker[], color: string): string => {
        const only = stickers.map((sticker) => ({
            defs: sticker.defs,
            outline: (fill: string) => (fill === color ? sticker.outline(fill) : ''),
            paint: () => '',
        }));

        return withoutEmptyGroups(kit.cluster(palette, lit, only));
    };

    const shadows = groups.map(({ name, stickers }) => ({
        name: `${name}-shadow`,
        group: name,
        markup: silhouettes(stickers, palette.cast),
    }));

    const edges = groups.map(({ name, stickers }) => ({
        name: `${name}-edge`,
        group: name,
        markup: silhouettes(stickers, palette.edge),
    }));

    const paints = groups.map(({ name, stickers }) => ({
        name,
        group: name,
        markup: stickers.map((sticker) => sticker.defs).join('')
            + stickers.map((sticker) => sticker.paint(palette, lit)).join(''),
    }));

    return [...shadows, ...edges, ...paints];
}

/** 示意图里那幅身前的配色、幽灵与机架。 */
export interface FrontStickers {
    /** 身前的配色 */
    palette: Palette;

    /** 造幽灵贴纸的参数 */
    ghost: GhostOptions;

    /** 三台机架，机身上没有影子 */
    bare: Sticker[];

    /** 同样的三台机架，机身上落着幽灵的影子 */
    shaded: Sticker[];
}

/**
 * 示意图里的身前，左右翻了过来：幽灵从页面右边飘来，停在机架身前时仍朝着左边，抬手指着左边的指示灯。
 *
 * 翻的是位置与朝向：落在机身上的影子跟着翻到左边，仍落在露出来的机身上；幽灵的受光处与贴纸的投影和别的画一样。
 * 三台机架都带着盘位槽：图标里下面两台的槽被幽灵挡着、没有画，页面上幽灵会飘走，照最上面一台补上。
 */
export function frontStickers(kit: IconKit): FrontStickers {
    const { palette, stickers } = kit.capture('front', 'default', false);
    const mirror = (x: number): number => kit.grid - x;
    const optionsOf = <T>(name: string): T[] =>
        stickers.filter(({ kind }) => kind === name).map(({ options }) => options as T);

    const [captured] = optionsOf<GhostOptions>('ghostSticker');
    const posed = captured?.pose.options;

    if (!captured || !posed) {
        throw new Error('没能从绘制脚本取出身前的幽灵');
    }

    // 姿态、小手与眼睛各自翻到另一边：头顶换到对称的位置，脊线往另一侧歪，眼睛朝另一侧转
    const ghost: GhostOptions = {
        pose: kit.ghostPose({
            top: [mirror(posed.top[0]), posed.top[1]],
            scale: posed.scale,
            lean: [-posed.lean[0], -posed.lean[1]],
        }),
        hands: (captured.hands ?? []).map((hand) => ({
            ...hand,
            line: hand.line.map(([x, y]): Point => [mirror(x), y]),
        })),
        eyes: captured.eyes.map((eye) => ({ ...eye, u: -eye.u, tilt: -(eye.tilt ?? kit.ghostEye.tilt) })),
    };

    // 机身上的影子都是幽灵的：换成翻过来的那只的剪影，往另一边挪开
    const outline = kit.ghostSticker(ghost);
    const servers = optionsOf<ServerOptions>('serverSticker');
    const slot = servers.find((server) => server.slot)?.slot;

    const mirrored = servers.map((server) => ({
        ...server,
        x: mirror(server.x + server.width),
        leds: server.leds.map(mirror),
        ...(slot ? { slot: { ...slot, x: mirror(slot.x + slot.width) } } : {}),
        shadows: (server.shadows ?? []).map((shadow) => ({ ...shadow, shape: outline.outline, dx: -shadow.dx })),
    }));

    // 剪影的滤镜定义在幽灵的贴纸里：落着影子的一组单独成层时带上这份定义
    const outlineDefs = { defs: outline.defs, outline: () => '', paint: () => '' };

    return {
        palette,
        ghost,
        bare: mirrored.map((server) => kit.serverSticker({ ...server, shadows: [] })),
        shaded: [outlineDefs, ...mirrored.map((server) => kit.serverSticker(server))],
    };
}

/**
 * 身前拆成的层：机架与幽灵两组的投影、贴纸边与成品，落着幽灵影子的机身盖在机架的成品上、与幽灵同组。
 *
 * 页面把幽灵藏起时，机身上的影子跟着藏起，露出下面两台的盘位槽。
 */
function frontLayers(kit: IconKit): ArtLayer[] {
    const { palette, ghost, bare, shaded } = frontStickers(kit);
    const page = { ...palette, cast: 'currentColor' };

    const shade = clusterLayers(kit, page, false, [{ name: 'shade', stickers: shaded }])
        .filter(({ name }) => name === 'shade')
        .map((layer) => ({ ...layer, group: 'ghost' }));

    return clusterLayers(kit, page, false, [
        { name: 'rack', stickers: bare },
        { name: 'ghost', stickers: [kit.ghostSticker(ghost)] },
    ]).flatMap((layer) => (layer.name === 'rack' ? [layer, ...shade] : [layer]));
}

/**
 * 显形拆成的层：最后面是光束，再是服务器与幽灵两组的投影、贴纸边与成品，亮着指示灯的机身盖在服务器上面。
 *
 * 光束与亮灯的机身单独成层，页面按幽灵在不在把它们显示或藏起。
 */
function revealLayers(kit: IconKit): ArtLayer[] {
    const { palette, stickers, beam } = kit.capture('reveal', 'default', false);
    const page = { ...palette, cast: 'currentColor' };
    const ghost = stickers.filter(({ kind }) => kind === 'ghostSticker');
    const server = stickers.filter(({ kind }) => kind !== 'ghostSticker');
    const lit = clusterLayers(kit, page, true, [{ name: 'lamps', stickers: server }]);

    const layers = clusterLayers(kit, page, false, [
        { name: 'server', stickers: server },
        { name: 'ghost', stickers: ghost },
    ]);

    return [
        { name: 'beam', markup: beam },
        ...layers.flatMap((layer) => (layer.name === 'server'
            ? [layer, ...lit.filter(({ name }) => name === 'lamps')]
            : [layer])),
    ];
}

/**
 * 底板：下方一片投影，里面是缩进底板范围的画面。
 *
 * Canvas 的 `shadowBlur` 是高斯模糊标准差的两倍。
 */
function plateMarkup(kit: IconKit, palette: Palette, scene: string): string {
    const { data, shadow } = kit.plate;
    const clip = kit.stickerId('plate-clip');
    const plate = (fill: string): string => `<path d="${data}" fill="${fill}"/>`;

    return kit.svg.blurred(kit.stickerId('plate-shadow'), plate(shadow.color), {
        dy: shadow.offsetY,
        blur: shadow.blur / 2,
        opacity: 1,
    })
        + plate(palette.plate[2] ?? '')
        + `<clipPath id="${clip}"><path d="${data}"/></clipPath>`
        + `<g clip-path="url(#${clip})">${scene}</g>`;
}

/**
 * Mac 的贴纸：屏幕与底座，机身的紫色、暗部与屏幕的深色都取自机架的配色。
 */
function macSticker(kit: IconKit): Sticker {
    const { lid, screen, base, notch } = macShape;
    const id = kit.stickerId('mac');

    const rect = (box: RoundedBox, fill: string): string =>
        `<rect x="${box.x}" y="${box.y}" width="${box.width}" height="${box.height}" `
        + `rx="${box.radius}" fill="${fill}"/>`;

    const shape = (fill: string): string => rect(lid, fill) + rect(base, fill);

    return {
        defs: '',
        outline: shape,
        paint(palette) {
            const server = palette['server'] as readonly string[];
            const shade = palette['serverShade'] as string;

            // 屏幕与底座各自自上而下由浅到深，下缘一道暗部，与机架相同
            const body = (name: string, box: RoundedBox): string =>
                kit.svg.linear(`${id}-${name}-fill`, [0, box.y, 0, box.y + box.height], server)
                + kit.svg.masked(
                    `${id}-${name}-inside`,
                    rect(box, '#fff'),
                    `<rect ${kit.svg.wide} fill="url(#${id}-${name}-fill)"/>`
                    + kit.svg.innerBand(`${id}-${name}-shade`, rect(box, '#000'), {
                        color: shade,
                        dy: -10,
                        blur: 10,
                        gain: 1.2,
                        opacity: 0.55,
                    }),
                );

            // 底座正中开合处的凹口
            const groove = rect({
                x: base.x + (base.width - notch.width) / 2,
                y: base.y,
                width: notch.width,
                height: notch.height,
                radius: notch.height / 2,
            }, shade);

            return body('lid', lid) + screenMarkup(palette['slot'] as string) + body('base', base) + groove;
        },
    };

    /** 屏幕：深色的屏幕上一扇小窗口。 */
    function screenMarkup(color: string): string {
        const area = {
            x: lid.x + screen.inset,
            y: lid.y + screen.inset,
            width: lid.width - screen.inset * 2,
            height: lid.height - screen.inset * 2,
            radius: screen.radius,
        };

        return rect(area, color) + windowMarkup(kit, area);
    }
}

/**
 * 屏幕里的小窗口：标题栏的三颗按钮，左边一条分支线串起几行提交。
 */
function windowMarkup(kit: IconKit, area: { x: number; y: number }): string {
    const { windowButtons, rows } = macShape;
    const { purples, branch: colors } = kit.colors;
    const left = area.x + 44;
    const lineX = left + 26;

    const buttons = windowButtons
        .map((color, index) => `<circle cx="${left + index * 40}" cy="${area.y + 44}" r="13" fill="${color}"/>`)
        .join('');

    const first = rows[0].y;
    const last = rows[rows.length - 1]?.y ?? first;

    // 分支线：主干贯穿各行，第二行分出一条支线，到最后一行汇回
    const fork = rows[1].y;
    const bend = lineX + 52;

    const branch = `<path d="M${lineX},${first}L${lineX},${last}`
        + `M${lineX},${fork}C${bend},${fork} ${bend},${last} ${lineX},${last}" `
        + `fill="none" stroke="${colors.line}" stroke-width="12" stroke-linecap="round"/>`;

    const commits = rows
        .map(({ y, width, shade }) => `<circle cx="${lineX}" cy="${y}" r="17" fill="${colors.node}"/>`
            + `<circle cx="${lineX}" cy="${y}" r="7" fill="${colors.core}"/>`
            + `<rect x="${lineX + 72}" y="${y - 11}" width="${width}" height="22" rx="11" `
            + `fill="${purples[shade] ?? ''}"/>`)
        .join('');

    return buttons + branch + commits;
}

/** 去掉空的 `<g>`：只画投影或只画贴纸边时，另一半剩下空的分组。 */
function withoutEmptyGroups(markup: string): string {
    let previous = '';
    let current = markup;

    while (current !== previous) {
        previous = current;
        current = current.replace(/<g [^>]*><\/g>/g, '');
    }

    return current;
}
