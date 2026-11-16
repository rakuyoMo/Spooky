/**
 * 服务器幽灵：夜色紫底板上，一只白色幽灵从两层服务器机架后探出身来，举起藏在白布下的双手；
 * 机架上是红橙色的 Git 分支符号，每台服务器有两盏指示灯：App 连着服务器时亮起一绿一青，否则灭着。
 * 底板带渐变与投影，其余元素都用纯色平面绘制；深色图标的底板是纯黑，幽灵换成浅米色。
 */

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
 * 服务器幽灵的入口。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 */
function paintServerGhostIcon(context, scale, pixels, style, lit) {
    const palette = SERVER_GHOST_PALETTES[style];

    // 从后往前画：幽灵和举起的双手在最底下，机架挡住幽灵的下半身，分支符号画在机架上。
    drawPlate(context, scale, palette);
    drawGhost(context, palette);
    drawArms(context, palette);
    drawRack(context, lit);
    drawBranch(context);
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
