/* global ARMFUL_BODY, ARMFUL_CHERRIES, ARMFUL_EYES, ARMFUL_GRADIENTS, ARMFUL_KNOT, ARMFUL_LIT, ARMFUL_POSE */
/* global ARMFUL_TAPERS, ARMFUL_WEB, CHERRY_PICK_HAND */
/* global branchSticker, cherrySticker, cherryStemLines, discShape, ghostOutline, leafSticker, starsMarkup, stickerId */
/* global svgBlurred, svgLinear, svgMasked, taperData */

import { boughAt, breeze, evenly, swung } from '../bough.js';
import { ACTS, ARMFUL } from '../plan.js';
import {
    EYES, POSES, STEM, TWINKLE, breathing, castOf, defsOf, edgeOf, faded, ghost, hangingShade, mixEyes, paintOf,
    palette, sprigAt, stemsSticker, turned,
} from '../stickers.js';
import {
    blinking, clamp, easeIn, easeInOut, easeOut, easeOutBack, lerp, lerpEach, ringing, span, sway,
} from '../timing.js';

/*
 * 第四幕 “满怀” 与片尾：小手往下一拽，梗从枝上断开，幽灵把一对樱桃抱进怀里、往后飘开；
 * 镜头跟着它离开枝头，枝退出画面。抱住之后一直留到全片结束。
 *
 * 构图照满怀的图标。图标里那一团是整幅画好的；这里拆成幽灵、两只小手、樱桃、梗与叶子，
 * 每一块都从采撷里的位置挪到满怀里的位置，幽灵的轮廓也逐点对过去。
 */

/** 这一幕开始的时刻；这一幕一直留到全片结束。 */
const { start } = ACTS.armful;

/** 满怀图标里那一团放到画面上时缩小的倍数：各块的粗细与半径跟着缩。 */
const SHRINK = ARMFUL_POSE.scale;

/**
 * 往下拽的那一下：hand 是小手与近处那颗樱桃挪开的量，far 与 knot 是远处那颗、结与枝跟着挪开的比例，
 * lean 是身子往后仰的角度，reach 是枝上离结多远的地方还跟着弯。
 */
const TUG = { hand: [-12, 20], far: 0.55, knot: 0.3, lean: -2.5, reach: 240 };

/**
 * 梗断开之后的枝：枝梢弹回去的幅度，以及镜头跟着幽灵离开时它退到画面右上方多远。
 *
 * 幽灵很轻，拽的时候枝梢只微微一低；弹回去的幅度与之相当。
 * 退到头时，整根枝连同贴纸边与投影都出了画面的右边；一路上都在采撷的标题下方，不从字的背后经过。
 */
const BRANCH = { recoil: 8, away: [660, -300] };

/** 远处那只手还缩在身体里时，中线在幽灵自身坐标里经过的点，以及这时相对顶出来之后的粗细。 */
const TUCKED = { points: [[150, 440], [176, 452], [198, 462]], thickness: 0.45 };

/**
 * 压在樱桃上面的那只手怎么画。
 *
 * 采撷里手与身体是一块贴纸、整块压着樱桃：把这块贴纸在手的范围里再显一遍，范围比手本身宽出 loose 到 snug。
 * 满怀里照图标单画一只、根部淡入身体：from 到 to 这一段里，先把单画的这只显出来，再把前一种撤掉。
 */
const HAND_OVER = { loose: 44, snug: 6, from: ARMFUL.hug - 0.4, to: ARMFUL.hug + 0.1 };

/** 抱住的那一下四周冒出的小星：中心、最大的时候从中心到角尖的长度、颜色与晚出来的秒数。 */
const SPARKLES = [
    { x: 250, y: 330, size: 26, color: '#FFFFFF', delay: 0 },
    { x: 818, y: 334, size: 20, color: ARMFUL_LIT.eye[0], delay: 0.1 },
    { x: 196, y: 650, size: 15, color: ARMFUL_LIT.eye[0], delay: 0.2 },
    { x: 842, y: 716, size: 18, color: '#FFFFFF', delay: 0.14 },
];

/**
 * 满怀里的样子，都换成了画面上的坐标：幽灵的姿态与眼睛，近处与远处的樱桃，结，
 * 通往近处与远处两颗樱桃的梗（even 是中线沿路程均分之后的点），梗自上而下渐变的起止，
 * 梗与两颗樱桃之间填成贴纸边颜色的三角，两只手，近处那只手下缘的褶，以及这只手从根部到手尖渐变的起止。
 *
 * 结上面顶着叶子的一小段梗与那片叶子由 stickers.js 的 sprigAt 给出：它们一直长在结上，樱桃挂在枝上时就在。
 */
const HUG = {
    pose: huggingPose(),
    eyes: ARMFUL_EYES.ovals.map(({ x, y, radiusX }) => ({
        u: x - ARMFUL_BODY[0][0],
        v: y - ARMFUL_BODY[0][1],
        size: radiusX / ARMFUL_EYES.ovals[0].radiusX,
        tilt: ARMFUL_EYES.tilt,
    })),
    near: placedDisc(ARMFUL_CHERRIES.big),
    far: placedDisc(ARMFUL_CHERRIES.small),
    knot: placedDisc(ARMFUL_KNOT),
    stems: [ARMFUL_TAPERS.stemBig, ARMFUL_TAPERS.stemSmall].map((stem) => {
        const taper = placedTaper(stem);

        return { ...taper, even: evenly(taper.line) };
    }),
    stemShade: ARMFUL_GRADIENTS.stem.flatMap((y) => placed([ARMFUL_KNOT.x, y])),
    web: ARMFUL_WEB.map(placed),
    nearHand: placedTaper(ARMFUL_TAPERS.nearHand),
    farHand: placedTaper(ARMFUL_TAPERS.farHand),
    crease: placedTaper(ARMFUL_TAPERS.crease),
    handShade: ARMFUL_GRADIENTS.hand.flatMap((x) => placed([x, ARMFUL_TAPERS.nearHand.line[1][1]])),
};

/**
 * 这一幕与片尾在 t 时刻的画面；这一幕开始之前返回 null。
 *
 * @param {number} t 当前时间
 * @returns {{back: string} | null}
 */
export function paintArmful(t) {
    if (t < start) {
        return null;
    }

    // 往下拽：到梗断开的那一刻拽到头，断开之后手里一松。
    const tug = easeInOut(span(t, start, ARMFUL.snap))
        * (1 - easeOut(span(t, ARMFUL.snap, ARMFUL.snap + 0.2)));

    // 抱进怀里的程度：略冲过头再回来；settled 不冲过头，给不该冲过头的量用。
    // 梗断开之前必须正好是 0：缓动函数在起点算出的是一个极小的数，各块就不再与采撷里的样子分毫不差。
    const hugging = span(t, ARMFUL.snap, ARMFUL.hug);
    const held = hugging > 0 ? easeOutBack(hugging, 0.8) : 0;
    const settled = clamp(held);

    const { spook, nearHand } = huggingGhost(t, tug, held);
    const { knot, near, far, hanging, stalk, leaf } = pairAt(t, tug, held);
    const branch = leavingBranch(t, tug);
    const topLeaf = leafSticker(leaf);

    // 梗：两根垂到樱桃上，结上面的一小段顶着叶子；渐变的起止从挂着时的样子换到满怀图标里的位置。
    const dangling = hangingShade(hanging.map(({ line }) => line), knot);
    const stalks = stemsSticker([...hanging, stalk], knot, lerpEach(dangling, HUG.stemShade, settled));

    // 樱桃：远处那颗上有近处那颗挡出的短影，近处那颗上有手压出的短影。
    const handShape = (fill) => `<path d="${taperData(nearHand.line, nearHand.from, nearHand.to)}" fill="${fill}"/>`;

    const farCherry = cherrySticker({
        ...far,
        shadows: [{ shape: discShape(near), dx: 8, dy: -4, opacity: 0.5 * settled }],
    });

    const nearCherry = cherrySticker({ ...near, shadows: [{ shape: handShape, dx: 6, dy: -6, opacity: 0.55 }] });

    // 梗与两颗樱桃之间的三角：从结上张开，樱桃之间不露出底板。
    const web = filler(HUG.web.map((point) => unfurled(knot, HUG.knot, point, settled)));

    // 采撷里梗在樱桃后面，满怀里在前面：趁动得最快的时候换。
    const fruit = held < 0.5 ? [stalks, farCherry, nearCherry] : [farCherry, nearCherry, stalks];
    const cluster = [...branch, web, topLeaf, spook, ...fruit];
    const body = stickerId('armful-ghost');

    // 从后往前：枝、三角、叶子、幽灵、落在幽灵身上的影子与褶、樱桃与梗，最后是压在樱桃上面的那只手。
    const markup = defsOf(cluster)
        + castOf(cluster)
        + edgeOf(cluster)
        + paintOf([...branch, web, topLeaf])
        + `<g id="${body}">${paintOf([spook])}</g>`
        + embrace(spook, { near, far, stem: hanging[0] }, clamp((held - 0.6) / 0.4))
        + paintOf(fruit)
        + handOver(t, body, nearHand, clamp(held * 3))
        + sparkles(t);

    // 抱住之后整团一起轻轻浮动，接着采撷里幽灵自己的浮动。
    const float = POSES.pick.float * settled * sway(t, 3.1);

    return { back: float === 0 ? markup : `<g transform="translate(0 ${float})">${markup}</g>` };
}

// MARK: - Private

/**
 * 把樱桃抱进怀里的幽灵。
 *
 * @param {number} t 当前时间
 * @param {number} tug 往下拽的程度
 * @param {number} held 抱进怀里的程度，0 是采撷里的样子，1 是满怀里的样子
 * @returns {{spook: object, nearHand: {line: number[][], from: number, to: number}}} 幽灵的贴纸与近处的那只手
 */
function huggingGhost(t, tug, held) {
    const settled = clamp(held);
    const rest = POSES.pick;

    // 采撷里的姿态：往下拽时身子往后仰一点；抱住之后自己不再浮动，交给整团一起做。
    const loose = breathing({
        ...rest,
        lean: [rest.lean[0] + TUG.lean * tug, rest.lean[1]],
        float: rest.float * (1 - settled),
        nod: rest.nod * (1 - settled),
    }, t);

    // 近处的手：从搭在樱桃上的样子，挪到压在大果左下的样子。
    const reaching = {
        line: [
            loose.place(...CHERRY_PICK_HAND.root),
            ...CHERRY_PICK_HAND.reach.map((point, index) => (
                moved(point, TUG.hand, (tug * (index + 1)) / CHERRY_PICK_HAND.reach.length)
            )),
        ],
        from: CHERRY_PICK_HAND.from,
        to: CHERRY_PICK_HAND.to,
    };

    const nearHand = mixTaper(reaching, HUG.nearHand, held);

    // 远处的手：从缩在身体里的样子顶出来，垫到小果下面。
    const tucked = {
        line: TUCKED.points.map(([u, v]) => loose.place(u, v)),
        from: HUG.farHand.from * TUCKED.thickness,
        to: HUG.farHand.to * TUCKED.thickness,
    };

    const spook = ghost({
        pose: mixPlacement(loose, HUG.pose, held),
        hands: [mixTaper(tucked, HUG.farHand, held), nearHand],
        eyes: mixEyes(EYES.right, HUG.eyes, settled),
        lit: 1,

        // 抱住的那一下，星星眼眨一下；此后隔一阵再眨。
        twinkle: blinking(
            t,
            [ARMFUL.hug, ARMFUL.line + 1, ARMFUL.lockup + 1.2, ARMFUL.lockup + 2.6],
            TWINKLE.length,
        ),
    });

    return { spook, nearHand };
}

/**
 * 从枝上摘下来、抱进怀里的一束樱桃：结、两颗樱桃、垂到它们上面的两根梗，连同结上面的一小段梗与长在它顶上的叶子。
 *
 * @param {number} t 当前时间
 * @param {number} tug 往下拽的程度
 * @param {number} held 抱进怀里的程度
 * @returns {{knot: object, near: object, far: object, hanging: {line: number[][], from: number, to: number}[],
 *     stalk: {line: number[][], from: number, to: number}, leaf: {from: number[], to: number[]}}}
 *     结、近处与远处的樱桃、通往这两颗的梗，以及结上面的一小段梗与叶子
 */
function pairAt(t, tug, held) {
    const bough = boughAt(1);
    const settled = clamp(held);

    const pulled = ({ x, y, radius }, share) => ({
        x: x + TUG.hand[0] * tug * share,
        y: y + TUG.hand[1] * tug * share,
        radius,
    });

    // 还挂在枝上的样子：被小手拽着，远处那颗随风摆。
    const loose = {
        knot: pulled(bough.knot, TUG.knot),
        near: pulled(bough.near, 1),
        far: pulled(swung(bough.far, bough.knot, breeze(t).far * (1 - settled)), TUG.far),
    };

    const dangling = cherryStemLines(loose.knot, loose.near, loose.far);
    const knot = mixDisc(loose.knot, HUG.knot, held);

    return {
        knot,
        near: mixDisc(loose.near, HUG.near, held),
        far: mixDisc(loose.far, HUG.far, held),
        hanging: HUG.stems.map((snug, index) => ({
            line: mixLine(dangling[index], snug, held),
            from: lerp(STEM.from, snug.from, settled),
            to: lerp(STEM.to, snug.to, settled),
        })),

        // 结上面的那一截一直长在结上：跟着结走，从挂着时的朝向转回满怀图标里的朝向。
        ...sprigAt(knot, lerp(bough.turn, 0, held)),
    };
}

/**
 * 梗断开之后弹回去的枝，连同留在枝上的那片叶子：镜头跟着幽灵离开枝头，它退出画面，退出去之后不再画。
 *
 * @param {number} t 当前时间
 * @param {number} tug 往下拽的程度
 * @returns {object[]} 两块贴纸，或者没有
 */
function leavingBranch(t, tug) {
    const gone = easeIn(span(t, ARMFUL.snap + 0.06, ARMFUL.snap + 0.72));

    if (gone >= 1) {
        return [];
    }

    const { line, from: thick, to: thin, leaf: kept } = boughAt(1);

    // 梗断开的那一下枝梢弹回去；镜头跟着幽灵离开，枝往右上方退出去。
    const spring = BRANCH.recoil * ringing(t, ARMFUL.snap, 0.32, 5.5);
    const fled = [BRANCH.away[0] * gone, BRANCH.away[1] * gone];

    const sprung = (point) => {
        const [dx, dy] = bend(point, tug, spring);

        return [dx + fled[0], dy + fled[1]];
    };

    const hinge = sprung(kept.from);

    return [
        branchSticker({ line: line.map((point) => moved(point, sprung(point))), from: thick, to: thin }),
        leafSticker({ from: moved(kept.from, hinge), to: moved(kept.to, hinge) }),
    ];
}

/**
 * 枝上的一点被拽弯、又弹起来时挪开的量：离结越近挪得越多。
 *
 * @param {number[]} point 枝上的一点
 * @param {number} tug 往下拽的程度
 * @param {number} [spring] 往上弹起的量
 * @returns {number[]} 挪开的量 [dx, dy]
 */
function bend([x], tug, spring = 0) {
    const share = Math.exp(-(((x - boughAt(1).knot.x) / TUG.reach) ** 2));

    return [TUG.hand[0] * TUG.knot * tug * share, (TUG.hand[1] * TUG.knot * tug - spring) * share];
}

/**
 * 樱桃与梗落在幽灵身上的影子，连同近处那只手下缘的褶：都裁在幽灵的身体里面。
 *
 * @param {object} spook 幽灵的贴纸
 * @param {{near: object, far: object, stem: {line: number[][], from: number, to: number}}} fruit
 *     两颗樱桃与通往近处那颗的梗
 * @param {number} amount 显出来的程度
 */
function embrace(spook, { near, far, stem }, amount) {
    if (amount <= 0) {
        return '';
    }

    const id = stickerId('embrace');
    const { line, from: thick, to: thin, belly } = HUG.crease;

    const shade = discShape(near)(palette.shadow)
        + discShape(far)(palette.shadow)
        + `<path d="${taperData(stem.line, stem.from, stem.to)}" fill="${palette.shadow}"/>`;

    return faded(svgMasked(
        id,
        spook.outline('#fff'),
        `<path d="${taperData(line, thick, thin, belly)}" fill="${palette.fold}" opacity="0.5"/>`
        + svgBlurred(`${id}-shade`, shade, { dx: -6 * SHRINK, dy: 10 * SHRINK, blur: 14 * SHRINK, opacity: 0.7 }),
    ), amount);
}

/**
 * 压在樱桃上面的近处那只手：身体垫在樱桃后面，手压在樱桃前面。两种画法见 HAND_OVER。
 *
 * @param {number} t 当前时间
 * @param {string} body 幽灵成品所在的 SVG 元素的 id
 * @param {{line: number[][], from: number, to: number}} hand 近处的那只手
 * @param {number} snugness 再显一遍的范围收紧的程度，0 最宽，1 最窄
 */
function handOver(t, body, hand, snugness) {
    const id = stickerId('hand-over');
    const margin = lerp(HAND_OVER.loose, HAND_OVER.snug, snugness);
    const swap = span(t, HAND_OVER.from, HAND_OVER.to) * 2;

    const again = svgMasked(
        id,
        `<path d="${taperData(hand.line, hand.from + margin, hand.to + margin)}" fill="#fff"/>`,
        `<use href="#${body}"/>`,
    );

    // 单画的一只：根部淡入身体，到手尖才是实的，颜色与渐变照图标。
    const [root, tip] = palette.hand;

    const alone = svgLinear(`${id}-shade`, HUG.handShade, [[0, root, 0], [0.5, root, 0.85], [0.7, root], [1, tip]])
        + `<path d="${taperData(hand.line, hand.from, hand.to)}" fill="url(#${id}-shade)"/>`;

    return faded(again, 1 - clamp(swap - 1)) + faded(alone, clamp(swap));
}

/**
 * 抱住的那一下四周冒出的几颗小星：变大又变小。
 *
 * @param {number} t 当前时间
 */
function sparkles(t) {
    return SPARKLES.map(({ delay, size, ...star }) => {
        const life = span(t, ARMFUL.hug - 0.1 + delay, ARMFUL.hug + 0.6 + delay);

        if (life <= 0 || life >= 1) {
            return '';
        }

        const swell = Math.sin(Math.PI * life);

        return faded(starsMarkup([{ ...star, size: size * swell }]), swell);
    }).join('');
}

/**
 * 填成贴纸边颜色的一块：只为了让贴纸边连成一片。
 *
 * @param {number[][]} corners 各个角
 * @returns {{defs: string, outline: Function, paint: Function}}
 */
function filler(corners) {
    const shape = (fill) => `<path d="M${corners.join('L')}Z" fill="${fill}"/>`;

    return { defs: '', outline: shape, paint: (colors) => shape(colors.edge) };
}

/**
 * 满怀里幽灵的姿态，做成绘制脚本 ghostPose 的样子：幽灵直立时的轮廓锚点逐个对到满怀的身体上，
 * 其余的点按满怀的身体不歪时的位置算，眼睛与受光处都落在图标里的地方。
 *
 * @returns {{scale: number, place: Function, degrees: Function}}
 */
function huggingPose() {
    const [topX, topY] = ARMFUL_BODY[0];
    const anchors = new Map(ghostOutline().map(([u, v], index) => [`${u},${v}`, placed(ARMFUL_BODY[index])]));

    return {
        scale: SHRINK,
        place: (u, v) => anchors.get(`${u},${v}`) ?? placed([topX + u, topY + v]),
        degrees: () => ARMFUL_POSE.degrees,
    };
}

/**
 * 两个姿态之间的过渡：自身坐标里的每个点，都从一个姿态里的位置挪到另一个姿态里的位置。
 *
 * @param {{scale: number, place: Function, degrees: Function}} loose 起始的姿态
 * @param {{scale: number, place: Function, degrees: Function}} snug 结束的姿态
 * @param {number} amount 0 取 loose，1 取 snug
 * @returns {{scale: number, place: Function, degrees: Function}}
 */
function mixPlacement(loose, snug, amount) {
    return {
        scale: lerp(loose.scale, snug.scale, amount),
        place: (u, v) => lerpEach(loose.place(u, v), snug.place(u, v), amount),
        degrees: (v) => lerp(loose.degrees(v), snug.degrees(v), amount),
    };
}

/**
 * 一根梗的中线从挂在枝上的样子到满怀里的样子的过渡。
 *
 * 两头直接用原样，停住时与图标分毫不差；途中两边各沿路程均分，逐点对应。
 *
 * @param {number[][]} loose 挂在枝上时中线经过的点
 * @param {{line: number[][], even: number[][]}} snug 满怀里的梗，见 HUG.stems
 * @param {number} amount 0 取 loose，1 取 snug
 */
function mixLine(loose, snug, amount) {
    if (amount <= 0) {
        return loose;
    }

    if (amount === 1) {
        return snug.line;
    }

    return evenly(loose).map((point, index) => lerpEach(point, snug.even[index], amount));
}

/**
 * 两个渐细笔画之间的过渡：中线逐点对应。
 */
function mixTaper(loose, snug, amount) {
    return {
        line: loose.line.map((point, index) => lerpEach(point, snug.line[index], amount)),
        from: lerp(loose.from, snug.from, amount),
        to: lerp(loose.to, snug.to, amount),
    };
}

/**
 * 两个圆之间的过渡。
 */
function mixDisc(loose, snug, amount) {
    return {
        x: lerp(loose.x, snug.x, amount),
        y: lerp(loose.y, snug.y, amount),
        radius: lerp(loose.radius, snug.radius, amount),
    };
}

/**
 * 一个点挪开一段距离之后的位置。
 *
 * @param {number[]} point 点
 * @param {number[]} offset 挪开的量 [dx, dy]
 * @param {number} [share] 只挪其中的几成
 */
function moved([x, y], [dx, dy], share = 1) {
    return [x + dx * share, y + dy * share];
}

/**
 * 满怀里结旁边的一个点，跟着现在的结张开到几成之后的位置。
 *
 * @param {{x: number, y: number}} knot 现在的结
 * @param {{x: number, y: number}} rest 满怀里的结
 * @param {number[]} point 满怀里的点
 * @param {number} amount 张开的程度，0 是缩在结上，1 是满怀里的样子
 */
function unfurled(knot, rest, [x, y], amount) {
    return [knot.x + (x - rest.x) * amount, knot.y + (y - rest.y) * amount];
}

/**
 * 满怀图标里的一个点在画面上的位置：那一团先按自己的坐标画好，再整团转一点、缩小、挪到画面正中。
 *
 * @param {number[]} point 满怀自己坐标里的点
 */
function placed(point) {
    const { pivot, degrees, shift } = ARMFUL_POSE;
    const [x, y] = turned(point, pivot, degrees);

    return [pivot[0] + (x - pivot[0]) * SHRINK + shift[0], pivot[1] + (y - pivot[1]) * SHRINK + shift[1]];
}

/**
 * 满怀图标里的一个圆在画面上的位置与大小。
 */
function placedDisc({ x, y, radius }) {
    const [placedX, placedY] = placed([x, y]);

    return { x: placedX, y: placedY, radius: radius * SHRINK };
}

/**
 * 满怀图标里的一个渐细笔画在画面上的位置与粗细。
 */
function placedTaper({ line, from: thick, to: thin, belly = 0 }) {
    return { line: line.map(placed), from: thick * SHRINK, to: thin * SHRINK, belly: belly * SHRINK };
}
