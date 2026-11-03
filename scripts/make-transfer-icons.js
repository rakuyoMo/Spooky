/**
 * 获取、拉取、推送三个工具栏图标，用 Canvas 2D 绘制。
 *
 * make-transfer-icons.swift 在无窗口的 WebKit 中执行本文件，按 @1x、@2x 两种像素尺寸调用 renderTransferIcon 取回 PNG。
 * 三个图标是同一支弧形块状箭头：尖角为直角的箭头朝左下，等宽的箭身从箭头背后沿圆弧拱向右上，尾端平切。
 * 获取只描轮廓，拉取是同一轮廓的实心版，推送把拉取转 180°、箭头朝右上；
 * 只画黑色、背景透明，作为模板图由 AppKit 与 SwiftUI 按外观着色。
 */

/** 设计网格的边长；所有坐标都在这一尺寸下给出，原点在左上角、y 轴朝下。 */
const GRID = 100;

/** 轮廓线宽，约为同尺寸 SF 符号 regular 字重的笔画粗细。 */
const STROKE = 7.5;

/** 图形连同轮廓线占网格边长的比例；图形宽而矮，宽度按这一比例占满。 */
const FILL = 0.96;

/** 箭身圆弧中线的半径。 */
const RADIUS = 30;

/** 箭身的宽度。 */
const BODY = 16;

/** 箭头底边的宽度。 */
const HEAD_WIDTH = 48;

/** 箭头从底边到尖端的长度；为底边宽度的一半时尖角是直角，朝左下的箭头两条边一竖一横。 */
const HEAD_LENGTH = 24;

/** 箭身尾端与箭头底边所在的角度，以数学方向计（逆时针为正、0° 朝右）。 */
const TAIL_ANGLE = 68;
const HEAD_ANGLE = 135;

/**
 * 以给定像素尺寸渲染一个图标。
 *
 * @param {number} pixels 导出图片的边长
 * @param {string} kind 图标的种类：'fetch'、'pull' 或 'push'
 * @returns {string} PNG 的 data URL
 */
function renderTransferIcon(pixels, kind) {
    const canvas = document.createElement('canvas');
    canvas.width = pixels;
    canvas.height = pixels;

    const context = canvas.getContext('2d');
    const shape = arrowShape();

    // 按轮廓的外接框把图形缩放到网格的 FILL 并放到正中；线宽不随缩放变化，先从可用的边长里扣掉
    const box = bounds(shape.points);
    const fit = (GRID * FILL - STROKE) / Math.max(box.maxX - box.minX, box.maxY - box.minY);
    const middle = [(box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2];

    // 再把箭头的竖边与横边挪到整像素上，边缘不发虚；推送绕画布中心转 180° 后同样落在整像素上
    const unit = pixels / GRID;
    const left = ((shape.tip[0] - middle[0]) * fit + (GRID - STROKE) / 2) * unit;
    const bottom = ((shape.tip[1] - middle[1]) * fit + (GRID + STROKE) / 2) * unit;
    const nudge = [(Math.round(left) - left) / unit, (Math.round(bottom) - bottom) / unit];

    context.scale(unit, unit);
    context.translate(GRID / 2, GRID / 2);

    if (kind === 'push') {
        context.rotate(Math.PI);
    }

    context.translate(...nudge);
    context.scale(fit, fit);
    context.translate(-middle[0], -middle[1]);

    context.lineWidth = STROKE / fit;
    context.lineJoin = 'round';
    context.fillStyle = '#000000';
    context.strokeStyle = '#000000';
    shape.trace(context);

    // 拉取与推送先填满轮廓，再与获取一样描一圈轮廓线，三者的外缘与圆角一致
    if (kind !== 'fetch') {
        context.fill();
    }

    context.stroke();
    return canvas.toDataURL('image/png');
}

/**
 * 箭头的轮廓：沿外弧从尾端走到箭头，绕过尖端回到内弧，再平切收起尾端。
 *
 * @returns {{trace: function(CanvasRenderingContext2D): void, points: number[][], tip: number[]}}
 *     trace 把轮廓写进当前路径；points 是计算外接框用的采样点；tip 是箭头的尖端
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

    const trace = (context) => {
        context.beginPath();

        // 画布的角度顺时针为正：外弧从尾端逆时针走到箭头，内弧再顺时针走回尾端，closePath 把尾端平切
        context.arc(center[0], center[1], outer, -tail, -head, true);
        context.lineTo(...outerCorner);
        context.lineTo(...tip);
        context.lineTo(...innerCorner);
        context.arc(center[0], center[1], inner, -head, -tail, false);
        context.closePath();
    };

    // 外接框取两段圆弧的采样点与箭头的三个角
    const points = [outerCorner, innerCorner, tip];

    for (let step = 0; step <= 64; step += 1) {
        const angle = tail + ((head - tail) * step) / 64;
        points.push(add(center, scale([Math.cos(angle), -Math.sin(angle)], outer)));
        points.push(add(center, scale([Math.cos(angle), -Math.sin(angle)], inner)));
    }

    return { trace, points, tip };
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
