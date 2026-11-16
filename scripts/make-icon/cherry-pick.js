/**
 * 采撷：墨绿的底板上，樱桃枝从右上伸进来，枝上的节点排成提交图的样子；奶白色的幽灵伸手握住枝上垂下的一对樱桃中的一颗。
 * 所有元素都是纯色平面。App 连着服务器时，枝上的节点亮成琥珀色，外面一圈淡光。
 * 深色图标的底板是纯黑，幽灵换成浅米色，枝、叶与樱桃压暗一档。
 */

/**
 * 采撷两种图标的配色：wall 是底色，也是枝上圆环中心的颜色；node 是枝上的圆环，glint 是樱桃上的高光。
 *
 * 默认图标是墨绿底板上的奶白色幽灵；深色图标的底板是纯黑，幽灵换成浅米色，枝、叶与樱桃压暗一档。
 */
const CHERRY_PICK_PALETTES = {
    default: {
        wall: '#12565C',
        ghost: '#FFF8EA',
        eye: '#0C2F36',
        branch: '#E9C891',
        node: '#FFF1CF',
        leaf1: '#86D4A8',
        leaf2: '#45B085',
        leaf3: '#BFE59A',
        stem: '#B6DC8E',
        cherry1: '#E8384F',
        cherry2: '#C81D3F',
        glint: '#FFD3CC',
    },
    dark: {
        wall: '#000000',
        ghost: '#EBE5D5',
        eye: '#000000',
        branch: '#CBAA74',
        node: '#EADDB8',
        leaf1: '#6FB990',
        leaf2: '#3A9772',
        leaf3: '#A5CB84',
        stem: '#9DC17A',
        cherry1: '#D23248',
        cherry2: '#B01A38',
        glint: '#F4C4BD',
    },
};

/** 采撷连着服务器时，枝上节点的琥珀光：core 是圆环中心的颜色，halo 是外面那圈淡光的颜色。 */
const CHERRY_PICK_LIT = {
    core: '#FFB020',
    halo: '#FFC453',
};

/**
 * 采撷的幽灵。身体先在自身坐标里画成直立的：原点在头心，u 向右、v 向下；再沿一条微弯的脊线摆进画面。角度为度。
 *
 * head 是头心在画面里的位置，radius 是头的半径，length 是下摆基线离头心的距离，flare 是下摆处比头宽出的量；
 * hem 是下摆从右到左的各个极值点 [u, 相对基线的高低]，正的是垂下的波瓣；sway 是波瓣向后飘的量；
 * lean 是脊线在头部与下摆处的倾角，正值是上身向右倾。
 * valley 是头与手臂之间的凹弧：at 是它在头上的方位（水平向右为 0，向下为正），radius 是半径。
 * arm 是手臂：rise 是上缘在凹弧处与手腕处的仰角，reach 是上缘的长度，hand 是手的半径，fall 是下缘在手腕处的仰角；
 * waist 是下缘接回身体右侧处离头心的距离，out 是那里比头宽出的量，drape 是下缘两头的手柄占全长的比例。
 * eyes 是两眼的中心、间距、相对身体的倾角与两个半轴。
 */
const CHERRY_PICK_GHOST = {
    head: [466, 546],
    radius: 148,
    length: 262,
    flare: 12,
    hem: [[108, 18], [52, -16], [-4, 18], [-58, -16], [-110, 17]],
    sway: -10,
    lean: [2, 5],
    valley: { at: 4, radius: 28 },
    arm: { rise: [44, 58], reach: 85, hand: 30, fall: 66, waist: 226, out: 12, drape: [0.34, 0.2] },
    eyes: { center: [62, -24], gap: 66, tilt: -16, radiusX: 14.5, radiusY: 22.5 },
};

/**
 * 采撷的枝，从右上伸进来、起伏着变细。
 *
 * nodes 与 radii 是主枝从右到左经过的点与各处的半径。
 * twigs 是小杈：from 是起点在主枝上的下标，points 是之后经过的点，radii 是从起点起各点的半径。
 * spur 是挂樱桃的短梗，写法与小杈相同。rings 是带圆环的节点：位置与枝在那里的半径。
 */
const CHERRY_PICK_BRANCH = {
    nodes: [[1100, 218], [880, 270], [765, 296], [640, 282], [520, 262], [410, 256], [318, 268], [268, 288]],
    radii: [28, 23.5, 20.5, 17, 13.5, 10.5, 7.5, 4],
    twigs: [
        { from: 3, points: [[598, 240], [572, 200]], radii: [11, 8, 4] },
        { from: 1, points: [[846, 230], [834, 196]], radii: [11, 7.5, 4] },
    ],
    spur: { from: 2, points: [[767, 324]], radii: [9, 6] },
    rings: [
        [[880, 270], 23.5], [[765, 296], 20.5], [[640, 282], 17],
        [[520, 262], 13.5], [[410, 256], 10.5], [[598, 240], 8],
    ],
};

/** 采撷的叶子，互生、大小不一：依次是叶柄的起点、叶柄的方向与长度、叶的方向与长度、配色里的颜色名、弯度；方向为度。 */
const CHERRY_PICK_LEAVES = [
    [[834, 196], -120, 6, -126, 66, 'leaf1', 0.06],
    [[834, 196], -78, 6, -84, 44, 'leaf2', -0.06],
    [[765, 296], -110, 18, -120, 94, 'leaf2', 0.07],
    [[765, 296], -66, 16, -60, 68, 'leaf1', -0.06],
    [[640, 282], 128, 15, 140, 62, 'leaf1', -0.08],
    [[572, 200], -150, 5, -155, 84, 'leaf3', -0.06],
    [[572, 200], -92, 5, -98, 58, 'leaf1', 0.06],
    [[598, 240], -36, 10, -30, 54, 'leaf2', -0.06],
    [[520, 262], -108, 13, -116, 80, 'leaf2', 0.07],
    [[410, 256], 124, 12, 136, 66, 'leaf1', -0.08],
    [[318, 268], -116, 9, -124, 62, 'leaf2', 0.06],
    [[268, 288], 170, 4, 164, 86, 'leaf3', 0.08],
    [[268, 288], -130, 4, -136, 54, 'leaf1', -0.05],
];

/** 采撷里樱桃的半径。 */
const CHERRY_PICK_CHERRY_RADIUS = 37;

/**
 * 采撷的入口：画面先铺满一张画布，再整张填进底板。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 */
function paintCherryPickIcon(context, scale, pixels, style, lit) {
    const palette = CHERRY_PICK_PALETTES[style];
    const scene = paintScene(pixels, (sceneContext) => drawCherryPick(sceneContext, palette, lit));

    drawPlateScene(context, scale, scene, palette.wall);
}

/**
 * 采撷的画面，铺满整张画布：底色上先画枝与叶，再画樱桃，幽灵在最上面。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {object} palette 所画图标的配色
 * @param {boolean} lit 枝上的节点是否亮着
 */
function drawCherryPick(context, palette, lit) {
    context.fillStyle = palette.wall;
    context.fillRect(0, 0, GRID, GRID);

    drawCherryPickBranch(context, palette, lit);
    drawCherryPickCherries(context, palette);
    drawCherryPickGhost(context, palette);
}

/**
 * 采撷的枝：叶子在最下面，上面是小杈、挂樱桃的短梗与主枝，节点上套着圆环。
 *
 * 亮着时，每个圆环外面有两圈平涂的淡光，圆环的中心换成琥珀色。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {object} palette 所画图标的配色
 * @param {boolean} lit 枝上的节点是否亮着
 */
function drawCherryPickBranch(context, palette, lit) {
    const { nodes, radii, twigs, spur, rings } = CHERRY_PICK_BRANCH;

    context.lineCap = 'round';
    context.lineWidth = 5;

    // 每片叶子由一小段叶柄接在枝上。
    for (const [node, stalkAngle, stalk, angle, length, color, bend] of CHERRY_PICK_LEAVES) {
        const base = polar(node, stalk, stalkAngle);
        const stalkLine = new Path2D();
        stalkLine.moveTo(...node);
        stalkLine.lineTo(...base);

        context.strokeStyle = palette[color];
        context.stroke(stalkLine);

        context.fillStyle = palette[color];
        context.fill(polygon(cherryPickLeaf(base, angle, length, bend)));
    }

    context.fillStyle = palette.branch;

    // 小杈先在主枝里顺着枝走一小段再分出去，分叉处是一道锐角。
    for (const { from, points, radii: girths } of twigs) {
        const node = nodes[from];
        const toward = nodes[from - 1];
        const distance = Math.hypot(toward[0] - node[0], toward[1] - node[1]);

        const inside = [
            node[0] + ((toward[0] - node[0]) / distance) * 34,
            node[1] + ((toward[1] - node[1]) / distance) * 34,
        ];

        context.fill(limb([inside, node, ...points], [girths[0], ...girths], 16));
    }

    context.fill(limb([nodes[spur.from], ...spur.points], spur.radii, 16));
    context.fill(limb(nodes, radii, 24));

    // 圆环的大小跟着枝在那里的粗细走。
    const ringRadius = (girth) => 0.55 * girth + 9.5;

    if (lit) {
        context.fillStyle = translucent(CHERRY_PICK_LIT.halo, 0.16);

        for (const [[x, y], girth] of rings) {
            context.fill(circle(x, y, ringRadius(girth) * 2.3));
        }

        context.fillStyle = translucent(CHERRY_PICK_LIT.halo, 0.26);

        for (const [[x, y], girth] of rings) {
            context.fill(circle(x, y, ringRadius(girth) * 1.6));
        }
    }

    for (const [[x, y], girth] of rings) {
        const radius = ringRadius(girth);

        context.fillStyle = palette.node;
        context.fill(circle(x, y, radius));

        context.fillStyle = lit ? CHERRY_PICK_LIT.core : palette.wall;
        context.fill(circle(x, y, radius * (lit ? 0.46 : 0.38)));
    }
}

/**
 * 采撷的一对樱桃：从短梗的梢上垂下两根细梗，前一颗在手的前方、被手握住一部分，它的同伴在右上。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {object} palette 所画图标的配色
 */
function drawCherryPickCherries(context, palette) {
    const { arm } = CHERRY_PICK_GHOST;
    const radius = CHERRY_PICK_CHERRY_RADIUS;

    // 被握住的那颗落在手伸出去的方向上。
    const hand = cherryPickHand(CHERRY_PICK_GHOST);
    const held = polar(hand, arm.hand + radius - 24, -(arm.rise[1] + arm.fall) / 2);
    const other = [held[0] + 62, held[1] - 12];

    const joint = CHERRY_PICK_BRANCH.spur.points.at(-1);

    context.strokeStyle = palette.stem;
    context.lineWidth = 6;
    context.lineCap = 'round';

    // 两根细梗各往一侧微弯。
    for (const [[x, y], sag] of [[other, 12], [held, -3]]) {
        const top = [x, y - radius + 7];
        const stemLine = new Path2D();
        stemLine.moveTo(...joint);
        stemLine.quadraticCurveTo((joint[0] + top[0]) / 2 + sag, (joint[1] + top[1]) / 2, ...top);
        context.stroke(stemLine);
    }

    // 同伴的颜色深一档；每颗左上一点高光。
    for (const [[x, y], color] of [[other, palette.cherry2], [held, palette.cherry1]]) {
        context.fillStyle = color;
        context.fill(circle(x, y, radius));

        context.fillStyle = palette.glint;
        context.fill(circle(x - radius * 0.34, y - radius * 0.38, radius * 0.2));
    }
}

/**
 * 采撷的幽灵：圆头直身、下摆略向后飘，一只手臂伸出去握住樱桃，两只竖椭圆的眼睛望着它。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {object} palette 所画图标的配色
 */
function drawCherryPickGhost(context, palette) {
    const ghost = CHERRY_PICK_GHOST;
    const pose = cherryPickPose(ghost);

    // 身体的轮廓先采样成折线，逐点沿脊线摆进画面。
    const body = nodeCurves(cherryPickBodyNodes(ghost))
        .flatMap(([from, control1, control2, to]) => cubicPoints(from, control1, control2, to, 20).slice(0, -1))
        .map(([u, v]) => pose.place(u, v));

    const arm = new Path2D();
    const armCurves = nodeCurves(cherryPickArmNodes(ghost, pose));
    arm.moveTo(...armCurves[0][0]);

    for (const [, control1, control2, to] of armCurves) {
        arm.bezierCurveTo(...control1, ...control2, ...to);
    }

    arm.closePath();

    context.fillStyle = palette.ghost;
    context.fill(polygon(body));
    context.fill(arm);

    const { center, gap, tilt, radiusX, radiusY } = ghost.eyes;
    const slope = (tilt * Math.PI) / 180;

    context.fillStyle = palette.eye;

    // 两眼沿倾斜的连线分居中心两侧，各自再跟着身体在那里的走向转。
    for (const side of [-1, 1]) {
        const u = center[0] + ((side * gap) / 2) * Math.cos(slope);
        const v = center[1] + ((side * gap) / 2) * Math.sin(slope);
        const [x, y] = pose.place(u, v);

        context.fill(ellipse(x, y, radiusX, radiusY, slope + pose.angle(v)));
    }
}

/**
 * 采撷的幽灵握着樱桃的那只手的圆心：由头与手臂之间的凹弧、手臂上缘的走向与长度推出。
 *
 * @param {object} ghost 幽灵的尺寸，见 CHERRY_PICK_GHOST
 * @returns {number[]}
 */
function cherryPickHand({ head, radius, valley, arm }) {
    const pit = polar(head, radius + valley.radius, valley.at);
    const start = polar(pit, valley.radius, 90 - arm.rise[0]);
    const top = polar(start, arm.reach, -(arm.rise[0] + arm.rise[1]) / 2);

    return polar(top, arm.hand, 90 - arm.rise[1]);
}

/**
 * 把采撷的幽灵从身体自身坐标摆进画面的脊线：从头心往下、微弯的一条三次曲线，下摆沿它向后飘。
 *
 * @param {object} ghost 幽灵的尺寸，见 CHERRY_PICK_GHOST
 * @returns {{place: (u: number, v: number) => number[], angle: (v: number) => number}}
 *     place 给出自身坐标里的点在画面里的位置，angle 给出 v 处身体相对竖直方向转过的弧度
 */
function cherryPickPose({ head, length, lean, sway }) {
    const [startLean, endLean] = lean.map((degrees) => (degrees * Math.PI) / 180);
    const startHeading = [-Math.sin(startLean), Math.cos(startLean)];
    const endHeading = [-Math.sin(endLean), Math.cos(endLean)];

    const middle = (startLean + endLean) / 2;
    const end = [head[0] - Math.sin(middle) * length, head[1] + Math.cos(middle) * length];
    const handle = length * 0.38;

    const spine = cubicPoints(
        head,
        [head[0] + startHeading[0] * handle, head[1] + startHeading[1] * handle],
        [end[0] - endHeading[0] * handle, end[1] - endHeading[1] * handle],
        end,
        80,
    );

    const travelled = arcLengths(spine);
    const total = travelled[travelled.length - 1];

    // 脊线上离头心 v 处的点与走向；头心以上与下摆以下沿两端的走向直着延伸。
    const frame = (v) => {
        if (v <= 0) {
            return [[spine[0][0] + startHeading[0] * v, spine[0][1] + startHeading[1] * v], startHeading];
        }

        if (v >= total) {
            const last = spine[spine.length - 1];
            return [[last[0] + endHeading[0] * (v - total), last[1] + endHeading[1] * (v - total)], endHeading];
        }

        const index = travelled.findLastIndex((distance, position) => position < spine.length - 1 && distance <= v);
        const t = (v - travelled[index]) / (travelled[index + 1] - travelled[index]);
        const [from, to] = [spine[index], spine[index + 1]];
        const span = Math.hypot(to[0] - from[0], to[1] - from[1]);

        return [
            [from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t],
            [(to[0] - from[0]) / span, (to[1] - from[1]) / span],
        ];
    };

    // 下摆从身长的 45% 处起向后飘，越往下飘得越多。
    const swayStart = length * 0.45;
    const swayEnd = length + 24;

    return {
        place(u, v) {
            const drift = v > swayStart ? sway * Math.min((v - swayStart) / (swayEnd - swayStart), 1.2) ** 2 : 0;
            const [[x, y], [tangentX, tangentY]] = frame(v);

            return [x + (u + drift) * tangentY, y - (u + drift) * tangentX];
        },

        angle(v) {
            const [, [tangentX, tangentY]] = frame(v);
            return Math.atan2(-tangentX, tangentY);
        },
    };
}

/**
 * 采撷的幽灵直立的身体在自身坐标里的轮廓节点，顺时针：头顶、右侧、下摆、左侧。
 *
 * @param {object} ghost 幽灵的尺寸，见 CHERRY_PICK_GHOST
 * @returns {object[]} 轮廓节点，见 smoothNode
 */
function cherryPickBodyNodes({ radius, length, flare, hem }) {
    const side = radius + flare;
    const corner = length - 34;
    const kappa = 0.5523 * radius;

    // 两条侧线在下摆上方收进两端的波瓣。
    const nodes = [
        smoothNode([0, -radius], [1, 0], kappa, kappa),
        smoothNode([radius, 0], [0, 1], kappa, length * 0.36),
        smoothNode([side, corner], [0, 1], length * 0.3, (hem[0][1] + 34) * 0.62),
    ];

    // 下摆的极值点交替是垂下的波瓣与凹口；手柄取到相邻极值点距离的一部分，两端的波瓣更圆。
    const stations = [side, ...hem.map(([u]) => u), -side];

    hem.forEach(([u, drop], index) => {
        const before = (stations[index] - u) * (index === 0 ? 0.58 : 0.46);
        const after = (u - stations[index + 2]) * (index === hem.length - 1 ? 0.58 : 0.46);

        nodes.push(smoothNode([u, length + drop], [-1, 0], before, after));
    });

    nodes.push(
        smoothNode([-side, corner], [0, -1], (hem[hem.length - 1][1] + 34) * 0.62, length * 0.3),
        smoothNode([-radius, 0], [0, -1], length * 0.36, kappa),
    );

    return nodes;
}

/**
 * 采撷的幽灵手臂的轮廓节点：凹弧与头外切，上缘伸到手，下缘垂到身体右侧的腰间，再从身体里面合拢。
 *
 * @param {object} ghost 幽灵的尺寸，见 CHERRY_PICK_GHOST
 * @param {{place: (u: number, v: number) => number[]}} pose 幽灵的脊线，见 cherryPickPose
 * @returns {object[]} 轮廓节点，见 smoothNode
 */
function cherryPickArmNodes(ghost, pose) {
    const { head, radius, valley, arm } = ghost;

    const dip = arcNodes(polar(head, radius + valley.radius, valley.at), valley.radius, valley.at + 180, 90 - arm.rise[0], 2);
    const tip = arcNodes(cherryPickHand(ghost), arm.hand, -90 - arm.rise[1], 90 - arm.fall, 3);

    // 凹弧从头的轮廓上直接起笔；它与手之间是一条缓弯，两头的手柄各取两点距离的三分之一。
    const reach = distanceBetween(dip[dip.length - 1].point, tip[0].point) / 3;
    dip[0].intoLength = 0;
    dip[dip.length - 1].outLength = reach;
    tip[0].intoLength = reach;

    // 下缘接回身体的地方，走向顺着身体右侧的边。
    const side = radius + arm.out;
    const hip = pose.place(side, arm.waist);
    const above = pose.place(side, arm.waist - 2);
    const below = pose.place(side, arm.waist + 2);
    const drop = distanceBetween(tip[tip.length - 1].point, hip);

    tip[tip.length - 1].outLength = drop * arm.drape[0];

    // 最后两个节点在身体里面，以直线合拢，被身体盖住。
    return [
        ...dip,
        ...tip,
        smoothNode(hip, [below[0] - above[0], below[1] - above[1]], drop * arm.drape[1], 0),
        smoothNode(pose.place(40, arm.waist), [1, 0], 0, 0),
        smoothNode(head, [1, 0], 0, 0),
    ];
}

/**
 * 采撷的一片叶子的轮廓点：基部圆、中段最宽、尖端收尖，整片沿中脉微弯。
 *
 * @param {number[]} base 叶子基部的位置
 * @param {number} degrees 叶的方向，度
 * @param {number} length 叶长
 * @param {number} bend 弯度：叶尖偏离中脉的量与叶长之比
 * @returns {number[][]}
 */
function cherryPickLeaf(base, degrees, length, bend) {
    const half = 0.2 * length;

    // 中脉一侧的边：从基部鼓到最宽处，再收到叶尖。
    const side = [
        ...cubicPoints([0, 0], [0.1 * length, 0.78 * half], [0.22 * length, half], [0.42 * length, half], 14),
        ...cubicPoints([0.42 * length, half], [0.66 * length, half], [0.84 * length, 0.3 * half], [length, 0], 18),
    ];

    const rim = [...side.map(([x, y]) => [x, -y]), ...side.slice(1, -1).reverse()];
    const angle = (degrees * Math.PI) / 180;

    return rim.map(([x, y]) => {
        const bent = y + bend * length * (x / length) ** 2;

        return [
            base[0] + x * Math.cos(angle) - bent * Math.sin(angle),
            base[1] + x * Math.sin(angle) + bent * Math.cos(angle),
        ];
    });
}

/**
 * 一段枝的轮廓：中线平滑地穿过各点，粗细在各点的半径之间平滑过渡，两端是圆头。
 *
 * @param {number[][]} points 中线经过的点
 * @param {number[]} radii 各点处的半径
 * @param {number} steps 相邻两点之间采样的段数
 * @returns {Path2D}
 */
function limb(points, radii, steps) {
    const line = catmullRom(points, steps);
    const travelled = arcLengths(line);
    const total = travelled[travelled.length - 1];

    return ribbon(line, smoothProfile(radii.map((radius, index) => [travelled[index * steps] / total, radius * 2])));
}

/**
 * 轮廓节点：轮廓经过 point，进来与出去的方向相同，两侧的贝塞尔手柄长度分别是 intoLength 与 outLength。
 *
 * @param {number[]} point 节点的位置
 * @param {number[]} direction 轮廓在节点处的走向，不必是单位向量
 * @param {number} intoLength 进来一侧的手柄长度
 * @param {number} outLength 出去一侧的手柄长度
 * @returns {{point: number[], direction: number[], intoLength: number, outLength: number}}
 */
function smoothNode(point, direction, intoLength, outLength) {
    const length = Math.hypot(direction[0], direction[1]);
    return { point, direction: [direction[0] / length, direction[1] / length], intoLength, outLength };
}

/**
 * 把一圈轮廓节点依次连成闭合的轮廓：每相邻两个节点之间一段三次贝塞尔曲线。
 *
 * @param {object[]} nodes 轮廓节点，见 smoothNode
 * @returns {number[][][]} 各段的起点、两个控制点与终点
 */
function nodeCurves(nodes) {
    return nodes.map((node, index) => {
        const next = nodes[(index + 1) % nodes.length];

        return [
            node.point,
            [
                node.point[0] + node.direction[0] * node.outLength,
                node.point[1] + node.direction[1] * node.outLength,
            ],
            [
                next.point[0] - next.direction[0] * next.intoLength,
                next.point[1] - next.direction[1] * next.intoLength,
            ],
            next.point,
        ];
    });
}

/**
 * 一段圆弧上的轮廓节点，从 start 走到 end；角度为度，水平向右为 0，屏幕上顺时针为正。
 *
 * @param {number[]} center 圆心
 * @param {number} radius 半径
 * @param {number} start 起点的角度
 * @param {number} end 终点的角度
 * @param {number} parts 圆弧分成的段数
 * @returns {object[]} 轮廓节点，见 smoothNode
 */
function arcNodes(center, radius, start, end, parts) {
    const step = (end - start) / parts;
    const sign = Math.sign(step);

    // 每段圆弧由一段三次贝塞尔曲线近似。
    const handle = (4 / 3) * Math.tan((Math.abs(step) * Math.PI) / 720) * radius;

    return Array.from({ length: parts + 1 }, (_, index) => {
        const angle = ((start + step * index) * Math.PI) / 180;

        return smoothNode(
            polar(center, radius, start + step * index),
            [-sign * Math.sin(angle), sign * Math.cos(angle)],
            handle,
            handle,
        );
    });
}

/**
 * 沿一条折线、按宽度函数展开的变宽笔画，两端是圆头。
 *
 * @param {number[][]} line 中线上的点
 * @param {(fraction: number) => number} width 走到全长的 fraction 处的宽度
 * @returns {Path2D}
 */
function ribbon(line, width) {
    const points = resample(line, 2);
    const last = points.length - 1;

    // 每个采样点的位置、走向与半宽。
    const frames = points.map(([x, y], index) => {
        const before = points[Math.max(index - 1, 0)];
        const after = points[Math.min(index + 1, last)];
        const length = distanceBetween(before, after) || 1;

        return {
            x,
            y,
            tangentX: (after[0] - before[0]) / length,
            tangentY: (after[1] - before[1]) / length,
            half: Math.max(width(index / last), 0) / 2,
        };
    });

    const east = frames.map(({ x, y, tangentX, tangentY, half }) => [x + tangentY * half, y - tangentX * half]);
    const west = frames.map(({ x, y, tangentX, tangentY, half }) => [x - tangentY * half, y + tangentX * half]);

    // 圆头：从一条边绕到另一条边的半圆；细到接近 0 的一头直接收尖。
    const cap = ({ x, y, tangentX, tangentY, half }, sign) => {
        if (half < 0.3) {
            return [];
        }

        return Array.from({ length: 15 }, (_, index) => {
            const angle = (Math.PI * (index + 1)) / 16;
            const across = sign * Math.cos(angle) * half;
            const along = sign * Math.sin(angle) * half;

            return [x + across * tangentY + along * tangentX, y - across * tangentX + along * tangentY];
        });
    };

    return polygon([...east, ...cap(frames[last], 1), ...west.reverse(), ...cap(frames[0], -1)]);
}

/**
 * 由 [位置, 值] 控制点得到平滑经过它们的函数；位置是 0–1 的比例，两端以外取端点的值。
 *
 * @param {number[][]} stops 控制点，位置递增
 * @returns {(x: number) => number}
 */
function smoothProfile(stops) {
    const xs = stops.map(([x]) => x);
    const ys = stops.map(([, y]) => y);
    const last = stops.length - 1;

    // 每个控制点处的斜率取前后两点连线的斜率。
    const slopes = stops.map((_, index) => {
        const before = Math.max(index - 1, 0);
        const after = Math.min(index + 1, last);

        return (ys[after] - ys[before]) / (xs[after] - xs[before]);
    });

    return (x) => {
        if (x <= xs[0]) {
            return ys[0];
        }

        if (x >= xs[last]) {
            return ys[last];
        }

        // 相邻两个控制点之间按三次埃尔米特曲线过渡。
        const index = xs.findLastIndex((stop) => stop <= x);
        const span = xs[index + 1] - xs[index];
        const t = (x - xs[index]) / span;

        return (2 * t ** 3 - 3 * t ** 2 + 1) * ys[index]
            + (t ** 3 - 2 * t ** 2 + t) * span * slopes[index]
            + (-2 * t ** 3 + 3 * t ** 2) * ys[index + 1]
            + (t ** 3 - t ** 2) * span * slopes[index + 1];
    };
}

/**
 * 依次连接各点的闭合多边形。
 *
 * @param {number[][]} points 顶点
 * @returns {Path2D}
 */
function polygon(points) {
    const path = new Path2D();

    // 空路径上的 lineTo 等同 moveTo。
    for (const [x, y] of points) {
        path.lineTo(x, y);
    }

    path.closePath();
    return path;
}

/**
 * 沿折线按弧长等距重新采样。
 *
 * @param {number[][]} points 折线上的点
 * @param {number} step 相邻采样点的间距，按全长取整后略有出入
 * @returns {number[][]}
 */
function resample(points, step) {
    const travelled = arcLengths(points);
    const total = travelled[travelled.length - 1];
    const count = Math.max(2, Math.floor(total / step));

    let segment = 0;

    return Array.from({ length: count + 1 }, (_, index) => {
        const distance = (total * index) / count;

        // 采样点一路往前走，所在的线段也只往前找。
        while (segment < travelled.length - 2 && travelled[segment + 1] < distance) {
            segment += 1;
        }

        const span = travelled[segment + 1] - travelled[segment];
        const t = span === 0 ? 0 : (distance - travelled[segment]) / span;
        const [from, to] = [points[segment], points[segment + 1]];

        return [from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t];
    });
}

/**
 * 圆上的点。
 *
 * @param {number[]} center 圆心
 * @param {number} radius 半径
 * @param {number} degrees 方位：水平向右为 0，屏幕上顺时针为正
 * @returns {number[]}
 */
function polar([x, y], radius, degrees) {
    const angle = (degrees * Math.PI) / 180;
    return [x + radius * Math.cos(angle), y + radius * Math.sin(angle)];
}
