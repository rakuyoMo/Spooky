/**
 * 午夜：紫色夜空的满幅画面缩进底板，一只近黑色的大幽灵从右侧探身进来、被底板右边裁切，一只白色胶囊眼看向画面内。
 * 眼睛就是指示灯：App 连着服务器时，眼睛与周围的光晕亮起同一种琥珀色的光，平滑地淡入幽灵。
 * 深色图标的底板是纯黑，幽灵换成在黑底上清楚的紫色。
 */

/**
 * 午夜两种图标的配色：夜空自左上的 skyStart 斜向渐变到右下的 skyEnd，幽灵用 ghost。
 *
 * 默认图标是紫色夜空里一只近黑色的幽灵；深色图标的夜空是纯黑，幽灵换成在黑底上清楚的紫色。
 */
const MIDNIGHT_PALETTES = {
    default: {
        skyStart: '#A98BFF',
        skyEnd: '#3A1B8E',
        ghost: '#140F22',
    },
    dark: {
        skyStart: '#000000',
        skyEnd: '#000000',
        ghost: '#7B5CF0',
    },
};

/**
 * 午夜连着服务器时，眼睛与光晕的琥珀光。
 *
 * light 是眼睛边缘与光晕起点的颜色；deep 是光变暗时偏向的深橙，让光晕的外圈不发灰。
 */
const AMBER = {
    light: '#FFC453',
    deep: '#E8521F',
};

/** 午夜的幽灵放到满幅画面上的姿态：直立坐标的原点落在 (700, 560)，向左倾斜 18°，缩到 0.95 倍。 */
const MIDNIGHT_POSE = {
    x: 700,
    y: 560,
    degrees: -18,
    scale: 0.95,
};

/**
 * 午夜的幽灵，直立坐标下：圆顶头部、竖直两侧与三瓣下摆，由各圆依次以公切线连成，两个凹圆在相邻的两瓣之间收出内凹。
 * 放到画面上向左倾斜后，右侧被底板右边裁切。
 */
const MIDNIGHT_GHOST = belt([
    { x: 0, y: -180, radius: 330 },
    { x: 238, y: 300, radius: 92 },
    { x: 119, y: 306, radius: 26, concave: true },
    { x: 0, y: 300, radius: 92 },
    { x: -119, y: 306, radius: 26, concave: true },
    { x: -238, y: 300, radius: 92 },
]);

/** 午夜的眼睛，直立坐标下：头部左半边的竖向胶囊，x 是中线，top 与 bottom 是两端半圆的圆心。 */
const MIDNIGHT_EYE = {
    x: -125,
    top: -225,
    bottom: -110,
    radius: 44,
};

/** 午夜连着服务器时的光晕：直立坐标下以眼睛中心为圆心的椭圆，整个落在头部之内。 */
const MIDNIGHT_GLOW = {
    radiusX: 145,
    radiusY: 238,
};

/**
 * 午夜的入口：底板的投影与服务器幽灵相同；满幅的画面整体缩进底板、按底板裁切，幽灵的右侧随之被裁掉。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 */
function paintMidnightIcon(context, scale, pixels, style, lit) {
    const palette = MIDNIGHT_PALETTES[style];

    withShadow(context, scale, PLATE_SHADOW, () => {
        context.fillStyle = palette.skyEnd;
        context.fill(PLATE);
    });

    context.clip(PLATE);
    context.translate(PLATE_ORIGIN, PLATE_ORIGIN);
    context.scale(PLATE_SIZE / GRID, PLATE_SIZE / GRID);

    drawMidnightSky(context, palette);
    drawMidnightGhost(context, palette, lit);
}

/**
 * 午夜的夜空：铺满画面，自左上的 skyStart 斜向渐变到右下的 skyEnd。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到满幅画面的上下文
 * @param {{skyStart: string, skyEnd: string}} palette 所画图标的配色
 */
function drawMidnightSky(context, palette) {
    const gradient = context.createLinearGradient(0, 0, GRID, GRID);
    gradient.addColorStop(0, palette.skyStart);
    gradient.addColorStop(1, palette.skyEnd);

    context.fillStyle = gradient;
    context.fillRect(0, 0, GRID, GRID);
}

/**
 * 午夜的幽灵：剪影从右侧探身进来，一只胶囊眼看向画面内。
 *
 * 眼睛就是指示灯：亮着时，眼睛与周围的光晕是同一种琥珀色的光；
 * 光晕在椭圆边缘之前已淡入幽灵的颜色，看不出椭圆的边，眼睛与光晕以外的像素与灭着时相同。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到满幅画面的上下文
 * @param {{ghost: string}} palette 所画图标的配色
 * @param {boolean} lit 指示灯是否亮着
 */
function drawMidnightGhost(context, palette, lit) {
    const { x, top, bottom, radius } = MIDNIGHT_EYE;
    const center = { x, y: (top + bottom) / 2 };

    const eye = roundedRect(
        x - radius,
        top - radius,
        radius * 2,
        bottom - top + radius * 2,
        radius,
    );

    // 剪影、眼睛与光晕都在直立坐标里给出，先放到幽灵的姿态上再画。
    context.save();
    context.translate(MIDNIGHT_POSE.x, MIDNIGHT_POSE.y);
    context.rotate((MIDNIGHT_POSE.degrees * Math.PI) / 180);
    context.scale(MIDNIGHT_POSE.scale, MIDNIGHT_POSE.scale);

    context.fillStyle = palette.ghost;
    context.fill(MIDNIGHT_GHOST);

    if (lit) {
        // 光晕：从眼睛边缘的琥珀色衰减到幽灵的颜色。
        fillEllipticalGradient(
            context,
            ellipse(center.x, center.y, MIDNIGHT_GLOW.radiusX, MIDNIGHT_GLOW.radiusY),
            { ...center, ...MIDNIGHT_GLOW },
            glowStops(palette.ghost),
        );

        // 亮着的眼睛：中心是浅琥珀，边缘接上光晕起点的颜色；渐变椭圆的两个半轴是胶囊的半宽与含端帽的半长。
        fillEllipticalGradient(
            context,
            eye,
            { ...center, radiusX: radius, radiusY: (bottom - top) / 2 + radius },
            [
                [0, mixLight(AMBER.light, '#FFFFFF', 0.5)],
                [0.55, mixLight(AMBER.light, '#FFFFFF', 0.2)],
                [1, AMBER.light],
            ],
        );
    } else {
        context.fillStyle = '#FFFFFF';
        context.fill(eye);
    }

    context.restore();
}

/**
 * 午夜光晕的色标：眼睛边缘以内保持满亮度，之后按 (1 − t)^1.6 衰减，到椭圆 96% 处成为幽灵的颜色。
 * 亮度在线性光空间里与幽灵的颜色混合，光变暗的同时颜色偏向 AMBER.deep。
 *
 * @param {string} ghost 幽灵的颜色，光晕最后淡入的颜色
 * @returns {[number, string][]} 渐变的位置与颜色
 */
function glowStops(ghost) {
    const start = 0.27;
    const end = 0.96;
    const steps = 11;

    // 满亮度的一段之后，衰减段均分成 11 步，每步一个色标。
    const offsets = [
        0,
        start,
        ...Array.from({ length: steps }, (_, index) => start + ((end - start) * (index + 1)) / steps),
    ];

    const stops = offsets.map((offset) => {
        const t = Math.max(0, Math.min(1, (offset - start) / (end - start)));
        const intensity = (1 - t) ** 1.6;
        const color = mixLight(AMBER.deep, AMBER.light, intensity);

        return [offset, mixLight(ghost, color, intensity)];
    });

    return [...stops, [1, ghost]];
}

/**
 * 用椭圆的径向渐变填充路径；椭圆的两个半轴沿当前坐标的横向与竖向。
 *
 * @param {CanvasRenderingContext2D} context 绘图上下文
 * @param {Path2D} path 要填充的路径
 * @param {{x: number, y: number, radiusX: number, radiusY: number}} shape 渐变椭圆的中心与两个半轴
 * @param {[number, string][]} stops 渐变的位置与颜色，位置 0 在中心，1 在椭圆上
 */
function fillEllipticalGradient(context, path, shape, stops) {
    const squeeze = shape.radiusX / shape.radiusY;

    // Canvas 的径向渐变只有圆形：以椭圆中心为原点把坐标横向压扁，渐变就是半径为竖向半轴的圆。
    context.save();
    context.translate(shape.x, shape.y);
    context.scale(squeeze, 1);

    const gradient = context.createRadialGradient(0, 0, 0, 0, 0, shape.radiusY);

    for (const [offset, color] of stops) {
        gradient.addColorStop(offset, color);
    }

    // 路径先移到以椭圆中心为原点，再横向拉伸、抵消压扁，画出来仍是原来的形状与位置。
    const placed = new Path2D();
    placed.addPath(path, new DOMMatrix().scale(1 / squeeze, 1).translate(-shape.x, -shape.y));

    context.fillStyle = gradient;
    context.fill(placed);
    context.restore();
}

/**
 * 一组圆按屏幕上的顺时针方向依次以公切线连成的闭合轮廓。
 *
 * 凸圆让轮廓绕在圆的外侧，凹圆让轮廓从圆旁掠过、收出内凹；计算时半径带符号，凸圆为正，凹圆为负。
 *
 * @param {{x: number, y: number, radius: number, concave?: boolean}[]} circles 依次相连的圆
 * @returns {Path2D}
 */
function belt(circles) {
    const signed = circles.map(({ x, y, radius, concave }) => ({ x, y, rho: concave ? -radius : radius }));

    // 相邻两圆的公切线：法向量 n 满足 (b − a)·n = ρa − ρb，行进方向在 n 的顺时针一侧；两个切点是各自圆心沿 n 移动 ρ。
    const tangents = signed.map((a, index) => {
        const b = signed[(index + 1) % signed.length];
        const length = Math.hypot(b.x - a.x, b.y - a.y);
        const ux = (b.x - a.x) / length;
        const uy = (b.y - a.y) / length;
        const along = (a.rho - b.rho) / length;
        const across = Math.sqrt(1 - along * along);
        const nx = along * ux + across * uy;
        const ny = along * uy - across * ux;

        return {
            from: [a.x + a.rho * nx, a.y + a.rho * ny],
            to: [b.x + b.rho * nx, b.y + b.rho * ny],
        };
    });

    const path = new Path2D();

    // 在每个圆上从入切点走到出切点，凸圆顺时针、凹圆逆时针；arc 先以直线从上一个出切点连过来，这段直线就是公切线。
    signed.forEach((item, index) => {
        const [inX, inY] = tangents[(index + signed.length - 1) % signed.length].to;
        const [outX, outY] = tangents[index].from;

        path.arc(
            item.x,
            item.y,
            Math.abs(item.rho),
            Math.atan2(inY - item.y, inX - item.x),
            Math.atan2(outY - item.y, outX - item.x),
            item.rho < 0,
        );
    });

    path.closePath();
    return path;
}

/**
 * 两种颜色在线性光空间里按 t 混合，明暗过渡比直接混合 sRGB 更像光。
 *
 * @param {string} a t 为 0 时的颜色，形如 #RRGGBB
 * @param {string} b t 为 1 时的颜色，形如 #RRGGBB
 * @param {number} t 混合比例
 * @returns {string} 混合后的颜色，形如 #RRGGBB
 */
function mixLight(a, b, t) {
    const linear = (hex) => [1, 3, 5].map((index) => {
        const value = Number.parseInt(hex.slice(index, index + 2), 16) / 255;
        return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    });

    const left = linear(a);
    const right = linear(b);

    // 逐个分量在线性光里插值，再换回 sRGB 的 0–255。
    const channels = left.map((value, index) => {
        const mixed = value + (right[index] - value) * t;
        const srgb = mixed <= 0.0031308 ? mixed * 12.92 : 1.055 * mixed ** (1 / 2.4) - 0.055;
        return Math.round(Math.max(0, Math.min(1, srgb)) * 255);
    });

    return `#${channels.map((value) => value.toString(16).padStart(2, '0').toUpperCase()).join('')}`;
}
