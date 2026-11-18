/**
 * Spooky 各组应用图标共用的部分：图标网格、底板、入口 renderIcon，以及不止一组用到的绘图工具。
 *
 * make-icon.swift 把本文件与同目录下各组的绘制脚本接成一份，在无窗口的 WebKit 中执行，
 * 为每组的默认图标与深色图标各画指示灯灭着、亮着两版，逐个尺寸调用 renderIcon 取回 PNG。
 *
 * 每组一个文件：配色与几何常量、入口 paint…Icon、绘制函数，以及只有这一组用到的工具；两组以上用到的工具放在本文件。
 * 满怀的三组只差背景，共用 armful.js；满怀、午夜、栖枝与采撷同一种贴纸画法，共用的部分在 sticker.js。
 * 加一组图标时新建一个文件，在 renderIcon 与 make-icon.swift 的表里各加一行。
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

/** 底板的圆角半径。 */
const PLATE_RADIUS = 185.4;

/** 底板：macOS 图标网格中位于 (100, 100)、边长 824 pt、圆角 185.4 的连续圆角方块。 */
const PLATE = continuousSquare(PLATE_ORIGIN, PLATE_ORIGIN, PLATE_SIZE, PLATE_RADIUS);

/** 底板下方的柔和投影，两组图标相同；参数按 1024 网格给出。 */
const PLATE_SHADOW = { offsetY: 10, blur: 20, color: 'rgba(0, 0, 0, 0.3)' };

/**
 * 以给定像素尺寸渲染一组图标中的一个。
 *
 * @param {number} pixels 导出图片的边长
 * @param {'armful' | 'armfulPlain' | 'armfulPurple' | 'perch' | 'cherryPick' | 'serverGhost' | 'midnight'} group
 *     图标组：满怀、满怀 · 素底、满怀 · 紫底、栖枝、采撷、服务器幽灵或午夜
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 * @returns {Promise<string>} PNG 的 data URL
 */
async function renderIcon(pixels, group, style, lit) {
    // 各组的入口，定义在各组的文件里。
    const painters = {
        armful: paintArmfulIcon,
        armfulPlain: paintArmfulPlainIcon,
        armfulPurple: paintArmfulPurpleIcon,
        perch: paintPerchIcon,
        cherryPick: paintCherryPickIcon,
        serverGhost: paintServerGhostIcon,
        midnight: paintMidnightIcon,
    };

    const canvas = document.createElement('canvas');
    canvas.width = pixels;
    canvas.height = pixels;

    // 坐标按 1024 网格给出，整体缩放到导出尺寸。
    const scale = pixels / GRID;
    const context = canvas.getContext('2d');
    context.scale(scale, scale);

    await painters[group](context, scale, pixels, style, lit);

    return canvas.toDataURL('image/png');
}

/**
 * 一张边长为 pixels、已缩放到 1024 网格的新画布，由 draw 画上内容。
 *
 * @param {number} pixels 画布的边长
 * @param {(context: CanvasRenderingContext2D) => void} draw 在 1024 网格里执行的绘制
 * @returns {HTMLCanvasElement}
 */
function paintScene(pixels, draw) {
    const canvas = document.createElement('canvas');
    canvas.width = pixels;
    canvas.height = pixels;

    const context = canvas.getContext('2d');
    context.scale(pixels / GRID, pixels / GRID);
    draw(context);

    return canvas;
}

/**
 * 把一张铺满画面的画布填进底板，底板下方带柔和投影。
 *
 * 画面整张当作图案填进底板，底板边缘的抗锯齿只算一次，不会被一层层叠上去的元素叠实。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {HTMLCanvasElement} scene 与导出图片同样大小、画面铺满的画布
 * @param {string} color 投出投影的那一遍所用的不透明颜色，被画面盖住
 */
function drawPlateScene(context, scale, scene, color) {
    withShadow(context, scale, PLATE_SHADOW, () => {
        context.fillStyle = color;
        context.fill(PLATE);
    });

    // 图案按画布的像素铺开，先抵消上下文到 1024 网格的缩放。
    const pattern = context.createPattern(scene, 'no-repeat');
    pattern.setTransform(new DOMMatrix().scale(1 / scale));

    context.fillStyle = pattern;
    context.fill(PLATE);
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
 * 两头尖、中间鼓的叶形的 SVG 路径数据：两条二次曲线共用起止点，控制点在中点两侧。
 *
 * @param {number[]} from 一头的位置
 * @param {number[]} to 另一头的位置
 * @param {number} reach 两个控制点各自离中点的距离
 * @returns {string}
 */
function lensData(from, to, reach) {
    const length = distanceBetween(from, to);
    const offsetX = (-(to[1] - from[1]) / length) * reach;
    const offsetY = ((to[0] - from[0]) / length) * reach;
    const middleX = (from[0] + to[0]) / 2;
    const middleY = (from[1] + to[1]) / 2;

    return `M${from}Q${middleX + offsetX},${middleY + offsetY} ${to}`
        + `Q${middleX - offsetX},${middleY - offsetY} ${from}Z`;
}

/**
 * 三次贝塞尔曲线上按参数均分的采样点。
 *
 * @param {number[]} from 起点
 * @param {number[]} control1 第一个控制点
 * @param {number[]} control2 第二个控制点
 * @param {number[]} to 终点
 * @param {number} steps 分成的段数
 * @returns {number[][]} 含起点与终点，共 steps + 1 个点
 */
function cubicPoints(from, control1, control2, to, steps) {
    return Array.from({ length: steps + 1 }, (_, index) => {
        const t = index / steps;
        const s = 1 - t;

        return [0, 1].map((axis) => s ** 3 * from[axis]
            + 3 * s ** 2 * t * control1[axis]
            + 3 * s * t ** 2 * control2[axis]
            + t ** 3 * to[axis]);
    });
}

/**
 * 折线上各点离起点的累计长度。
 *
 * @param {number[][]} points 折线上的点
 * @returns {number[]} 与 points 一一对应，第一项为 0
 */
function arcLengths(points) {
    const travelled = [0];

    for (let index = 1; index < points.length; index += 1) {
        travelled.push(travelled[index - 1] + distanceBetween(points[index - 1], points[index]));
    }

    return travelled;
}

/**
 * 两点的距离。
 *
 * @param {number[]} a 一个点
 * @param {number[]} b 另一个点
 * @returns {number}
 */
function distanceBetween(a, b) {
    return Math.hypot(b[0] - a[0], b[1] - a[1]);
}

/**
 * 连续圆角方块。
 *
 * @param {number} left 左边的 x
 * @param {number} top 上边的 y
 * @param {number} size 边长
 * @param {number} radius 圆角半径
 * @returns {Path2D}
 */
function continuousSquare(left, top, size, radius) {
    return new Path2D(continuousSquareData(left, top, size, radius));
}

/**
 * 连续圆角方块的 SVG 路径数据：从右上角起顺时针，每个角由 CONTINUOUS_CORNER 的三段曲线组成。
 *
 * @param {number} left 左边的 x
 * @param {number} top 上边的 y
 * @param {number} size 边长
 * @param {number} radius 圆角半径
 * @returns {string}
 */
function continuousSquareData(left, top, size, radius) {
    const right = left + size;
    const bottom = top + size;

    // back 指向来路一侧的边，out 指向去路一侧的边，两者都从角顶点出发。
    const corners = [
        { vertex: [right, top], back: [-1, 0], out: [0, 1] },
        { vertex: [right, bottom], back: [0, -1], out: [-1, 0] },
        { vertex: [left, bottom], back: [1, 0], out: [0, -1] },
        { vertex: [left, top], back: [0, 1], out: [1, 0] },
    ];

    let data = '';

    for (const { vertex, back, out } of corners) {
        const point = (u, v) => [
            vertex[0] + (u * back[0] + v * out[0]) * radius,
            vertex[1] + (u * back[1] + v * out[1]) * radius,
        ];

        // 第一个角从它的起点起笔，之后每个角都从直边连过来。
        data += `${data ? 'L' : 'M'}${point(CORNER_EXTENT, 0)}`;

        for (const [c1u, c1v, c2u, c2v, u, v] of CONTINUOUS_CORNER) {
            data += `C${point(c1u, c1v)} ${point(c2u, c2v)} ${point(u, v)}`;
        }
    }

    return `${data}Z`;
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
 * @param {number} rotation 绕中心顺时针旋转的弧度
 * @returns {Path2D}
 */
function ellipse(x, y, radiusX, radiusY, rotation = 0) {
    const path = new Path2D();
    path.ellipse(x, y, radiusX, radiusY, rotation, 0, Math.PI * 2);
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
