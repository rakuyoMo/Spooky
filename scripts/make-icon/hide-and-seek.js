/**
 * 躲猫猫的四组：探身、身前、藏身与显形。炭黑底板上，白色幽灵与紫色的服务器共用一圈奶油白的贴纸边。
 * 画法照满怀，见 sticker.js；四组都不画满月。App 连着服务器时幽灵的眼睛不变，服务器上的两盏指示灯亮起一绿一青。
 * 深色图标的底板是纯黑，幽灵换成浅米色，服务器压暗一档。
 */

/**
 * 服务器的颜色：server 是机身自上而下的两个色标，serverShade 是机身下缘的暗部与落在机身上的影子，
 * slot 是盘位槽与灭着的指示灯；深色图标压暗一档。
 */
const HIDE_AND_SEEK_COLORS = {
    default: { server: ['#9A89FF', '#6453E8'], serverShade: '#3A2CAE', slot: '#1F1752' },
    dark: { server: ['#8170EA', '#4E3FCE'], serverShade: '#2A1F92', slot: '#150F3A' },
};

/** 亮着的两盏指示灯：一绿一青，两种图标相同。 */
const HIDE_AND_SEEK_LEDS = ['#46E08A', '#4FD6FF'];

/** 探身的机架上的分支符号：line 是连线，node 是节点，core 是节点中心的浅色。 */
const HIDE_AND_SEEK_BRANCH = { line: '#F4572F', node: '#F66038', core: '#FFE3D0' };

/** 侧身的幽灵两只眼睛在自身坐标里的位置，望向右边；远处的一只略小、略高。 */
const HIDE_AND_SEEK_EYES = [{ u: 79, v: 240 }, { u: 197, v: 234, size: 0.92 }];

/**
 * 探身的入口：幽灵正面从两层的机架后升起来，举起两只小手；机架上有分支符号。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 */
async function paintRiseIcon(context, scale, pixels, style, lit) {
    const pose = ghostPose({ top: [512, 150], scale: 0.95, lean: [0, 0] });
    const arm = (side) => ({
        line: [pose.place(side * 190, 428), pose.place(side * 304, 404), pose.place(side * 372, 322)],
        from: 128,
        to: 82,
    });
    const rack = { left: 172, width: 680, height: 150, tops: [556, 720] };
    const [upper, lower] = rack.tops;
    const trunk = rack.left + 104;
    const twig = rack.left + 212;

    const stars = starsMarkup([
        { x: 130, y: 170, size: 28, color: ARMFUL_PURPLES[2] },
        { x: 900, y: 150, size: 18, color: ARMFUL_PURPLES[1] },
    ]);

    await paintHideAndSeekIcon(context, scale, pixels, style, lit, stars, [
        steadyGhostSticker({
            pose,
            hands: [arm(-1), arm(1)],
            eyes: [{ u: -66, v: 236, tilt: 0 }, { u: 66, v: 236, tilt: 0 }],
        }),
        ...rack.tops.map((top) => serverSticker({
            x: rack.left,
            y: top,
            width: rack.width,
            height: rack.height,
            slot: { x: rack.left + 304, width: 210, height: 26 },
            leds: [rack.left + 572, rack.left + 622],
            ledRadius: 17,
        })),
        branchMarkSticker({
            trunk: [[trunk, upper + 75], [trunk, lower + 75]],
            twig: [[twig, upper + 75], [twig, upper + 142], [trunk, upper + 118], [trunk, lower + 44]],
            nodes: [[trunk, upper + 75], [trunk, lower + 75], [twig, upper + 75]],
        }),
    ]);
}

/**
 * 身前的入口：三层的机架整面立在后面，幽灵侧身浮在它前面，一只小手抬向右边的指示灯；
 * 最上面一台的盘位槽从幽灵的头后面穿过去，两头都露在外面。参数见 paintRiseIcon。
 */
async function paintFrontIcon(context, scale, pixels, style, lit) {
    const pose = ghostPose({ top: [424, 250], scale: 0.9, lean: [7, 2] });
    const ghost = steadyGhostSticker({
        pose,
        hands: [{ line: [pose.place(196, 430), pose.place(300, 412), pose.place(356, 356)], from: 116, to: 76 }],
        eyes: HIDE_AND_SEEK_EYES,
    });
    const rack = { left: 132, width: 760, height: 196, tops: [176, 386, 596] };

    await paintHideAndSeekIcon(context, scale, pixels, style, lit, '', [
        ...rack.tops.map((top, index) => serverSticker({
            x: rack.left,
            y: top,
            width: rack.width,
            height: rack.height,
            slot: index ? undefined : { x: rack.left + 88.67, width: 400, height: 37.47 },
            leds: [rack.left + 608, rack.left + 672],
            ledRadius: 21,
            shadows: [{ shape: ghost.outline, dx: 10, dy: 16, opacity: 0.6 }],
        })),
        ghost,
    ]);
}

/**
 * 藏身的入口：一座四层的机柜立在左边，幽灵从它背后歪着身子探出来、望向机柜，一只小手扒着机柜的边。参数见 paintRiseIcon。
 */
async function paintHideIcon(context, scale, pixels, style, lit) {
    const cabinet = { left: 132, width: 340, height: 164, tops: [176, 354, 532, 710] };
    const paw = taperData([[548, 592], [478, 612], [436, 610]], 104, 80);

    const stars = starsMarkup([
        { x: 900, y: 190, size: 24, color: ARMFUL_PURPLES[2] },
        { x: 560, y: 150, size: 16, color: ARMFUL_PURPLES[1] },
    ]);

    await paintHideAndSeekIcon(context, scale, pixels, style, lit, stars, [
        steadyGhostSticker({
            pose: ghostPose({ top: [720, 236], scale: 0.92, lean: [20, 3] }),
            eyes: [{ u: -18, v: 244, tilt: -6 }, { u: -130, v: 240, size: 0.92, tilt: -6 }],
        }),
        ...cabinet.tops.map((top) => serverSticker({
            x: cabinet.left,
            y: top,
            width: cabinet.width,
            height: cabinet.height,
            slot: { x: cabinet.left + 36, width: 96, height: 26 },
            leds: [cabinet.left + 172, cabinet.left + 220],
            ledRadius: 17,
            shadows: [{ shape: (fill) => `<path d="${paw}" fill="${fill}"/>`, dx: -4, dy: 10, opacity: 0.6 }],
        })),
        pawSticker({ data: paw, fade: [580, 0, 470, 0] }),
    ]);
}

/**
 * 显形的入口：底下一台服务器往上投出一束光，幽灵在光里浮着。参数见 paintRiseIcon。
 */
async function paintRevealIcon(context, scale, pixels, style, lit) {
    const server = { x: 212, y: 780, width: 600, height: 136 };

    const backdrop = beamMarkup({ base: [372, 652], mouth: [40, 984], bottom: 800, top: 60 })
        + starsMarkup([
            { x: 196, y: 340, size: 22, color: '#FFFFFF' },
            { x: 828, y: 236, size: 16, color: '#FFFFFF' },
            { x: 790, y: 560, size: 12, color: ARMFUL_PURPLES[2] },
        ]);

    await paintHideAndSeekIcon(context, scale, pixels, style, lit, backdrop, [
        serverSticker({
            ...server,
            slot: { x: server.x + 70, width: 230, height: 26 },
            leds: [server.x + 454, server.x + 508],
            ledRadius: 17,
        }),
        steadyGhostSticker({
            pose: ghostPose({ top: [500, 138], scale: 0.8, lean: [6, -3] }),
            eyes: HIDE_AND_SEEK_EYES,
        }),
    ]);
}

/**
 * 画出躲猫猫的一组：画面先铺满一张画布，再整张填进底板。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 * @param {string} backdrop 贴纸身后的背景，满幅坐标下的 SVG 片段
 * @param {object[]} stickers 共用一圈贴纸边的各块贴纸，从后往前
 */
async function paintHideAndSeekIcon(context, scale, pixels, style, lit, backdrop, stickers) {
    const palette = { ...ARMFUL_PALETTES[style], ...HIDE_AND_SEEK_COLORS[style] };
    const markup = armfulCharcoalMarkup(palette) + backdrop + stickerClusterMarkup(palette, lit, stickers);

    drawPlateScene(context, scale, await stickerScene(pixels, markup), palette.plate[2]);
}

/**
 * 眼睛始终是竖椭圆的幽灵：连着服务器时不换成四角星。参数见 ghostSticker。
 *
 * @param {object} options
 * @returns {{defs: string, outline: (fill: string) => string, paint: (palette: object) => string}}
 */
function steadyGhostSticker(options) {
    const ghost = ghostSticker(options);

    return { ...ghost, paint: (palette) => ghost.paint(palette, false) };
}

/**
 * 一台服务器的贴纸：圆角的机身自上而下由浅到深，下缘一道暗部；正面一条盘位槽、两盏指示灯，亮着时一绿一青、各带一圈光。
 *
 * @param {object} options
 * @param {number} options.x 左边的 x
 * @param {number} options.y 上边的 y
 * @param {number} options.width 宽度
 * @param {number} options.height 高度
 * @param {{x: number, width: number, height: number}} [options.slot] 盘位槽：左边的 x 与宽高，竖直居中
 * @param {number[]} options.leds 两盏指示灯圆心的 x，竖直居中
 * @param {number} options.ledRadius 指示灯的半径
 * @param {{shape: (fill: string) => string, dx: number, dy: number, opacity: number}[]} [options.shadows] 别的东西落在机身上的影子
 * @returns {{defs: string, outline: (fill: string) => string, paint: (palette: object, lit: boolean) => string}}
 */
function serverSticker({ x, y, width, height, slot, leds, ledRadius, shadows = [] }) {
    const id = stickerId('server');
    const middle = y + height / 2;
    const rect = (fill) => `<rect x="${x}" y="${y}" width="${width}" height="${height}" rx="${height * 0.23}" fill="${fill}"/>`;
    const lamp = (index, fill) => `<circle cx="${leds[index]}" cy="${middle}" r="${ledRadius}" fill="${fill}"/>`;

    return {
        defs: '',
        outline: rect,
        paint(palette, lit) {
            const lamps = leds.map((_, index) => (lit
                ? svgBlurred(`${id}-glow-${index}`, lamp(index, HIDE_AND_SEEK_LEDS[index]), { blur: ledRadius * 0.9, gain: 1.4, opacity: 0.9 })
                    + lamp(index, HIDE_AND_SEEK_LEDS[index])
                : lamp(index, palette.slot))).join('');

            return svgLinear(`${id}-fill`, [0, y, 0, y + height], palette.server)
                + svgMasked(
                    `${id}-inside`,
                    rect('#fff'),
                    `<rect ${SVG_WIDE} fill="url(#${id}-fill)"/>`
                    + svgInnerBand(`${id}-shade`, rect('#000'), { color: palette.serverShade, dx: 0, dy: -10, blur: 10, gain: 1.2, opacity: 0.55 })
                    + shadows.map(({ shape, dx, dy, opacity }, index) => svgBlurred(
                        `${id}-shadow-${index}`,
                        shape(palette.serverShade),
                        { dx, dy, blur: 14, opacity },
                    )).join('')
                    + (slot
                        ? `<rect x="${slot.x}" y="${middle - slot.height / 2}" width="${slot.width}" height="${slot.height}" `
                            + `rx="${slot.height / 2}" fill="${palette.slot}"/>`
                        : '')
                    + lamps,
                );
        },
    };
}

/**
 * 压在别的东西上的一只小手：根部淡入身体，到手尖才是实的。
 *
 * @param {object} options
 * @param {string} options.data 手的路径数据
 * @param {number[]} options.fade 淡入的方向 [x1, y1, x2, y2]：从根部到手尖
 * @returns {{defs: string, outline: (fill: string) => string, paint: (palette: object) => string}}
 */
function pawSticker({ data, fade }) {
    const id = stickerId('paw');

    return {
        defs: '',
        outline: (fill) => `<path d="${data}" fill="${fill}"/>`,
        paint(palette) {
            return svgLinear(id, fade, [[0, palette.hand[0], 0], [0.5, palette.hand[0], 0.85], [0.7, palette.hand[0]], [1, palette.hand[1]]])
                + `<path d="${data}" fill="url(#${id})"/>`;
        },
    };
}

/**
 * 画在机架上的分支符号：主干竖贯两台服务器，支线从右上方汇入；不带贴纸边。
 *
 * @param {object} options
 * @param {number[][]} options.trunk 主干的两端
 * @param {number[][]} options.twig 支线的起点、两个控制点与终点
 * @param {number[][]} options.nodes 各个节点的圆心
 * @returns {{defs: string, outline: () => string, paint: () => string}}
 */
function branchMarkSticker({ trunk, twig, nodes }) {
    const [from, control1, control2, to] = twig;
    const lines = `M${trunk[0]}L${trunk[1]}M${from}C${control1} ${control2} ${to}`;

    return {
        defs: '',
        outline: () => '',
        paint() {
            return `<path d="${lines}" fill="none" stroke="${HIDE_AND_SEEK_BRANCH.line}" stroke-width="20" stroke-linecap="round"/>`
                + nodes.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="28" fill="${HIDE_AND_SEEK_BRANCH.node}"/>`
                    + `<circle cx="${x}" cy="${y}" r="12" fill="${HIDE_AND_SEEK_BRANCH.core}"/>`).join('');
        },
    };
}

/**
 * 从服务器往上投出的一束光：下窄上宽，自下而上淡出；中间一束更亮的光芯。
 *
 * @param {object} options
 * @param {number[]} options.base 光束底边的左右两端的 x
 * @param {number[]} options.mouth 光束顶边的左右两端的 x
 * @param {number} options.bottom 底边的 y
 * @param {number} options.top 顶边的 y
 * @returns {string} 满幅坐标下的 SVG 片段
 */
function beamMarkup({ base, mouth, bottom, top }) {
    // 光芯的两侧各往里收光束宽度的 shrink 倍。
    const cone = (shrink) => {
        const inset = (mouth[1] - mouth[0]) * shrink;
        const foot = (base[1] - base[0]) * shrink;

        return `M${base[0] + foot},${bottom}L${base[1] - foot},${bottom}L${mouth[1] - inset},${top}L${mouth[0] + inset},${top}Z`;
    };

    return svgLinear('beam', [0, bottom, 0, top], [[0, ARMFUL_PURPLES[1], 0.8], [0.55, ARMFUL_PURPLES[0], 0.42], [1, ARMFUL_PURPLES[0], 0]])
        + svgLinear('beam-core', [0, bottom, 0, top], [[0, ARMFUL_PURPLES[2], 0.7], [0.6, ARMFUL_PURPLES[1], 0.22], [1, ARMFUL_PURPLES[1], 0]])
        + svgBlurred('beam-soft', `<path d="${cone(0)}" fill="url(#beam)"/>`, { blur: 5, opacity: 1 })
        + svgBlurred('beam-core-soft', `<path d="${cone(0.2)}" fill="url(#beam-core)"/>`, { blur: 14, opacity: 1 });
}
