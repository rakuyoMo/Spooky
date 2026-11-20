import type { TrailPoseName } from '../art/trail.ts';

/*
 * 首页小幽灵的路线：按页面上各块内容的位置排出一串关键帧，再按滚动的距离插值出幽灵当时的位置、大小、姿势与转角。
 *
 * 这里只有不碰页面的纯函数。坐标都是文档坐标，单位是 CSS 像素；滚动的距离就是视口顶边的文档坐标。
 * 路线只由滚动的距离决定，往回滚时原路返回。
 */

/** 页面上的一块矩形，文档坐标。 */
export interface Box {
    /** 左边 */
    left: number;

    /** 上边 */
    top: number;

    /** 右边 */
    right: number;

    /** 下边 */
    bottom: number;
}

/** 排路线用到的页面布局，由页面的脚本量出。 */
export interface TrailLayout {
    /** 视口的宽 */
    width: number;

    /** 视口的高 */
    height: number;

    /** 页面顶部固定的导航栏的高度 */
    header: number;

    /** 最远能滚到的距离 */
    end: number;

    /** 正文栏的左边与右边 */
    column: { left: number; right: number };

    /** 顶部的应用图标 */
    hero: Box;

    /** 顶部的名字、标题与副标题合起来的范围 */
    heading: Box;

    /** 演示窗口 */
    window: Box;

    /** 演示窗口右边一行右端空着的地方的 y：扒着窗口边的小手落在这里，不挡住窗口里的内容 */
    grip?: number;

    /** 示意图里的服务器 */
    server: Box;

    /** 冲突向导旁显形的那幅画：一台服务器往上投出一束光 */
    reveal: Box;

    /** 收尾的满怀 */
    armful: Box;

    /** 收尾的标语 */
    title: Box;

    /** 页面上的各块内容：幽灵横穿页面时从它们之间的空当过 */
    blocks: readonly Box[];
}

/** 排路线用到的画的尺寸，取自构建时写出的 JSON。 */
export interface TrailMetrics {
    /** 姿势原大显示时，幽灵自身坐标的一个单位有多少 CSS 像素 */
    unit: number;

    /** 四幅静止的画里幽灵所在的位置：身体正中占画面宽与高的比例，画面每宽 1 px 时一个单位的长度 */
    anchors: Record<
        'hero' | 'server' | 'reveal' | 'armful',
        { centre: readonly [number, number]; unit: number }
    >;

    /** 姿势原大时，“藏身” 里窗口的边到身体正中的距离 */
    hideEdge: number;

    /** 姿势原大时，“藏身” 里小手的中心比身体正中低多少 */
    pawDrop: number;

    /** 姿势原大时，“够樱桃” 那一刻身体正中到樱桃枝画面右边的距离 */
    branchReach: number;
}

/** 路线上的一个关键帧。 */
export interface TrailKey {
    /** 滚动的距离 */
    s: number;

    /** 身体正中的 x */
    x: number;

    /** 身体正中的 y */
    y: number;

    /** 幽灵自身坐标的一个单位有多少 CSS 像素 */
    u: number;

    /** 到下一帧之前显示的姿势；从停靠的帧出发、去往不停靠的帧时，换成下一帧的姿势 */
    pose: TrailPoseName;

    /** 累计翻过的角度 */
    roll: number;

    /** 上下飘动的幅度：0 是停稳，1 是飘着 */
    bob: number;

    /** 停靠：到这一帧时速度降到 0 */
    hold: boolean;
}

/** 排好的路线：关键帧，以及跟着滚动距离切换的几处画面。 */
export interface TrailPlan {
    /** 各个关键帧，按滚动的距离排好；`tangents` 与它一一对应 */
    keys: readonly TrailKey[];

    /** 各关键帧上 x、y 与单位长度对滚动距离的斜率 */
    tangents: readonly (readonly [number, number, number])[];

    /** 不超过这个距离时，幽灵还停在顶部图标里，由图标自己的画显示 */
    rest: number;

    /** 幽灵离开图标底板的一段：投影从底板上的颜色换成页面上的颜色 */
    plate: readonly [number, number];

    /** 停在演示窗口边上的一段；`side` 是扒在右边、露出半个身子，`top` 是从上边探出头 */
    hide: { mode: 'side' | 'top'; from: number; to: number };

    /** 停在示意图里服务器身前的一段：幽灵的影子落在机架上；从这一段的开头起，服务器的指示灯一直亮着 */
    server: readonly [number, number];

    /** 停在显形那幅画的光里的一段：那台服务器的指示灯亮着，光束出现；没有去那里时为空 */
    reveal: readonly [number, number] | undefined;

    /** 樱桃枝：“够樱桃” 那一刻身体正中的位置与缩放，滑进来的一段，以及摘下樱桃的距离 */
    branch: { x: number; y: number; scale: number; from: number; to: number; pick: number };

    /** 从这个距离起，幽灵已落在收尾的满怀里，由那幅画自己显示 */
    home: number;

    /** 满月淡入的一段 */
    moon: readonly [number, number];
}

/** 某个滚动距离上幽灵的样子。 */
export interface TrailSample {
    /** 身体正中的 x */
    x: number;

    /** 身体正中的 y */
    y: number;

    /** 幽灵自身坐标的一个单位有多少 CSS 像素 */
    u: number;

    /** 显示的姿势 */
    pose: TrailPoseName;

    /** 累计翻过的角度 */
    roll: number;

    /** 上下飘动的幅度 */
    bob: number;
}

/** 幽灵带贴纸边时，半宽与半高各是多少个单位。 */
export const ghostHalf = { width: 300, height: 345 } as const;

/** 幽灵身体的半宽，单位同上。 */
const bodyHalf = 289;

/** 排路线时一起用到的量。 */
interface Context {
    /** 页面布局 */
    layout: TrailLayout;

    /** 画的尺寸 */
    metrics: TrailMetrics;

    /** 一路上幽灵的单位长度 */
    u: number;

    /** 左右两条道上身体正中的 x */
    lanes: { left: number; right: number };
}

/** 收尾各步的时机，都是滚动的距离。 */
interface ClosingTimes {
    /** 樱桃枝从页面右边滑进来的一段 */
    slide: readonly [number, number];

    /** 幽灵到了枝下 */
    into: number;

    /** 摘下樱桃 */
    pickAt: number;

    /** 落进满怀那幅画里 */
    home: number;
}

/** 按页面布局排出整条路线。 */
export function planTrail(layout: TrailLayout, metrics: TrailMetrics): TrailPlan {
    const u = trailUnit(layout.width);
    const context: Context = { layout, metrics, u, lanes: laneX(layout, u) };
    const keys: TrailKey[] = [];

    const hero = heroKeys(context);
    keys.push(...hero.keys);

    const hide = windowKeys(context, keys);
    const server = serverKeys(context, keys);
    const crossed = crossKeys(context, keys);

    // 显形那幅画在页面左边，只有到了左边那条道上才过去
    const reveal = crossed ? revealKeys(context, keys) : undefined;
    const closing = closingKeys(context, keys, crossed);

    // 页面很短时几站会挤在一起：让关键帧的滚动距离逐个变大
    for (const [index, current] of keys.entries()) {
        const before = keys[index - 1];

        if (before && current.s <= before.s) {
            current.s = before.s + 1;
        }
    }

    return {
        keys,
        tangents: tangentsOf(keys),
        rest: 0.5,
        plate: hero.plate,
        hide,
        server,
        reveal,
        branch: closing.branch,
        home: closing.home,
        moon: closing.moon,
    };
}

/** 取某个滚动距离上幽灵的样子：位置与大小按单调的三次曲线插值，姿势按所在一段的两头决定。 */
export function sampleTrail(plan: TrailPlan, s: number): TrailSample {
    const { keys, tangents } = plan;
    const first = keys[0];
    const last = keys.at(-1);

    if (!first || !last) {
        throw new Error('路线没有关键帧');
    }

    if (s <= first.s) {
        return pick(first);
    }

    if (s >= last.s) {
        return pick(last);
    }

    // 二分找到 s 所在的一段
    let low = 0;
    let high = keys.length - 1;

    while (high - low > 1) {
        const middle = (low + high) >> 1;

        if ((keys[middle]?.s ?? 0) <= s) {
            low = middle;
        } else {
            high = middle;
        }
    }

    const from = keys[low] ?? first;
    const to = keys[high] ?? last;
    const span = to.s - from.s;
    const t = span > 0 ? (s - from.s) / span : 1;
    const [mx0, my0, mu0] = tangents[low] ?? [0, 0, 0];
    const [mx1, my1, mu1] = tangents[high] ?? [0, 0, 0];

    return {
        x: hermite(from.x, to.x, mx0 * span, mx1 * span, t),
        y: hermite(from.y, to.y, my0 * span, my1 * span, t),
        u: hermite(from.u, to.u, mu0 * span, mu1 * span, t),
        pose: from.hold && !to.hold ? to.pose : from.pose,
        roll: from.roll + (to.roll - from.roll) * smootherstep(t),
        bob: from.bob + (to.bob - from.bob) * smootherstep(t),
    };
}

/**
 * 找出能让幽灵横穿整个页面的空当：各块内容在竖直方向上都不占的一段，至少比幽灵高出 `room`。
 */
export function findGaps(blocks: readonly Box[], room: number): Box[] {
    const spans = blocks
        .map(({ top, bottom }) => [top, bottom] as const)
        .toSorted((a, b) => a[0] - b[0]);
    const gaps: Box[] = [];
    let reach = Number.NEGATIVE_INFINITY;

    for (const [top, bottom] of spans) {
        if (Number.isFinite(reach) && top - reach >= room) {
            gaps.push({ left: 0, top: reach, right: 0, bottom: top });
        }

        reach = Math.max(reach, bottom);
    }

    return gaps;
}

/** 向目标值指数趋近：`tau` 秒后差距剩下约三分之一，与帧率无关。 */
export function approach(current: number, target: number, seconds: number, tau: number): number {
    return target + (current - target) * Math.exp(-seconds / tau);
}

/** 由屏幕上横向的速度（px / s）算出身体顺着方向的倾角，正值向右倾。 */
export function leanOf(velocity: number): number {
    return clamp(velocity * 0.012, -13, 13);
}

/** `value` 在 `from` 到 `to` 之间走了多少，0 到 1。 */
export function progress(value: number, from: number, to: number): number {
    return to > from ? clamp((value - from) / (to - from), 0, 1) : Number(value >= to);
}

/** 宽屏上幽灵大一些，手机上小一些。 */
export function trailUnit(width: number): number {
    return clamp(width / 9600, 0.08, 0.15);
}

/** 顶部图标：从机架身后升起来，离开底板，长大一点，往旁边飘。 */
function heroKeys(context: Context): { keys: TrailKey[]; plate: readonly [number, number] } {
    const { layout, metrics, u } = context;
    const { hero, heading, width, height, header } = layout;
    const anchor = metrics.anchors.hero;
    const art = hero.right - hero.left;
    const x = hero.left + anchor.centre[0] * art;
    const y = hero.top + anchor.centre[1] * (hero.bottom - hero.top);
    const start = art * anchor.unit;
    const risen = (start + u) / 2;
    const top = y - 0.3 * art;

    // 升起的这一段要在导航栏下面走完：手机上图标离导航栏近，这一段短
    const rise = clamp(top - ghostHalf.height * risen - header - 6, 12, 0.07 * height);

    // 标题与副标题右边空得下幽灵时，从它们旁边过；空不下时先飘出屏幕右边
    const roomy = width - heading.right >= 2 * ghostHalf.width * u + 24;
    const leave = rise + (roomy ? 0.1 : 0.08) * height;
    const side = roomy ? heading.right + (width - heading.right) / 2 : width + ghostHalf.width * u + 4;

    return {
        keys: [
            key({ s: 0, x, y, u: start, pose: 'rise', bob: 0, hold: true }),
            key({ s: rise, x, y: top, u: risen, pose: 'rise', bob: 0 }),
            key({ s: leave, x: side, y: inView(context, leave, y, u), u, pose: 'right' }),
        ],
        plate: [rise * 0.5, leave],
    };
}

/** 演示窗口：宽屏上扒着窗口右边露出半个身子，窗口右边空不下时从窗口上边探出头。 */
function windowKeys(context: Context, keys: TrailKey[]): TrailPlan['hide'] {
    const { layout, metrics, u, lanes } = context;
    const { window, width, height } = layout;
    const previous = lastKey(keys);
    const side = width - window.right >= 0.85 * 2 * bodyHalf * u;
    const scale = u / metrics.unit;
    const grip = layout.grip ?? window.top + 0.3 * Math.min(height, window.bottom - window.top);
    const y = side ? grip - metrics.pawDrop * scale : window.top - 0.2 * ghostHalf.height * u;
    const x = side ? window.right + metrics.hideEdge * scale : window.right - ghostHalf.width * u - 4;
    const from = Math.max(y - 0.7 * height, previous.s + 0.12 * height);
    const to = Math.max(y - 0.3 * height, from + 0.25 * height);
    const pose = side ? 'hide' : 'rise';

    keys.push(
        key({ s: from, x, y, u, pose, bob: 0, hold: true }),
        key({ s: to, x, y, u, pose, bob: 0, hold: true }),
    );

    // 离开窗口，顺着右边那条道往下
    const away = to + 0.15 * height;
    keys.push(key({ s: away, x: lanes.right, y: laneY(context, away, 0.55), u, pose: 'float' }));

    return { mode: side ? 'side' : 'top', from, to };
}

/**
 * 示意图里的服务器：飘到机架身前，抬手指向指示灯，灯亮起；之后平着飘回右边那条道，灯一直亮着。
 *
 * 返回停在机架身前的一段。
 */
function serverKeys(context: Context, keys: TrailKey[]): readonly [number, number] {
    const { layout, metrics, u, lanes } = context;
    const { server, height } = layout;
    const anchor = metrics.anchors.server;
    const art = server.right - server.left;
    const x = server.left + anchor.centre[0] * art;
    const y = server.top + anchor.centre[1] * (server.bottom - server.top);
    const docked = art * anchor.unit;

    // 机架身前的那个位置在视口高度的 22% 到 78% 之间时，幽灵都停在那里
    const from = Math.max(y - 0.78 * height, lastKey(keys).s + 0.35 * height);
    const to = Math.max(y - 0.22 * height, from + 0.3 * height);
    const arrive = from - 0.2 * height;
    const leave = to + 0.12 * height;

    // 示意图上面的内容伸到路上时，径直飞过去会从它前面经过：动身前先顺着道降到示意图的高度
    const lane = laneY(context, arrive, 0.55);
    const half = { width: ghostHalf.width * u, height: ghostHalf.height * u };
    const diagram = layout.blocks.find(
        ({ left, right, top, bottom }) =>
            left <= server.left && right >= server.right && top <= server.top && bottom >= server.bottom,
    );
    const blocked =
        diagram !== undefined &&
        layout.blocks.some(({ right, bottom }) => {
            // 只看动身时与幽灵在同一高度上的内容
            if (bottom > diagram.top || bottom <= lane - half.height) {
                return false;
            }

            // 径直飞过去，身体降到这块内容的下边以下时已经走了多远：那时身体的左边要在它的右边以外
            const cleared = clamp((bottom + half.height - lane) / (y - lane), 0, 1);

            return right > lanes.right + cleared * (x - lanes.right) - half.width;
        });
    const start = blocked ? inView(context, arrive, diagram.top + half.height, u) : lane;

    laneRun(context, keys, arrive, lanes.right, 0.55);
    keys.push(
        key({ s: arrive, x: lanes.right, y: start, u, pose: 'left' }),
        key({ s: from, x, y, u: docked, pose: 'front', bob: 0, hold: true }),
        key({ s: to, x, y, u: docked, pose: 'front', bob: 0, hold: true }),

        // 平着飘回右边那条道，不从机架下面的标题后面经过
        key({ s: leave, x: lanes.right, y: inView(context, leave, y, u), u, pose: 'right' }),
    );

    return [from, to];
}

/**
 * 横穿页面：离开服务器之后的第一个空当里从右往左，途中慢慢翻一整圈，之后顺着左边那条道往下飘。
 *
 * 回右边的那一趟在收尾前的空当里；除了它没有别的空当时不横穿，留在右边那条道上。返回幽灵是否到了左边。
 */
function crossKeys(context: Context, keys: TrailKey[]): boolean {
    const { layout, u, lanes } = context;
    const { height, server } = layout;
    const gaps = gapsAboveArmful(context);
    const gap = gaps.find(({ top }) => top >= server.bottom);

    if (!gap || gap === gaps.at(-1)) {
        return false;
    }

    const y = (gap.top + gap.bottom) / 2;
    const from = Math.max(y - 0.72 * height, lastKey(keys).s + 0.15 * height);
    const to = Math.max(y - 0.32 * height, from + 0.3 * height);

    laneRun(context, keys, from, lanes.right, 0.6);
    keys.push(
        key({ s: from, x: lanes.right, y, u, pose: 'left' }),
        key({ s: to, x: lanes.left, y, u, pose: 'float', roll: 360 }),
    );

    return true;
}

/**
 * 冲突向导旁的显形：从左边那条道飘到服务器上方的光里，浮着停一阵，再往左飘回道上。
 *
 * 返回停在光里的一段：这一段里那台服务器的指示灯亮着，光束出现。
 */
function revealKeys(context: Context, keys: TrailKey[]): readonly [number, number] {
    const { layout, metrics, u, lanes } = context;
    const { reveal, height } = layout;
    const anchor = metrics.anchors.reveal;
    const art = reveal.right - reveal.left;
    const x = reveal.left + anchor.centre[0] * art;
    const y = reveal.top + anchor.centre[1] * (reveal.bottom - reveal.top);
    const docked = art * anchor.unit;

    // 幽灵在视口高度的 70% 到 30% 之间时都停在光里，飘来与飘走都看得见
    const from = Math.max(y - 0.7 * height, lastKey(keys).s + 0.3 * height);
    const to = Math.max(y - 0.3 * height, from + 0.25 * height);
    const arrive = from - 0.15 * height;
    const leave = to + 0.12 * height;
    const roll = lastKey(keys).roll;

    // 动身时已降到这幅画上边的高度：往右飘进去时不碰上面那一块内容
    const above = inView(context, arrive, reveal.top - ghostHalf.height * u, u);

    laneRun(context, keys, arrive, lanes.left, 0.5);
    keys.push(
        key({ s: arrive, x: lanes.left, y: above, u, pose: 'right', roll }),
        key({ s: from, x, y, u: docked, pose: 'reveal', roll, hold: true }),
        key({ s: to, x, y, u: docked, pose: 'reveal', roll, hold: true }),

        // 平着飘回左边那条道，不从下面的服务器前面经过
        key({ s: leave, x: lanes.left, y: inView(context, leave, y, u), u, pose: 'left', roll }),
    );

    return [from, to];
}

/**
 * 收尾：樱桃枝从页面右边伸进来，幽灵眼睛放光、伸手去够；樱桃落进怀里，变成满怀，轻轻落在标语上方。
 *
 * `crossed` 时幽灵在左边那条道上，要先横穿页面才到枝下，见 `dashToBranch`；否则从右边那条道拐过去，见 `turnToBranch`。
 */
function closingKeys(
    context: Context,
    keys: TrailKey[],
    crossed: boolean,
): { branch: TrailPlan['branch']; home: number; moon: readonly [number, number] } {
    const { layout, metrics, u } = context;
    const { armful, width, height } = layout;
    const scale = u / metrics.unit;
    const gap = gapsAboveArmful(context).at(-1);
    const y = gap ? (gap.top + gap.bottom) / 2 : armful.top - ghostHalf.height * u;

    // 枝最粗的一头落在视口右边以外
    const x = width + 4 - metrics.branchReach * scale;
    const { slide, into, pickAt, home } = crossed ? dashToBranch(context, keys, y) : turnToBranch(context, keys, y);
    const anchor = metrics.anchors.armful;
    const art = armful.right - armful.left;

    // 前面翻过的角度保留下来，后面不再转
    const roll = lastKey(keys).roll;

    keys.push(
        key({ s: into, x: x - bodyHalf * u * 0.6, y, u, pose: 'spot', roll }),
        key({ s: Math.max(into + 0.02 * height, pickAt - 0.08 * height), x, y, u, pose: 'reach', roll }),
        key({ s: pickAt, x, y, u, pose: 'armful', roll, bob: 0, hold: true }),
        key({
            roll,
            s: home,
            x: armful.left + anchor.centre[0] * art,
            y: armful.top + anchor.centre[1] * (armful.bottom - armful.top),
            u: art * anchor.unit,
            pose: 'armful',
            bob: 0,
            hold: true,
        }),
    );

    return {
        branch: { x, y, scale, from: slide[0], to: slide[1], pick: pickAt },
        home: home + 0.02 * height,
        moon: [pickAt, home],
    };
}

/**
 * 从左边那条道去枝下：樱桃枝先伸进来；幽灵到了枝所在的那一层，望见它，眼睛放光，再顺着空当横穿页面飞过去。
 *
 * `y` 是枝所在空当的中心。页面在空当下面剩得不多时，各步按同一个比例缩短，落定赶在滚到底之前。
 */
function dashToBranch(context: Context, keys: TrailKey[], y: number): ClosingTimes {
    const { layout, u, lanes } = context;
    const { height, end } = layout;

    // 空当的中心升到视口高度的九成处，幽灵整个看得见
    const arrive = Math.max(y - 0.9 * height, lastKey(keys).s + 0.05 * height);

    // 望着枝、眼睛放光、横穿、够樱桃、落定依次占 0.05、0.07、0.3、0.1、0.3 屏，合起来 0.82 屏
    const span = clamp((end - 0.04 * height - arrive) / 0.82, 0.05 * height, height);
    const spot = arrive + 0.05 * span;
    const leave = spot + 0.07 * span;
    const into = leave + 0.3 * span;
    const pickAt = into + 0.1 * span;
    const roll = lastKey(keys).roll;

    laneRun(context, keys, arrive, lanes.left, 0.5);
    keys.push(
        key({ s: arrive, x: lanes.left, y, u, pose: 'right', roll, hold: true }),
        key({ s: spot, x: lanes.left, y, u, pose: 'spot', roll, hold: true }),
        key({ s: leave, x: lanes.left, y, u, pose: 'spot', roll, hold: true }),
    );

    // 枝在幽灵到之前伸进来：这时空当刚从视口底边升上来
    return {
        slide: [arrive - 0.12 * height, arrive - 0.02 * height],
        into,
        pickAt,
        home: pickAt + 0.3 * span,
    };
}

/**
 * 从右边那条道去枝下：枝所在的空当刚进视口就拐进去，枝同时伸进来；标语出现时摘下樱桃。
 *
 * `y` 是枝所在空当的中心。
 */
function turnToBranch(context: Context, keys: TrailKey[], y: number): ClosingTimes {
    const { layout, u, lanes } = context;
    const { title, height, end } = layout;
    const into = Math.max(y - 0.75 * height, lastKey(keys).s + 0.25 * height);
    const enter = into - 0.2 * height;
    const pickAt = Math.min(
        Math.max(title.top - 0.85 * height, into + 0.1 * height),
        end - 0.12 * height,
    );
    const home = Math.max(
        Math.min(pickAt + 0.3 * height, end - 0.04 * height),
        pickAt + 0.06 * height,
    );

    laneRun(context, keys, enter, lanes.right, 0.5);
    keys.push(key({
        s: enter,
        x: lanes.right,
        y: laneY(context, enter, 0.5),
        u,
        pose: 'right',
        roll: lastKey(keys).roll,
    }));

    return { slide: [enter, into], into, pickAt, home };
}

/** 满怀上方幽灵过得去的空当，从上到下；最后一个是樱桃枝伸进来的地方。 */
function gapsAboveArmful(context: Context): Box[] {
    const { layout, u } = context;

    return findGaps(layout.blocks, 2 * ghostHalf.height * u + 16).filter(
        ({ bottom }) => bottom <= layout.armful.top + 1,
    );
}

/** 顺着一条道往下飘：上一帧到 `until` 之间每隔大半屏补一帧，幽灵一直留在视口里。 */
function laneRun(
    context: Context,
    keys: TrailKey[],
    until: number,
    x: number,
    fraction: number,
): void {
    const { height } = context.layout;
    const start = lastKey(keys).s;
    const steps = Math.floor((until - start) / (0.6 * height));

    for (let step = 1; step <= steps; step += 1) {
        const s = start + ((until - start) * step) / (steps + 1);
        keys.push(key({
            s,
            x,
            y: laneY(context, s, fraction),
            u: context.u,
            pose: 'float',
            roll: lastKey(keys).roll,
        }));
    }
}

/** 两条道：正文栏两边空得下幽灵时取空白的正中，空不下时贴着屏幕边、身体不碰正文。 */
function laneX(layout: TrailLayout, u: number): { left: number; right: number } {
    const { column, width } = layout;
    const half = ghostHalf.width * u;
    const inner = bodyHalf * u + 4;
    const left = column.left >= 2 * half ? column.left / 2 : column.left - inner;
    const margin = width - column.right;
    const right = margin >= 2 * half ? column.right + margin / 2 : column.right + inner;

    return { left, right };
}

/** 道上的 y：视口里导航栏以下那部分的某个比例处。 */
function laneY(context: Context, s: number, fraction: number): number {
    const { header, height } = context.layout;

    return s + header + fraction * (height - header);
}

/** 把 y 限制在视口里导航栏以下、幽灵整个看得见的范围。 */
function inView(context: Context, s: number, y: number, u: number): number {
    const { header, height } = context.layout;
    const half = ghostHalf.height * u + 8;

    return clamp(y, s + header + half, s + height - half);
}

/** 单调的三次曲线在各关键帧上的斜率：停靠的帧为 0，前后走向相反时为 0，不会冲过头。 */
function tangentsOf(keys: readonly TrailKey[]): [number, number, number][] {
    return keys.map((current, index) => {
        const before = keys[index - 1];
        const after = keys[index + 1];

        if (!before || !after || current.hold) {
            return [0, 0, 0];
        }

        return [
            slope(before.x, current.x, after.x, current.s - before.s, after.s - current.s),
            slope(before.y, current.y, after.y, current.s - before.s, after.s - current.s),
            slope(before.u, current.u, after.u, current.s - before.s, after.s - current.s),
        ];
    });
}

/** 一帧上的斜率，取前后两段斜率的加权调和平均。 */
function slope(
    before: number,
    current: number,
    after: number,
    left: number,
    right: number,
): number {
    if (left <= 0 || right <= 0) {
        return 0;
    }

    const d0 = (current - before) / left;
    const d1 = (after - current) / right;

    if (d0 * d1 <= 0) {
        return 0;
    }

    return (3 * (left + right)) / ((2 * right + left) / d0 + (right + 2 * left) / d1);
}

/** 补齐关键帧的默认值：飘着、不翻转、不停靠。 */
function key(value: Pick<TrailKey, 's' | 'x' | 'y' | 'u' | 'pose'> & Partial<TrailKey>): TrailKey {
    return { roll: 0, bob: 1, hold: false, ...value };
}

/** 排到目前为止的最后一帧。 */
function lastKey(keys: readonly TrailKey[]): TrailKey {
    const last = keys.at(-1);

    if (!last) {
        throw new Error('路线还没有关键帧');
    }

    return last;
}

/** 关键帧本身的样子。 */
function pick({ x, y, u, pose, roll, bob }: TrailKey): TrailSample {
    return { x, y, u, pose, roll, bob };
}

/** 三次 Hermite 插值。 */
function hermite(p0: number, p1: number, m0: number, m1: number, t: number): number {
    const t2 = t * t;
    const t3 = t2 * t;

    return (
        (2 * t3 - 3 * t2 + 1) * p0 +
        (t3 - 2 * t2 + t) * m0 +
        (-2 * t3 + 3 * t2) * p1 +
        (t3 - t2) * m1
    );
}

/** 两头导数与二阶导数都为 0 的缓动。 */
function smootherstep(t: number): number {
    return t * t * t * (t * (t * 6 - 15) + 10);
}

/** 把值限制在范围内。 */
function clamp(value: number, low: number, high: number): number {
    return Math.min(Math.max(value, low), high);
}
