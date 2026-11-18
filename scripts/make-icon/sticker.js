/**
 * 各组共用的贴纸画法：炭黑底板上，幽灵与它身边的物件共用一圈奶油白的贴纸边。
 * 柔边、暗部与投影靠模糊与蒙版画出，WebKit 的 Canvas 2D 没有滤镜，所以画面先拼成 SVG、再画进 Canvas。
 *
 * 满怀之外各组的画面由一块块贴纸拼成：每块给出 defs（滤镜的定义）、outline(fill)（染成一种颜色的剪影）
 * 与 paint(palette, lit)（成品），由 paintStickerIcon 从后往前叠起来。配色、满月、四角星眼与贴纸边的宽度照 armful.js。
 * 坐标都是满幅坐标：1024 见方，整体缩进底板。
 */

/** 树枝的颜色：branch 是自上而下的两个色标，bark 是枝的暗部与落在枝上的影子；深色图标压暗一档。 */
const STICKER_BRANCH_COLORS = {
    default: { branch: ['#A67A60', '#7B5443'], bark: '#553629' },
    dark: { branch: ['#93694F', '#6A4737'], bark: '#462B21' },
};

/** 幽灵直立时右半边的轮廓锚点 [u, v]：原点在头顶，u 向右、v 向下。 */
const STICKER_GHOST_SIDE = [[0, 0], [155, 54], [246, 192], [280, 352], [289, 512], [258, 622]];

/** 幽灵直立时头顶到下摆最低处的距离，下摆的瓣数，以及瓣与瓣之间的凹口比瓣底高出的量。 */
const STICKER_GHOST_HEM = { length: 666, lobes: 3, notch: 32 };

/** 幽灵近处那只眼睛的两个半轴，以及眼睛相对身体顺时针转的度数。 */
const STICKER_GHOST_EYE = { radiusX: 30, radiusY: 48.6, tilt: 6 };

/** 幽灵身上径向渐变的圆心相对自身坐标 (0, 250) 处的偏移与半径，都按幽灵的大小缩放；受光处在头的右上。 */
const STICKER_GHOST_LIGHT = { dx: 41, dy: -116, radius: 681.36 };

/** 贴纸的 id 用到的流水号。 */
let stickerSerial = 0;

/**
 * 画出一张由贴纸拼成的图标：画面先铺满一张画布，再整张填进底板。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 幽灵的眼睛是否亮成四角星
 * @param {string} backdrop 贴纸身后的背景，满幅坐标下的 SVG 片段
 * @param {object[]} stickers 共用一圈贴纸边的各块贴纸，从后往前
 */
async function paintStickerIcon(context, scale, pixels, style, lit, backdrop, stickers) {
    const palette = { ...ARMFUL_PALETTES[style], ...STICKER_BRANCH_COLORS[style] };
    const markup = armfulCharcoalMarkup(palette) + backdrop + stickerClusterMarkup(palette, lit, stickers);

    drawPlateScene(context, scale, await stickerScene(pixels, markup), palette.plate[2]);
}

/**
 * 共用一圈贴纸边的一团贴纸，贴纸在底板上落一片柔和的影子。
 *
 * @param {object} palette 所画图标的配色
 * @param {boolean} lit 幽灵的眼睛是否亮成四角星
 * @param {object[]} stickers 各块贴纸，从后往前
 * @returns {string} 满幅坐标下的 SVG 片段
 */
function stickerClusterMarkup(palette, lit, stickers) {
    const id = stickerId('cluster');

    // 各块的剪影往外描粗一圈：染成贴纸边的颜色就是贴纸边，染成影子的颜色再模糊就是贴纸的投影。
    const silhouette = (color) => `<g stroke="${color}" stroke-width="${ARMFUL_POSE.edge * 2}" stroke-linejoin="round" stroke-linecap="round">`
        + stickers.map((sticker) => sticker.outline(color)).join('')
        + '</g>';

    return stickers.map((sticker) => sticker.defs).join('')
        + svgBlurred(`${id}-shadow`, silhouette(palette.cast), { dx: 6, dy: 14, blur: 24, opacity: 0.5 })
        + silhouette(palette.edge)
        + stickers.map((sticker) => sticker.paint(palette, lit)).join('');
}

/**
 * 幽灵的贴纸：身体与从身上顶出来的小手修圆成一条轮廓，受光处在头的右上，轮廓内侧一道淡色；
 * 眼睛是纯色的竖椭圆，亮着时换成四角星。
 *
 * @param {object} options
 * @param {{scale: number, place: Function, degrees: Function}} options.pose 姿态，见 ghostPose
 * @param {{line: number[][], from: number, to: number}[]} [options.hands] 小手：渐细的笔画，画面坐标下
 * @param {{u: number, v: number, size?: number, tilt?: number}[]} options.eyes 眼睛在幽灵自身坐标里的位置，size 是相对近处那只的大小，
 *     tilt 是相对身体顺时针转的度数，省略时照 STICKER_GHOST_EYE
 * @returns {{defs: string, outline: (fill: string) => string, paint: (palette: object, lit: boolean) => string}}
 */
function ghostSticker({ pose, hands = [], eyes }) {
    const id = stickerId('ghost');
    const path = (data, fill) => `<path d="${data}" fill="${fill}"/>`;
    const body = blobData(ghostOutline().map(([u, v]) => pose.place(u, v)));
    const handData = hands.map(({ line, from, to }) => taperData(line, from, to));
    const shape = (fill) => `<g filter="url(#${id}-rounding)">${path(body, fill)}${handData.map((data) => path(data, fill)).join('')}</g>`;

    const [anchorX, anchorY] = pose.place(0, 250);
    const light = STICKER_GHOST_LIGHT;

    // 眼睛跟着身体在那里的走向转。
    const ovals = eyes.map(({ u, v, size = 1, tilt = STICKER_GHOST_EYE.tilt }) => {
        const [x, y] = pose.place(u, v);

        return {
            x,
            y,
            radiusX: STICKER_GHOST_EYE.radiusX * size * pose.scale,
            radiusY: STICKER_GHOST_EYE.radiusY * size * pose.scale,
            tilt: pose.degrees(v) + tilt,
        };
    });

    const ovalMarkup = (fill) => ovals
        .map(({ x, y, radiusX, radiusY, tilt }) => `<ellipse cx="${x}" cy="${y}" rx="${radiusX}" ry="${radiusY}" `
            + `transform="rotate(${tilt} ${x} ${y})" fill="${fill}"/>`)
        .join('');

    // 四角星：同色的圆头描边把四个角尖修圆。
    const sparkleMarkup = (fill) => ovals
        .map(({ x, y, radiusX, radiusY, tilt }) => `<path d="${sparkleData(x, y, radiusX * ARMFUL_SPARKLES.reachX, radiusY * ARMFUL_SPARKLES.reachY)}" `
            + `transform="rotate(${tilt} ${x} ${y})" fill="${fill}" `
            + `stroke="${fill}" stroke-width="${ARMFUL_SPARKLES.rounding * pose.scale}" stroke-linejoin="round"/>`)
        .join('');

    return {
        defs: svgRounding(`${id}-rounding`, ARMFUL_SEAM),
        outline: shape,
        paint(palette, lit) {
            const eyesMarkup = lit
                ? svgBlurred(`${id}-eye-glow`, sparkleMarkup(ARMFUL_LIT.eyeGlow), { blur: 16, opacity: 0.75 })
                    + `<linearGradient id="${id}-eye" x1="0" y1="0" x2="0" y2="1">${svgStops(ARMFUL_LIT.eye)}</linearGradient>`
                    + sparkleMarkup(`url(#${id}-eye)`)
                : ovalMarkup(palette.eye);

            return svgRadial(
                `${id}-light`,
                anchorX + light.dx * pose.scale,
                anchorY + light.dy * pose.scale,
                light.radius * pose.scale,
                [[0, palette.ghost[0]], [0.46, palette.ghost[1]], [0.74, palette.ghost[2]], [1, palette.ghost[3]]],
            )
                + svgMasked(
                    `${id}-inside`,
                    shape('#fff'),
                    `<rect ${SVG_WIDE} fill="url(#${id}-light)"/>`
                    + svgInnerBand(`${id}-rim`, shape('#000'), { color: palette.rim, blur: 9, gain: 1.6, opacity: 0.8 }),
                )
                + eyesMarkup;
        },
    };
}

/**
 * 一颗樱桃的贴纸：平涂的圆，上面可以有别的东西落下的短影。
 *
 * @param {object} options
 * @param {number} options.x 圆心的 x
 * @param {number} options.y 圆心的 y
 * @param {number} options.radius 半径
 * @param {{shape: (fill: string) => string, dx: number, dy: number, opacity: number}[]} [options.shadows]
 *     短影：shape 是投下影子的形体，dx 与 dy 是影子挪开的量，opacity 是不透明度
 * @returns {{defs: string, outline: (fill: string) => string, paint: (palette: object) => string}}
 */
function cherrySticker({ x, y, radius, shadows = [] }) {
    const id = stickerId('cherry');
    const disc = discShape({ x, y, radius });

    return {
        defs: '',
        outline: disc,
        paint(palette) {
            return svgMasked(
                `${id}-inside`,
                disc('#fff'),
                `<rect ${SVG_WIDE} fill="${palette.cherry}"/>`
                + shadows.map(({ shape, dx, dy, opacity }, index) => svgBlurred(
                    `${id}-shadow-${index}`,
                    shape(palette.wine),
                    { dx, dy, blur: 16, opacity },
                )).join(''),
            );
        },
    };
}

/**
 * 樱桃梗的贴纸：从分叉处的结垂下几根渐细的梗，自上而下由浅到深。
 *
 * @param {object} options
 * @param {number[][][]} options.lines 各根梗的中线经过的点，都从结出发
 * @param {{x: number, y: number, radius: number}} options.knot 分叉处的结
 * @returns {{defs: string, outline: (fill: string) => string, paint: (palette: object) => string}}
 */
function stemSticker({ lines, knot }) {
    const id = stickerId('stem');
    const tapers = lines.map((line) => taperData(line, 13.6, 11.6));
    const ys = lines.flat().map(([, y]) => y);

    const shape = (fill) => tapers.map((data) => `<path d="${data}" fill="${fill}"/>`).join('') + discShape(knot)(fill);

    return {
        defs: '',
        outline: shape,
        paint(palette) {
            return svgLinear(id, [0, Math.min(...ys), 0, Math.max(...ys)], palette.stem) + shape(`url(#${id})`);
        },
    };
}

/**
 * 一片叶子的贴纸：两头圆钝的叶形，平涂，右下是暗部，上面压一道叶脉。
 *
 * @param {object} options
 * @param {number[]} options.from 叶柄一头的位置
 * @param {number[]} options.to 叶尖的位置
 * @returns {{defs: string, outline: (fill: string) => string, paint: (palette: object) => string}}
 */
function leafSticker({ from, to }) {
    const id = stickerId('leaf');
    const length = distanceBetween(from, to);

    // 二次曲线的顶点只到控制点偏移量的一半，控制点要推出两倍拱高。
    const data = lensData(from, to, length * ARMFUL_LEAF.bulge * 2);
    const along = (t) => [from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t];

    // 叶脉的粗细跟着叶长走，比例照满怀的叶子。
    const vein = taperData([along(0.13), along(0.84)], (11 * length) / 92, (8 * length) / 92);
    const shape = (fill) => `<g filter="url(#${id}-rounding)"><path d="${data}" fill="${fill}"/></g>`;

    return {
        defs: svgRounding(`${id}-rounding`, ARMFUL_LEAF.rounding),
        outline: shape,
        paint(palette) {
            return svgMasked(
                `${id}-inside`,
                shape('#fff'),
                `<rect ${SVG_WIDE} fill="${palette.leaf}"/>`
                + svgInnerBand(`${id}-shade`, shape('#000'), { color: palette.leafShade, dx: -7.07, dy: -7.07, blur: 16, gain: 1.25, opacity: 1 }),
            )
                + `<path d="${vein}" fill="${palette.vein}"/>`;
        },
    };
}

/**
 * 一根树枝的贴纸：渐细的枝，自上而下由浅到深，下缘一道暗部，上面可以有别的东西落下的影子。
 *
 * @param {object} options
 * @param {number[][]} options.line 中线经过的点
 * @param {number} options.from 起点处的粗细
 * @param {number} options.to 终点处的粗细
 * @param {((fill: string) => string)[]} [options.shadows] 在枝上投下影子的形体
 * @returns {{defs: string, outline: (fill: string) => string, paint: (palette: object) => string}}
 */
function branchSticker({ line, from, to, shadows = [] }) {
    const id = stickerId('branch');
    const data = taperData(line, from, to);
    const shape = (fill) => `<g filter="url(#${id}-rounding)"><path d="${data}" fill="${fill}"/></g>`;
    const ys = line.map(([, y]) => y);

    return {
        defs: svgRounding(`${id}-rounding`, 12),
        outline: shape,
        paint(palette) {
            return svgLinear(`${id}-fill`, [0, Math.min(...ys) - 40, 0, Math.max(...ys) + 40], palette.branch)
                + svgMasked(
                    `${id}-inside`,
                    shape('#fff'),
                    `<rect ${SVG_WIDE} fill="url(#${id}-fill)"/>`
                    + svgInnerBand(`${id}-shade`, shape('#000'), { color: palette.bark, dx: 0, dy: -12, blur: 12, gain: 1.2, opacity: 0.5 })
                    + shadows.map((shadow, index) => svgBlurred(
                        `${id}-shadow-${index}`,
                        shadow(palette.bark),
                        { dx: 0, dy: 16, blur: 14, opacity: 0.6 },
                    )).join(''),
                );
        },
    };
}

/**
 * 从一个结垂下的一对樱桃的两根梗：每根从结出发，微弯着落到樱桃的顶上。
 *
 * @param {{x: number, y: number}} knot 分叉处的结
 * @param {{x: number, y: number, radius: number}} near 近处的樱桃
 * @param {{x: number, y: number, radius: number}} far 远处的樱桃
 * @returns {number[][][]} 两根梗的中线经过的点
 */
function cherryStemLines(knot, near, far) {
    return [
        [[knot.x, knot.y], [(knot.x + near.x) / 2 + 6, (knot.y + near.y - near.radius) / 2], [near.x + 6, near.y - near.radius + 6]],
        [[knot.x, knot.y], [(knot.x + far.x) / 2 + 8, (knot.y + far.y - far.radius) / 2], [far.x, far.y - far.radius + 6]],
    ];
}

/**
 * 紫色的满月与四角星：一轮自上而下由浅到深的满月，四周一圈紫光，旁边几颗四角星。
 *
 * @param {{x: number, y: number, radius: number}} moon 满月的圆心与半径
 * @param {{x: number, y: number, size: number, color: string}[]} stars 每颗四角星的中心、从中心到角尖的长度与颜色
 * @returns {string} 满幅坐标下的 SVG 片段
 */
function moonMarkup(moon, stars) {
    const id = stickerId('moon');
    const disc = discShape(moon);

    return svgLinear(id, [0, moon.y - moon.radius, 0, moon.y + moon.radius], [...ARMFUL_PURPLES].reverse())
        + svgBlurred(`${id}-glow`, disc(ARMFUL_PURPLES[0]), { blur: 40, opacity: 0.5 })
        + disc(`url(#${id})`)
        + starsMarkup(stars);
}

/**
 * 几颗四角星：四个角尖之间的边往中心收成弧。
 *
 * @param {{x: number, y: number, size: number, color: string}[]} stars 每颗四角星的中心、从中心到角尖的长度与颜色
 * @returns {string} 满幅坐标下的 SVG 片段
 */
function starsMarkup(stars) {
    return stars
        .map(({ x, y, size, color }) => `<path d="M${x},${y - size}Q${x},${y} ${x + size},${y}Q${x},${y} ${x},${y + size}`
            + `Q${x},${y} ${x - size},${y}Q${x},${y} ${x},${y - size}Z" fill="${color}"/>`)
        .join('');
}

/**
 * 幽灵的姿态：一条从头顶往下的脊线，倾角从头部的 lean[0] 平滑过渡到下摆处的 lean[1]。
 *
 * @param {object} options
 * @param {number[]} options.top 头顶在画面里的位置
 * @param {number} options.scale 幽灵的大小，1 是自身坐标的原大
 * @param {number[]} options.lean 脊线在头部与下摆处的倾角，度，正值是头往右歪
 * @returns {{scale: number, place: (u: number, v: number) => number[], degrees: (v: number) => number}}
 *     place 给出自身坐标里的点在画面里的位置，degrees 给出 v 处身体顺时针转过的度数
 */
function ghostPose({ top, scale, lean }) {
    const { length } = STICKER_GHOST_HEM;
    const step = 2;
    const count = Math.ceil((length + 120) / step);
    const frames = [];
    let [x, y] = top;

    // 脊线按自身坐标里每 2 个单位走一步，下摆以下沿最后的走向直着延伸。
    for (let index = 0; index <= count; index += 1) {
        const t = Math.min((index * step) / length, 1);
        const degrees = lean[0] + (lean[1] - lean[0]) * t * t * (3 - 2 * t);
        const angle = (degrees * Math.PI) / 180;

        frames.push({ x, y, angle, degrees });
        x -= Math.sin(angle) * step * scale;
        y += Math.cos(angle) * step * scale;
    }

    const frame = (v) => frames[Math.max(0, Math.min(count, Math.round(v / step)))];

    return {
        scale,
        place(u, v) {
            const { x: spineX, y: spineY, angle } = frame(v);
            return [spineX + Math.cos(angle) * u * scale, spineY + Math.sin(angle) * u * scale];
        },
        degrees: (v) => frame(v).degrees,
    };
}

/**
 * 幽灵直立时的轮廓锚点，顺时针：头顶、右侧、下摆、左侧。
 *
 * @returns {number[][]} 自身坐标里的 [u, v]
 */
function ghostOutline() {
    const { length, lobes, notch } = STICKER_GHOST_HEM;
    const corner = STICKER_GHOST_SIDE[STICKER_GHOST_SIDE.length - 1][0];
    const step = corner / lobes;
    const hem = [];

    // 下摆从右到左，交替是垂下的瓣底与瓣之间的凹口。
    for (let index = 1; index < lobes * 2; index += 1) {
        hem.push([corner - index * step, index % 2 ? length : length - notch]);
    }

    return [...STICKER_GHOST_SIDE, ...hem, ...STICKER_GHOST_SIDE.slice(1).reverse().map(([u, v]) => [-u, v])];
}

/**
 * 染成某种颜色的圆的 SVG 片段。
 *
 * @param {{x: number, y: number, radius: number}} disc 圆心与半径
 * @returns {(fill: string) => string}
 */
function discShape({ x, y, radius }) {
    return (fill) => `<circle cx="${x}" cy="${y}" r="${radius}" fill="${fill}"/>`;
}

/**
 * 一块贴纸在 SVG 里用的 id，每次调用都不同。
 *
 * @param {string} name id 的前缀
 * @returns {string}
 */
function stickerId(name) {
    stickerSerial += 1;
    return `${name}-${stickerSerial}`;
}

/**
 * 贴纸画法的画面，铺满整张画布：满幅的画面整体缩进底板的范围。
 *
 * 画面先按 1024 px 画出，再逐级减半缩到导出尺寸：修圆轮廓的滤镜按这一尺寸收出约一个像素宽的边，直接按小尺寸画会出锯齿。
 * WebKit 画 SVG 滤镜时的舍入不固定：同一份 SVG 每次画出的 1024 px 画面可能有几个像素差一个色阶（macOS 27 实测）。
 *
 * @param {number} pixels 导出图片的边长
 * @param {string} markup 满幅坐标下的 SVG 片段：背景与贴纸
 * @returns {Promise<HTMLCanvasElement>}
 */
async function stickerScene(pixels, markup) {
    const inset = `translate(${PLATE_ORIGIN} ${PLATE_ORIGIN}) scale(${PLATE_SIZE / GRID})`;

    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${GRID}" height="${GRID}" viewBox="0 0 ${GRID} ${GRID}">`
        + `<g transform="${inset}">${markup}</g></svg>`;

    const image = new Image();
    image.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
    await image.decode();

    let scene = paintScene(GRID, (context) => context.drawImage(image, 0, 0, GRID, GRID));

    while (scene.width > pixels) {
        const larger = scene;
        const size = Math.max(pixels, larger.width / 2);
        scene = paintScene(size, (context) => context.drawImage(larger, 0, 0, GRID, GRID));
    }

    return scene;
}

/** SVG 里蒙版与滤镜的作用范围：比画面大一圈，容纳画面之外的底色与模糊。 */
const SVG_WIDE = 'x="-200" y="-200" width="1424" height="1424"';

/**
 * SVG 渐变的色标。
 *
 * @param {(string | [number, string, number?])[]} stops 颜色，均匀分布；或 [位置, 颜色, 不透明度]，不透明度省略为 1
 * @returns {string}
 */
function svgStops(stops) {
    return stops
        .map((stop, index) => {
            const [offset, color, opacity = 1] = Array.isArray(stop) ? stop : [index / (stops.length - 1), stop];
            return `<stop offset="${offset}" stop-color="${color}" stop-opacity="${opacity}"/>`;
        })
        .join('');
}

/**
 * SVG 的线性渐变，坐标按所在的坐标系给出。
 *
 * @param {string} id 渐变的 id
 * @param {number[]} line 起点与终点 [x1, y1, x2, y2]
 * @param {(string | [number, string, number?])[]} stops 色标，见 svgStops
 * @returns {string}
 */
function svgLinear(id, [x1, y1, x2, y2], stops) {
    return `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">`
        + `${svgStops(stops)}</linearGradient>`;
}

/**
 * SVG 的同心径向渐变，坐标按所在的坐标系给出。
 *
 * @param {string} id 渐变的 id
 * @param {number} x 圆心的 x
 * @param {number} y 圆心的 y
 * @param {number} radius 外圈的半径
 * @param {(string | [number, string, number?])[]} stops 色标，见 svgStops
 * @returns {string}
 */
function svgRadial(id, x, y, radius, stops) {
    return `<radialGradient id="${id}" gradientUnits="userSpaceOnUse" cx="${x}" cy="${y}" r="${radius}">`
        + `${svgStops(stops)}</radialGradient>`;
}

/**
 * 把一段 SVG 内容裁在一个形体里面。
 *
 * @param {string} id 蒙版的 id
 * @param {string} shape 画成白色的形体
 * @param {string} content 裁在形体里面的内容
 * @returns {string}
 */
function svgMasked(id, shape, content) {
    return `<mask id="${id}" maskUnits="userSpaceOnUse" ${SVG_WIDE}>${shape}</mask>`
        + `<g mask="url(#${id})">${content}</g>`;
}

/**
 * 把一段 SVG 内容模糊成一片柔和的影子或光。
 *
 * @param {string} id 滤镜的 id
 * @param {string} content 要模糊的内容
 * @param {{dx?: number, dy?: number, blur: number, gain?: number, opacity: number}} options
 *     dx 与 dy 是模糊之前挪开的量，blur 是模糊的标准差，gain 是模糊之后透明度放大的倍数，opacity 是整片的不透明度
 * @returns {string}
 */
function svgBlurred(id, content, { dx = 0, dy = 0, blur, gain = 1, opacity }) {
    return `<filter id="${id}" filterUnits="userSpaceOnUse" ${SVG_WIDE} color-interpolation-filters="sRGB">`
        + `<feGaussianBlur stdDeviation="${blur}"/>`
        + `<feComponentTransfer><feFuncA type="linear" slope="${gain}"/></feComponentTransfer></filter>`
        + `<g opacity="${opacity}" filter="url(#${id})"><g transform="translate(${dx} ${dy})">${content}</g></g>`;
}

/**
 * 形体内侧沿着轮廓的一道柔边：亮边、暗部都是它。
 *
 * 把形体以外的区域染上颜色，往形体里挪一点再模糊；裁回形体内部由调用方完成。
 *
 * @param {string} id 这道柔边用到的蒙版与滤镜的 id 前缀
 * @param {string} hole 画成黑色的形体
 * @param {{color: string, dx?: number, dy?: number, blur: number, gain: number, opacity: number}} options
 *     color 是柔边的颜色，其余见 svgBlurred
 * @returns {string}
 */
function svgInnerBand(id, hole, { color, ...options }) {
    return `<mask id="${id}-outside" maskUnits="userSpaceOnUse" ${SVG_WIDE}><rect ${SVG_WIDE} fill="#fff"/>${hole}</mask>`
        + svgBlurred(`${id}-blur`, `<rect ${SVG_WIDE} fill="${color}" mask="url(#${id}-outside)"/>`, options);
}

/**
 * 把形体的尖角与接缝修圆的 SVG 滤镜：先模糊、再把透明度拉回硬边，凸角被修圆，相邻的形体在接缝处融成一条顺滑的轮廓。
 *
 * @param {string} id 滤镜的 id
 * @param {number} radius 修出的圆角半径
 * @returns {string}
 */
function svgRounding(id, radius) {
    // 直角被修出的圆角约为模糊标准差的 1.86 倍；斜率让拉回来的边保持约一个单位宽的过渡。
    const deviation = radius * 0.54;
    const slope = 2.3 * deviation;

    return `<filter id="${id}" filterUnits="userSpaceOnUse" ${SVG_WIDE} color-interpolation-filters="sRGB">`
        + `<feGaussianBlur stdDeviation="${deviation}"/>`
        + `<feComponentTransfer><feFuncA type="linear" slope="${slope}" intercept="${-(slope - 1) / 2}"/></feComponentTransfer>`
        + '</filter>';
}

/**
 * 眼睛亮成的四角星的 SVG 路径数据：四个角尖在中心的正上、正右、正下、正左，角尖之间的边按 ARMFUL_SPARKLES.pinch 往中心收。
 *
 * @param {number} x 中心的 x
 * @param {number} y 中心的 y
 * @param {number} reachX 左右两个角尖到中心的距离
 * @param {number} reachY 上下两个角尖到中心的距离
 * @returns {string}
 */
function sparkleData(x, y, reachX, reachY) {
    const waist = (signX, signY) => `${x + signX * reachX * ARMFUL_SPARKLES.pinch},${y + signY * reachY * ARMFUL_SPARKLES.pinch}`;

    return `M${x},${y - reachY}Q${waist(1, -1)} ${x + reachX},${y}Q${waist(1, 1)} ${x},${y + reachY}`
        + `Q${waist(-1, 1)} ${x - reachX},${y}Q${waist(-1, -1)} ${x},${y - reachY}Z`;
}

/**
 * 平滑穿过各锚点的闭合轮廓的 SVG 路径数据。
 *
 * @param {number[][]} points 轮廓依次经过的锚点
 * @returns {string}
 */
function blobData(points) {
    const curves = chordSpline(points, true);
    return `M${curves[0][0]}${curves.map(([, control1, control2, to]) => `C${control1} ${control2} ${to}`).join('')}Z`;
}

/**
 * 渐细笔画的 SVG 路径数据：沿一条平滑穿过各点的中线，粗细从一头过渡到另一头的实心形体。
 *
 * @param {number[][]} line 中线经过的点
 * @param {number} from 起点处的粗细
 * @param {number} to 终点处的粗细
 * @param {number} belly 中段额外鼓出的粗细
 * @returns {string}
 */
function taperData(line, from, to, belly = 0) {
    const center = [line[0]];

    for (const [start, control1, control2, end] of chordSpline(line, false)) {
        center.push(...cubicPoints(start, control1, control2, end, 12).slice(1));
    }

    const last = center.length - 1;
    const travelled = arcLengths(center);
    const left = [];
    const right = [];

    // 粗细按走过的路程插值；两条边是中线沿法线各往一侧挪半个粗细。
    center.forEach(([x, y], index) => {
        const before = center[Math.max(0, index - 1)];
        const after = center[Math.min(last, index + 1)];
        const length = Math.hypot(after[0] - before[0], after[1] - before[1]);
        const normalX = -(after[1] - before[1]) / length;
        const normalY = (after[0] - before[0]) / length;

        const along = travelled[index] / travelled[last];
        const half = Math.max(0, from + (to - from) * along + belly * Math.sin(Math.PI * along)) / 2;

        left.push([x + normalX * half, y + normalY * half]);
        right.push([x - normalX * half, y - normalY * half]);
    });

    // 端头：有粗细时画半圆收口，细到接近 0 时直接收成尖。
    const cap = (radius, target) => (radius > 0.4 ? `A${radius} ${radius} 0 0 0 ${target}` : `L${target}`);

    return `M${left.join('L')}${cap(to / 2, right[last])}`
        + `L${right.slice(0, last).reverse().join('L')}${cap(from / 2, left[0])}Z`;
}

/**
 * 平滑穿过各点的曲线：每相邻两点之间一段三次贝塞尔曲线。
 *
 * 手柄沿前后两点的连线，长度取本段弦长的三分之一，疏密不均的点也不会甩出鼓包。
 *
 * @param {number[][]} points 曲线依次经过的点
 * @param {boolean} closed 是否首尾相接
 * @returns {number[][][]} 各段的起点、两个控制点与终点
 */
function chordSpline(points, closed) {
    const count = points.length;

    // 闭合曲线首尾相接；不闭合的曲线在两端重复端点。
    const at = (index) => (closed
        ? points[((index % count) + count) % count]
        : points[Math.min(count - 1, Math.max(0, index))]);

    return Array.from({ length: closed ? count : count - 1 }, (_, index) => {
        const [before, from, to, after] = [at(index - 1), at(index), at(index + 1), at(index + 2)];
        const reach = distanceBetween(from, to) / 3;

        const handle = (start, end) => {
            const length = distanceBetween(start, end) || 1;
            return [((end[0] - start[0]) / length) * reach, ((end[1] - start[1]) / length) * reach];
        };

        const leaving = handle(before, to);
        const arriving = handle(from, after);

        return [
            from,
            [from[0] + leaving[0], from[1] + leaving[1]],
            [to[0] - arriving[0], to[1] - arriving[1]],
            to,
        ];
    });
}
