/**
 * Spooky 的两组应用图标，用 Canvas 2D 按 macOS 图标网格绘制。
 *
 * make-icon.swift 在无窗口的 WebKit 中执行本文件，为每组的默认图标与深色图标各画指示灯灭着、亮着两版，逐个尺寸调用 renderIcon 取回 PNG。
 *
 * 服务器幽灵：夜色紫底板上，一只白色幽灵从两层服务器机架后探出身来，举起藏在白布下的双手；
 * 机架上是红橙色的 Git 分支符号，每台服务器有两盏指示灯：App 连着服务器时亮起一绿一青，否则灭着。
 * 底板带渐变与投影，其余元素都用纯色平面绘制；深色图标的底板是纯黑，幽灵换成浅米色。
 *
 * 午夜：紫色夜空的满幅画面缩进同样的底板，一只近黑色的大幽灵从右侧探身进来、被底板右边裁切，一只白色胶囊眼看向画面内。
 * 眼睛就是指示灯：App 连着服务器时，眼睛与周围的光晕亮起同一种琥珀色的光，平滑地淡入幽灵。
 * 深色图标的底板是纯黑，幽灵换成在黑底上清楚的紫色。
 */

/** 图标网格的边长；所有坐标都在这一尺寸下给出，原点在左上角。 */
const GRID = 1024;

/** 连续圆角的起止点到角顶点的距离，以圆角半径为单位。 */
const CORNER_EXTENT = 1.52866495;

/**
 * 连续圆角一个角上的三段三次贝塞尔曲线，与系统连续圆角（SwiftUI `RoundedRectangle` 的 `.continuous` 样式）的路径一致。
 *
 * 每段依次是两个控制点与终点的 [u, v]，以圆角半径为单位：
 * u 是沿来路一侧的边到角顶点的距离，v 是沿去路一侧的边到角顶点的距离。
 */
const CONTINUOUS_CORNER = [
    [1.08849001, 0, 0.86840701, 0, 0.63149399, 0.0749114],
    [0.37282401, 0.16906001, 0.16906001, 0.37282401, 0.0749114, 0.63149399],
    [0, 0.86840701, 0, 1.08849001, 0, 1.52866495],
];

/** 底板左上角在 1024 网格中的 x 与 y。 */
const PLATE_ORIGIN = 100;

/** 底板的边长。 */
const PLATE_SIZE = 824;

/** 底板：macOS 图标网格中位于 (100, 100)、边长 824 pt、圆角 185.4 的连续圆角方块。 */
const PLATE = continuousSquare(PLATE_ORIGIN, PLATE_ORIGIN, PLATE_SIZE, 185.4);

/** 底板下方的柔和投影，两组图标相同；参数按 1024 网格给出。 */
const PLATE_SHADOW = { offsetY: 10, blur: 20, color: 'rgba(0, 0, 0, 0.3)' };

/**
 * 服务器幽灵两种图标的配色：底板渐变自上而下由 plateTop 过渡到 plateBottom，幽灵与白布用 ghost，布上的褶用 fold。
 *
 * 默认图标是夜色过渡到亮紫的底板上一只白色幽灵；深色图标的底板上下都是纯黑，幽灵换成浅米色。
 */
const SERVER_GHOST_PALETTES = {
    default: {
        plateTop: '#2C2470',
        plateBottom: '#6F60E6',
        ghost: '#FFFFFF',
        fold: '#D3CCF0',
    },
    dark: {
        plateTop: '#000000',
        plateBottom: '#000000',
        ghost: '#EBE5D5',
        fold: '#CBC1AC',
    },
};

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
 * 以给定像素尺寸渲染一组图标中的一个。
 *
 * @param {number} pixels 导出图片的边长
 * @param {'serverGhost' | 'midnight'} group 图标组：服务器幽灵或午夜
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 * @returns {string} PNG 的 data URL
 */
function renderIcon(pixels, group, style, lit) {
    const canvas = document.createElement('canvas');
    canvas.width = pixels;
    canvas.height = pixels;

    // 坐标按 1024 网格给出，整体缩放到导出尺寸。
    const scale = pixels / GRID;
    const context = canvas.getContext('2d');
    context.scale(scale, scale);

    // 午夜：底板的投影与服务器幽灵相同；满幅的画面整体缩进底板、按底板裁切，幽灵的右侧随之被裁掉。
    if (group === 'midnight') {
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

        return canvas.toDataURL('image/png');
    }

    const palette = SERVER_GHOST_PALETTES[style];

    // 从后往前画：幽灵和举起的双手在最底下，机架挡住幽灵的下半身，分支符号画在机架上。
    drawPlate(context, scale, palette);
    drawGhost(context, palette);
    drawArms(context, palette);
    drawRack(context, lit);
    drawBranch(context);

    return canvas.toDataURL('image/png');
}

/**
 * 底板：按配色自上而下渐变，下方带柔和投影。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {{plateTop: string, plateBottom: string}} palette 所画图标的配色
 */
function drawPlate(context, scale, palette) {
    withShadow(context, scale, PLATE_SHADOW, () => {
        context.fillStyle = palette.plateBottom;
        context.fill(PLATE);
    });

    context.fillStyle = verticalGradient(
        context,
        PLATE_ORIGIN,
        PLATE_ORIGIN + PLATE_SIZE,
        palette.plateTop,
        palette.plateBottom,
    );

    context.fill(PLATE);
}

/**
 * 幽灵：头部从机架后探出，眼睛是深紫色。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {{ghost: string}} palette 所画图标的配色
 */
function drawGhost(context, palette) {
    // 半圆头部接竖直两侧，下半身藏在机架后面。
    const ghost = new Path2D();
    ghost.moveTo(320, 680);
    ghost.lineTo(320, 406);
    ghost.arc(512, 406, 192, Math.PI, 0);
    ghost.lineTo(704, 680);
    ghost.closePath();

    context.fillStyle = palette.ghost;
    context.fill(ghost);

    context.fillStyle = '#2A2163';
    context.fill(ellipse(452, 424, 28, 39));
    context.fill(ellipse(572, 424, 28, 39));
}

/**
 * 举起的两只手藏在白布下：拳头把布顶起，布从拳头往下垂进机架后面，一道褶顺着垂下。
 * 只描左手，右手沿中线镜像。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {{ghost: string, fold: string}} palette 所画图标的配色
 */
function drawArms(context, palette) {
    const degree = Math.PI / 180;

    // 拳头：手臂在这里指向左上方 228°，上沿向内收拢 14°，与拳头相切。
    const fist = { x: 256, y: 398, radius: 24 };
    const pointing = 228 * degree;
    const taper = 14 * degree;
    const upperTangent = pointing + 90 * degree - taper;

    const along = ([x, y], angle, length) => [
        x + Math.cos(angle) * length,
        y + Math.sin(angle) * length,
    ];

    const upper = along([fist.x, fist.y], upperTangent, fist.radius);

    const arm = new Path2D();

    // 上沿：从肩膀竖直起笔，顺着收拢的方向接到拳头。
    arm.moveTo(320, 408);
    arm.bezierCurveTo(
        320, 442,
        ...along(upper, pointing - taper, -50),
        ...upper,
    );

    // 绕过拳头顶端，到拳头最外侧；布从这里往下垂，垂进机架后面。
    arm.arc(fist.x, fist.y, fist.radius, upperTangent, Math.PI, true);
    arm.bezierCurveTo(228, 466, 238, 530, 262, 572);

    // 经机架后面与身体内部闭合，这几段都被挡住，看不见。
    arm.lineTo(390, 572);
    arm.lineTo(390, 408);
    arm.closePath();

    // 一道管状褶从拳头往下垂：两段二次曲线共用起止点，中间最宽约 9，两头收尖。
    const fold = new Path2D();
    fold.moveTo(254, 424);
    fold.quadraticCurveTo(253, 502, 286, 592);
    fold.quadraticCurveTo(271, 498, 254, 424);
    fold.closePath();

    // 褶只画在布的范围里，不会越出布的边缘。
    const drawLeft = () => {
        context.fillStyle = palette.ghost;
        context.fill(arm);

        context.save();
        context.clip(arm);
        context.fillStyle = palette.fold;
        context.fill(fold);
        context.restore();
    };

    drawLeft();

    // 右手是左手沿中线 x = 512 的镜像。
    context.save();
    context.translate(GRID, 0);
    context.scale(-1, 1);
    drawLeft();
    context.restore();
}

/**
 * 机架：上下叠放的两台服务器，各带一条盘位槽与两盏指示灯。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {boolean} lit 指示灯是否亮着
 */
function drawRack(context, lit) {
    for (const top of [560, 706]) {
        context.fillStyle = '#3B347A';
        context.fill(roundedRect(212, top, 600, 132, 30));

        // 盘位槽在中间。
        const middle = top + 66;
        context.fillStyle = '#140F33';
        context.fill(roundedRect(470, middle - 11, 200, 22, 11));

        // 两盏指示灯靠右，亮着时一绿一青；灭着的灯与盘位槽同色。
        context.fillStyle = lit ? '#46E08A' : '#140F33';
        context.fill(circle(714, middle, 11));
        context.fillStyle = lit ? '#4FD6FF' : '#140F33';
        context.fill(circle(750, middle, 11));
    }
}

/**
 * Git 分支符号：主干竖贯两台服务器，支线从右上方汇入。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 */
function drawBranch(context) {
    const nodes = [[300, 626], [300, 772], [392, 626]];

    const lines = new Path2D();
    lines.moveTo(300, 626);
    lines.lineTo(300, 772);
    lines.moveTo(392, 626);
    lines.bezierCurveTo(
        392, 694,
        300, 674,
        300, 742,
    );

    context.strokeStyle = '#F4572F';
    context.lineWidth = 18;
    context.lineCap = 'round';
    context.stroke(lines);

    context.fillStyle = '#F66038';

    for (const [x, y] of nodes) {
        context.fill(circle(x, y, 25));
    }

    // 节点中心点上浅色。
    context.fillStyle = '#FFE3D0';

    for (const [x, y] of nodes) {
        context.fill(circle(x, y, 10.5));
    }
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
 * 在带投影的状态下执行绘制。Canvas 的投影参数不受变换矩阵影响，需要按导出尺寸换算。
 *
 * @param {CanvasRenderingContext2D} context 绘图上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {{offsetY?: number, blur: number, color: string}} shadow 1024 网格下的投影参数，偏移以向下为正
 * @param {() => void} draw 带投影执行的绘制
 */
function withShadow(context, scale, shadow, draw) {
    context.save();
    context.shadowOffsetY = (shadow.offsetY ?? 0) * scale;
    context.shadowBlur = shadow.blur * scale;
    context.shadowColor = shadow.color;
    draw();
    context.restore();
}

/**
 * 竖直方向的两色线性渐变。
 *
 * @param {CanvasRenderingContext2D} context 绘图上下文
 * @param {number} startY 渐变起点的 y，颜色为 top
 * @param {number} endY 渐变终点的 y，颜色为 bottom
 * @param {string} top 起点颜色
 * @param {string} bottom 终点颜色
 * @returns {CanvasGradient}
 */
function verticalGradient(context, startY, endY, top, bottom) {
    const gradient = context.createLinearGradient(0, startY, 0, endY);
    gradient.addColorStop(0, top);
    gradient.addColorStop(1, bottom);
    return gradient;
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
 * 连续圆角方块：从右上角起顺时针，每个角由 CONTINUOUS_CORNER 的三段曲线组成。
 *
 * @param {number} left 左边的 x
 * @param {number} top 上边的 y
 * @param {number} size 边长
 * @param {number} radius 圆角半径
 * @returns {Path2D}
 */
function continuousSquare(left, top, size, radius) {
    const right = left + size;
    const bottom = top + size;

    // back 指向来路一侧的边，out 指向去路一侧的边，两者都从角顶点出发。
    const corners = [
        { vertex: [right, top], back: [-1, 0], out: [0, 1] },
        { vertex: [right, bottom], back: [0, -1], out: [-1, 0] },
        { vertex: [left, bottom], back: [1, 0], out: [0, -1] },
        { vertex: [left, top], back: [0, 1], out: [1, 0] },
    ];

    const path = new Path2D();

    for (const { vertex, back, out } of corners) {
        const point = (u, v) => [
            vertex[0] + (u * back[0] + v * out[0]) * radius,
            vertex[1] + (u * back[1] + v * out[1]) * radius,
        ];

        // 空路径上的 lineTo 等同 moveTo，之后每个角都从直边连过来。
        path.lineTo(...point(CORNER_EXTENT, 0));

        for (const [c1u, c1v, c2u, c2v, u, v] of CONTINUOUS_CORNER) {
            path.bezierCurveTo(...point(c1u, c1v), ...point(c2u, c2v), ...point(u, v));
        }
    }

    path.closePath();
    return path;
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
 * 以左上角、宽高与圆角半径描述的圆角矩形。
 *
 * @param {number} x 左边的 x
 * @param {number} y 上边的 y
 * @param {number} width 宽度
 * @param {number} height 高度
 * @param {number} radius 圆角半径
 * @returns {Path2D}
 */
function roundedRect(x, y, width, height, radius) {
    const path = new Path2D();
    path.roundRect(x, y, width, height, radius);
    return path;
}

/**
 * 以中心与两个半轴描述的椭圆。
 *
 * @param {number} x 中心的 x
 * @param {number} y 中心的 y
 * @param {number} radiusX 水平半轴
 * @param {number} radiusY 竖直半轴
 * @returns {Path2D}
 */
function ellipse(x, y, radiusX, radiusY) {
    const path = new Path2D();
    path.ellipse(x, y, radiusX, radiusY, 0, 0, Math.PI * 2);
    return path;
}

/**
 * 以圆心与半径描述的圆。
 *
 * @param {number} x 圆心的 x
 * @param {number} y 圆心的 y
 * @param {number} radius 半径
 * @returns {Path2D}
 */
function circle(x, y, radius) {
    const path = new Path2D();
    path.arc(x, y, radius, 0, Math.PI * 2);
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
