/**
 * 获取的工具栏图标，用 Canvas 2D 绘制。
 *
 * make-fetch-icon.swift 在无窗口的 WebKit 中执行本文件，按 @1x、@2x 两种像素尺寸调用 renderFetchIcon 取回 PNG。
 * 画面是一支空心的弧形箭头：箭身从右下方起，沿圆弧绕过上方转到左侧，箭头朝左下；
 * 只画黑色轮廓、背景透明，作为模板图由 AppKit 与 SwiftUI 按外观着色。
 */

/** 设计网格的边长；所有坐标都在这一尺寸下给出，原点在左上角、y 轴朝下。 */
const GRID = 100;

/** 轮廓线宽，约为同尺寸 SF 符号 regular 字重的笔画粗细。 */
const STROKE = 7.5;

/** 图形连同轮廓线占网格边长的比例，四周留出的空白与同组 SF 符号的图片相当。 */
const FILL = 0.92;

/** 箭身圆弧中线的半径。 */
const RADIUS = 27;

/** 箭身的宽度。 */
const BODY = 15;

/** 箭头底边的宽度。 */
const HEAD_WIDTH = 40;

/** 箭头从底边到尖端的长度。 */
const HEAD_LENGTH = 25;

/** 箭身尾端与箭头底边所在的角度，以数学方向计（逆时针为正、0° 朝右）。 */
const TAIL_ANGLE = -55;
const HEAD_ANGLE = 150;

/**
 * 以给定像素尺寸渲染图标。
 *
 * @param {number} pixels 导出图片的边长
 * @returns {string} PNG 的 data URL
 */
function renderFetchIcon(pixels) {
    const canvas = document.createElement('canvas');
    canvas.width = pixels;
    canvas.height = pixels;

    const context = canvas.getContext('2d');
    const shape = arrowShape();

    // 按轮廓的外接框把图形缩放到网格的 FILL 并放到正中；线宽不随缩放变化，先从可用的边长里扣掉
    const box = bounds(shape.points);
    const fit = (GRID * FILL - STROKE) / Math.max(box.maxX - box.minX, box.maxY - box.minY);

    context.scale(pixels / GRID, pixels / GRID);
    context.translate(GRID / 2, GRID / 2);
    context.scale(fit, fit);
    context.translate(-(box.minX + box.maxX) / 2, -(box.minY + box.maxY) / 2);

    context.lineWidth = STROKE / fit;
    context.lineJoin = 'round';
    context.lineCap = 'round';
    context.strokeStyle = '#000000';
    shape.trace(context);
    context.stroke();

    return canvas.toDataURL('image/png');
}

/**
 * 箭头的轮廓：沿外弧走到箭头，绕过尖端回到内弧，再以半圆收起尾端。
 *
 * @returns {{trace: function(CanvasRenderingContext2D): void, points: number[][]}}
 *     trace 把轮廓写进当前路径；points 是计算外接框用的采样点
 */
function arrowShape() {
    const center = [GRID / 2, GRID / 2];
    const inner = RADIUS - BODY / 2;
    const outer = RADIUS + BODY / 2;
    const tail = radians(TAIL_ANGLE);
    const head = radians(HEAD_ANGLE);

    // 箭头底边的中点、径向与前进方向；画布的 y 轴朝下，数学角度换成画布坐标时 y 取反
    const radial = [Math.cos(head), -Math.sin(head)];
    const forward = [-Math.sin(head), -Math.cos(head)];
    const base = add(center, scale(radial, RADIUS));
    const outerCorner = add(base, scale(radial, HEAD_WIDTH / 2));
    const innerCorner = add(base, scale(radial, -HEAD_WIDTH / 2));
    const tip = add(base, scale(forward, HEAD_LENGTH));

    // 尾端的半圆朝箭身来路的反方向鼓出
    const tailRadial = [Math.cos(tail), -Math.sin(tail)];
    const tailMiddle = add(center, scale(tailRadial, RADIUS));
    const capStart = Math.atan2(-tailRadial[1], -tailRadial[0]);

    const trace = (context) => {
        context.beginPath();

        // 画布的角度顺时针为正：外弧从尾端逆时针走到箭头，内弧再顺时针走回尾端
        context.arc(center[0], center[1], outer, -tail, -head, true);
        context.lineTo(...outerCorner);
        context.lineTo(...tip);
        context.lineTo(...innerCorner);
        context.arc(center[0], center[1], inner, -head, -tail, false);
        context.arc(tailMiddle[0], tailMiddle[1], BODY / 2, capStart, capStart - Math.PI, true);
        context.closePath();
    };

    // 外接框取两段圆弧的采样点、箭头的三个角与尾端半圆的采样点
    const points = [outerCorner, innerCorner, tip];

    for (let step = 0; step <= 64; step += 1) {
        const angle = tail + ((head - tail) * step) / 64;
        points.push(add(center, scale([Math.cos(angle), -Math.sin(angle)], outer)));
        points.push(add(center, scale([Math.cos(angle), -Math.sin(angle)], inner)));

        const cap = capStart - (Math.PI * step) / 64;
        points.push(add(tailMiddle, scale([Math.cos(cap), Math.sin(cap)], BODY / 2)));
    }

    return { trace, points };
}

/**
 * 一组点的外接框。
 *
 * @param {number[][]} points 点
 * @returns {{minX: number, minY: number, maxX: number, maxY: number}}
 */
function bounds(points) {
    const xs = points.map((point) => point[0]);
    const ys = points.map((point) => point[1]);

    return {
        minX: Math.min(...xs),
        minY: Math.min(...ys),
        maxX: Math.max(...xs),
        maxY: Math.max(...ys),
    };
}

/** 角度换成弧度。 */
function radians(degrees) {
    return (degrees * Math.PI) / 180;
}

/** 两个向量相加。 */
function add(a, b) {
    return [a[0] + b[0], a[1] + b[1]];
}

/** 向量乘以标量。 */
function scale(vector, factor) {
    return [vector[0] * factor, vector[1] * factor];
}
