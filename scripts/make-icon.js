/**
 * Spooky 的应用图标，用 Canvas 2D 按 macOS 图标网格绘制。
 *
 * make-icon.swift 在无窗口的 WebKit 中执行本文件，为默认图标与深色图标各画指示灯灭着、亮着两版，逐个尺寸调用 renderIcon 取回 PNG。
 * 画面是夜色紫底板上，一只白色幽灵从两层服务器机架后探出身来，举起藏在白布下的双手；
 * 机架上是红橙色的 Git 分支符号，每台服务器有两盏指示灯：App 连着服务器时亮起一绿一青，否则灭着。
 * 底板带渐变与投影，其余元素都用纯色平面绘制；深色图标的底板是纯黑，幽灵换成浅米色。
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

/** 底板：macOS 图标网格中位于 (100, 100)、边长 824 pt、圆角 185.4 的连续圆角方块。 */
const PLATE = continuousSquare(100, 100, 824, 185.4);

/**
 * 两种图标的配色：底板渐变自上而下由 plateTop 过渡到 plateBottom，幽灵与白布用 ghost，布上的褶用 fold。
 *
 * 默认图标是夜色过渡到亮紫的底板上一只白色幽灵；深色图标的底板上下都是纯黑，幽灵换成浅米色。
 */
const PALETTES = {
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
 * 以给定像素尺寸渲染图标。
 *
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 * @returns {string} PNG 的 data URL
 */
function renderIcon(pixels, style, lit) {
    const canvas = document.createElement('canvas');
    canvas.width = pixels;
    canvas.height = pixels;

    // 坐标按 1024 网格给出，整体缩放到导出尺寸。
    const scale = pixels / GRID;
    const context = canvas.getContext('2d');
    context.scale(scale, scale);

    const palette = PALETTES[style];

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
    const shadow = { offsetY: 10, blur: 20, color: 'rgba(0, 0, 0, 0.3)' };

    withShadow(context, scale, shadow, () => {
        context.fillStyle = palette.plateBottom;
        context.fill(PLATE);
    });

    context.fillStyle = verticalGradient(context, 100, 924, palette.plateTop, palette.plateBottom);
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
