import type { TrailPoseName } from '../art/trail.ts';
import { clamp, type GazeAim, type GazeStop, type PoseSpan, type Ramp } from './cues.ts';

/*
 * 首页小幽灵的路线：按页面上各块内容的位置排出一串关键帧，再按滚动的距离插值出幽灵当时的位置、大小与转角；
 * 一路上换姿势、转眼神、伸手与灯光亮灭的时机也一起排好，按滚动的距离取值见 `cues.ts`。
 *
 * 这里只有不碰页面的纯函数。坐标都是文档坐标，单位是 CSS 像素；滚动的距离就是视口顶边的文档坐标。
 * 一切都只由滚动的距离决定，往回滚时原路返回；两站之间按幽灵在屏幕上要走的路留够滚动的距离，中速滚动时也走得平稳。
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

    /** 顶部的大标题：幽灵飘到它旁边时望着它 */
    headline: Box;

    /** 演示窗口 */
    window: Box;

    /** 演示窗口右边一行右端空着的地方的 y：扒着窗口边的小手先落在这里，不挡住窗口里的内容 */
    grip?: number;

    /** 示意图里的服务器 */
    server: Box;

    /** 正文各段介绍里的配图，从上到下：幽灵飘过时望向它们 */
    media: readonly Box[];

    /** 冲突向导旁显形的那幅画：一台服务器往上投出一束光 */
    reveal: Box;

    /** 显形那一段介绍的标题 */
    revealTitle: Box;

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

    /** 姿势原大时，樱桃枝画面的上边与下边比 “够樱桃” 那一刻的身体正中低多少 */
    branchSpan: readonly [number, number];

    /** 姿势原大时，那对樱桃的正中相对 “够樱桃” 那一刻身体正中的位置 */
    cherry: readonly [number, number];
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

    /** 累计翻过的角度 */
    roll: number;

    /** 上下飘动的幅度：0 是停稳，1 是飘着 */
    bob: number;

    /** 停靠：到这一帧时速度降到 0，跟着页面走 */
    hold: boolean;

    /** 顺着窗口边滑：到这一帧时横向与大小不变，y 对滚动距离的斜率是这个值；省略时按前后两帧算出 */
    glide?: number;
}

/** 幽灵的移动：关键帧，以及各关键帧上 x、y 与单位长度对滚动距离的斜率，两者一一对应。 */
export interface TrailMotion {
    /** 各个关键帧，按滚动的距离排好 */
    keys: readonly TrailKey[];

    /** 各关键帧上的斜率 */
    tangents: readonly (readonly [number, number, number])[];
}

/** 排好的路线：幽灵的移动，以及跟着滚动距离变化的姿势、眼神、小手与几处画面。 */
export interface TrailPlan extends TrailMotion {
    /** 不超过这个距离时，幽灵还停在顶部图标里，由图标自己的画显示 */
    rest: number;

    /** 幽灵离开图标底板的一段：投影从底板上的颜色换成页面上的颜色 */
    plate: readonly [number, number];

    /** 停在演示窗口边上的一段；`side` 是扒在右边、露出半个身子，顺着窗口边往下滑，`top` 是从上边探出头 */
    hide: { mode: 'side' | 'top'; from: number; to: number };

    /** 各个姿势完整显示的一段，按先后排好 */
    poses: readonly PoseSpan[];

    /** 眼神的各站，按先后排好 */
    gaze: readonly GazeStop[];

    /** 眼睛亮成四角星：从 [0] 到 [1] 渐渐亮起，之后一直亮着 */
    lit: readonly [number, number];

    /** 扒着窗口边的小手伸出与缩回；从窗口上边探头时没有 */
    paw: Ramp | undefined;

    /** 示意图里服务器的指示灯与落在机架上的影子：幽灵碰到机架时渐渐亮起，离开时渐渐熄灭 */
    lamps: Ramp;

    /** 显形那台服务器的光束与指示灯，亮灭同上；没有去那里时没有 */
    beam: Ramp | undefined;

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

    /** 累计翻过的角度 */
    roll: number;

    /** 上下飘动的幅度 */
    bob: number;
}

/** 幽灵带贴纸边时，半宽与半高各是多少个单位。 */
export const ghostHalf = { width: 300, height: 345 } as const;

/** 幽灵身体的半宽，单位同上。 */
const bodyHalf = 289;

/** 幽灵在屏幕上移动的速度最多是滚动速度的这么多倍：两站之间按它留够滚动的距离。 */
const pace = 1.5;

/** 扒着窗口边往下滑时，y 对滚动距离的斜率：比 1 略大，幽灵在视口里几乎不动，又看得出在往下溜。 */
const slideRate = 1.1;

/** 换姿势、转眼神这类过渡占的滚动距离，是视口高度的这个比例。 */
const blend = 0.06;

/** 飞向停靠处时，横向还剩那幅画宽度的这么多倍时小手开始伸出；离开时横向走出这么远时手已收回。 */
const reachAt = 0.65;

/** 飞向停靠处时，横向还剩那幅画宽度的这么多倍时身子碰到画里的机器、灯开始亮；离开时走出这么远时灯已熄灭。 */
const touchAt = 0.56;

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

/** 顶部图标这一段：关键帧、离开底板的一段，以及升出机架与飘到标题旁边的距离。 */
interface Rising {
    /** 关键帧 */
    keys: TrailKey[];

    /** 离开底板的一段 */
    plate: readonly [number, number];

    /** 升出机架 */
    risen: number;

    /** 飘到标题旁边 */
    pass: number;
}

/** 停在演示窗口边的一段。 */
interface Hiding {
    /** 扒在右边或从上边探头 */
    mode: 'side' | 'top';

    /** 停在窗口边时的姿势 */
    pose: TrailPoseName;

    /** 开始换成这个姿势 */
    enter: number;

    /** 到了窗口边 */
    from: number;

    /** 开始离开：收手、换回飘着的姿势 */
    release: number;

    /** 换回飘着的姿势 */
    to: number;

    /** 扒着窗口边的小手伸出与缩回 */
    paw: Ramp | undefined;
}

/** 停在某幅画前的一站。 */
interface Dock {
    /** 停靠处身体正中的 x */
    x: number;

    /** 从道上动身 */
    arrive: number;

    /** 停稳 */
    from: number;

    /** 开始离开 */
    to: number;

    /** 回到道上 */
    leave: number;

    /** 那幅画的宽度 */
    art: number;
}

/** 停在某幅画前时，小手伸出与灯光亮灭的时机。 */
interface DockCues {
    /** 小手伸出与缩回；没有小手的姿势在这一段里换过去 */
    hand: Ramp;

    /** 画里的灯亮起与熄灭 */
    lamps: Ramp;
}

/** 收尾各步的时机，都是滚动的距离。 */
interface Closing {
    /** 樱桃枝 */
    branch: TrailPlan['branch'];

    /** 落进满怀之后交给那幅画 */
    home: number;

    /** 满月淡入的一段 */
    moon: readonly [number, number];

    /** 樱桃枝滑进来的一段 */
    slide: readonly [number, number];

    /** 枝滑到位之后那对樱桃的正中 */
    cherry: { x: number; y: number };

    /** 注意到樱桃：眼神正好落到樱桃上、眼睛开始放光、动身去够 */
    turn: number;

    /** 换成 “望见樱桃” 的姿势 */
    spot: number;

    /** 到了枝下 */
    into: number;

    /** 换成 “够樱桃” 的姿势 */
    reach: number;

    /** 摘下樱桃 */
    pick: number;
}

/** 去枝下的两种走法排出的时机。 */
interface ClosingTimes {
    /** 樱桃枝滑进来的一段 */
    slide: readonly [number, number];

    /** 眼睛开始放光、动身去够 */
    turn: number;

    /** 到了枝下 */
    into: number;

    /** 摘下樱桃 */
    pickAt: number;

    /** 落进满怀那幅画里 */
    home: number;
}

/** 各站排出的时机，排姿势与眼神时一起用到。 */
interface Stages {
    /** 顶部图标 */
    hero: Rising;

    /** 演示窗口 */
    hide: Hiding;

    /** 示意图里的服务器 */
    server: Dock;

    /** 服务器前伸手与亮灯的时机 */
    docked: DockCues;

    /** 显形那幅画；没有去那里时没有 */
    reveal: Dock | undefined;

    /** 显形那幅画前换姿势与亮灯的时机 */
    shown: DockCues | undefined;

    /** 收尾 */
    closing: Closing;
}

/** 望着屏幕前。 */
const ahead: GazeAim = { kind: 'ahead' };

/** 按页面布局排出整条路线。 */
export function planTrail(layout: TrailLayout, metrics: TrailMetrics): TrailPlan {
    const u = trailUnit(layout.width);
    const context: Context = { layout, metrics, u, lanes: laneX(layout, u) };
    const hero = heroKeys(context);
    const keys: TrailKey[] = [...hero.keys];
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

    const motion: TrailMotion = { keys, tangents: tangentsOf(keys) };
    const docked = dockCues(motion, server);
    const shown = reveal ? dockCues(motion, reveal) : undefined;
    const stages: Stages = { hero, hide, server, docked, reveal, shown, closing };

    return {
        ...motion,
        rest: 0.5,
        plate: hero.plate,
        hide: { mode: hide.mode, from: hide.from, to: hide.to },
        poses: poseSpans(context, stages),
        gaze: gazeStops(context, motion, stages),
        lit: [closing.turn, closing.turn + 0.03 * layout.height],
        paw: hide.paw,
        lamps: docked.lamps,
        beam: shown?.lamps,
        branch: closing.branch,
        home: closing.home,
        moon: closing.moon,
    };
}

/** 取某个滚动距离上幽灵的样子：位置与大小按三次曲线插值，翻转与飘动的幅度按先慢后快再慢的进度过渡。 */
export function sampleTrail(motion: TrailMotion, s: number): TrailSample {
    const { keys, tangents } = motion;
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

/**
 * 欠阻尼的弹簧走过 `seconds` 秒：`value` 带着速度 `velocity` 被拉向 `target`，返回新的值与速度。
 *
 * `omega` 是固有角频率（弧度 / 秒），`zeta` 是阻尼比，在 0 与 1 之间；按解析解计算，与帧率无关。
 */
export function spring(
    value: number,
    velocity: number,
    target: number,
    seconds: number,
    omega: number,
    zeta: number,
): [number, number] {
    const offset = value - target;
    const decay = Math.exp(-zeta * omega * seconds);
    const damped = omega * Math.sqrt(1 - zeta * zeta);
    const cos = Math.cos(damped * seconds);
    const sin = Math.sin(damped * seconds);
    const swing = (velocity + zeta * omega * offset) / damped;

    return [
        target + decay * (offset * cos + swing * sin),
        decay * ((swing * damped - zeta * omega * offset) * cos - (offset * damped + zeta * omega * swing) * sin),
    ];
}

/** 由屏幕上横向的速度（px / s）算出身体顺着方向的倾角，正值向右倾。 */
export function leanOf(velocity: number): number {
    return clamp(velocity * 0.012, -13, 13);
}

/** 宽屏上幽灵大一些，手机上小一些。 */
export function trailUnit(width: number): number {
    return clamp(width / 9600, 0.08, 0.15);
}

/**
 * 顶部图标：从机架身后升起来，一边升一边往旁边飘，离开底板、长大一点。
 *
 * 一路贴着导航栏下面：名字、标题与副标题逐行升到幽灵身下之前，幽灵已经越过这一行的右边，不从标题后面经过；
 * 右边空得下幽灵时停在标题旁边，空不下时接着飘出屏幕右边。
 */
function heroKeys(context: Context): Rising {
    const { layout, metrics, u } = context;
    const { hero, heading, width, height, header } = layout;
    const anchor = metrics.anchors.hero;
    const art = hero.right - hero.left;
    const x = hero.left + anchor.centre[0] * art;
    const y = hero.top + anchor.centre[1] * (hero.bottom - hero.top);
    const start = art * anchor.unit;
    const risen = (start + u) / 2;
    const top = y - 0.3 * art;
    const ride = header + 8 + ghostHalf.height * u;

    // 升起的这一段要在导航栏下面走完：手机上图标离导航栏近，这一段短
    const rise = clamp(top - ghostHalf.height * risen - header - 6, 12, 0.07 * height);

    // 每一行升到幽灵身下的时机与那时幽灵要越过的位置；最赶的一行定下飘到旁边的时机，从一开始就匀着往旁边飘
    const lines = layout.blocks.filter(({ top: lineTop, bottom }) => lineTop >= heading.top && bottom <= heading.bottom);
    const marks = lines.map((line) => ({
        s: Math.max(line.top - ride - ghostHalf.height * u - 4, rise + 0.04 * height),
        x: line.right + ghostHalf.width * u + 8,
    }));
    const pass = marks.reduce<{ s: number; x: number } | undefined>(
        (best, mark) => (best && (best.x - x) / best.s >= (mark.x - x) / mark.s ? best : mark),
        undefined,
    ) ?? { s: rise + 0.1 * height, x: heading.right + ghostHalf.width * u + 8 };

    const roomy = width - heading.right >= 2 * ghostHalf.width * u + 24;
    const keys = [
        key({ s: 0, x, y, u: start, bob: 0, hold: true }),
        key({ s: rise, x: x + ((pass.x - x) * rise) / pass.s, y: top, u: risen }),
        key({ s: pass.s, x: pass.x, y: pass.s + ride, u }),
    ];

    // 右边空不下幽灵时，越过标题之后接着飘出屏幕右边
    const side = width + ghostHalf.width * u + 4;

    if (!roomy && pass.x < side) {
        const leave = pass.s + travel(side - pass.x, 0, 0.05 * height);

        keys.push(key({ s: leave, x: side, y: leave + ride, u }));
    }

    return { keys, plate: [rise * 0.5, lastKey(keys).s], risen: rise, pass: pass.s };
}

/**
 * 演示窗口：宽屏上扒着窗口右边、露出半个身子，伸出小手扒住窗口边，跟着视口顺着窗口边往下滑；
 * 滑到离窗口下边还有一个半身子高时开始收手，边收边接着往下飘，回到右边那条道。
 * 窗口右边空不下半个身子时，改成从窗口上边探出头，见 `peekKeys`。
 */
function windowKeys(context: Context, keys: TrailKey[]): Hiding {
    const { layout, metrics, u, lanes } = context;
    const { window, width, height, header } = layout;

    if (width - window.right < 0.85 * 2 * bodyHalf * u) {
        return peekKeys(context, keys);
    }

    const previous = lastKey(keys);
    const scale = u / metrics.unit;
    const drop = metrics.pawDrop * scale;
    const x = window.right + metrics.hideEdge * scale;
    const grip = (layout.grip ?? window.top + 0.3 * Math.min(height, window.bottom - window.top)) - drop;

    // 搭上窗口边时，搭的那一行在视口高度的一半处；从上一站过来的路按速度上限留够滚动距离
    const from = Math.max(grip - 0.5 * height, previous.s + arrival(previous, x, grip, 0.12 * height));

    // 窗口很矮时也至少滑上一小段再收手
    const letGo = Math.max(window.bottom - 1.5 * ghostHalf.height * u - drop, grip + 0.1 * height * slideRate);
    const release = from + (letGo - grip) / slideRate;
    const lane = header + 0.55 * (height - header);
    const away = release + travel(lanes.right - x, lane - (letGo - release), 0.2 * height);
    const hiding = { x, u, bob: 0, glide: slideRate } as const;

    keys.push(
        key({ ...hiding, s: from, y: grip }),
        key({ ...hiding, s: release, y: letGo }),
        key({ s: away, x: lanes.right, y: laneY(context, away, 0.55), u }),
    );

    // 到了窗口边才伸出小手；开始收手时还顺着窗口边往下滑，收手与换回飘着的姿势同时进行
    return {
        mode: 'side',
        pose: 'hide',
        enter: from - blend * height,
        from,
        release,
        to: release + blend * height,
        paw: [from, from + blend * height, release, release + blend * height],
    };
}

/** 窗口右边空不下半个身子时，从窗口上边探出头，停一阵再飘回右边那条道。 */
function peekKeys(context: Context, keys: TrailKey[]): Hiding {
    const { layout, u, lanes } = context;
    const { window, height, header } = layout;
    const previous = lastKey(keys);
    const y = window.top - 0.2 * ghostHalf.height * u;
    const x = window.right - ghostHalf.width * u - 4;
    const from = Math.max(y - 0.7 * height, previous.s + arrival(previous, x, y, 0.12 * height));
    const to = Math.max(y - 0.3 * height, from + 0.25 * height);
    const lane = header + 0.55 * (height - header);
    const away = to + travel(lanes.right - x, lane - (y - to), 0.15 * height);

    keys.push(
        key({ s: from, x, y, u, bob: 0, hold: true }),
        key({ s: to, x, y, u, bob: 0, hold: true }),
        key({ s: away, x: lanes.right, y: laneY(context, away, 0.55), u }),
    );

    return {
        mode: 'top',
        pose: 'rise',
        enter: from - 0.05 * height,
        from,
        release: to,
        to: to + 0.05 * height,
        paw: undefined,
    };
}

/**
 * 示意图里的服务器：飘到机架身前，抬手指向指示灯；之后平着飘回右边那条道。
 *
 * 机架身前的那个位置在视口高度的 78% 处时停稳；视口里导航栏以下那部分的 30% 处时开始离开。
 */
function serverKeys(context: Context, keys: TrailKey[]): Dock {
    const { layout, metrics, u, lanes } = context;
    const { server, height, header } = layout;
    const anchor = metrics.anchors.server;
    const art = server.right - server.left;
    const x = server.left + anchor.centre[0] * art;
    const y = server.top + anchor.centre[1] * (server.bottom - server.top);
    const docked = art * anchor.unit;

    // 从道上过去与回到道上的路按速度上限留够滚动距离
    const reach = travel(x - lanes.right, 0.78 * height - (header + 0.55 * (height - header)), 0.2 * height);
    const from = Math.max(y - 0.78 * height, lastKey(keys).s + reach + 0.05 * height);
    const to = Math.max(y - header - 0.3 * (height - header), from + 0.15 * height);
    const arrive = from - reach;
    const leave = to + travel(lanes.right - x, 0, 0.12 * height);

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
        key({ s: arrive, x: lanes.right, y: start, u }),
        key({ s: from, x, y, u: docked, bob: 0, hold: true }),
        key({ s: to, x, y, u: docked, bob: 0, hold: true }),

        // 平着飘回右边那条道，不从机架下面的标题后面经过
        key({ s: leave, x: lanes.right, y: inView(context, leave, y, u), u }),
    );

    return { x, arrive, from, to, leave, art };
}

/**
 * 横穿页面：离开服务器之后的第一个空当里从右往左，途中慢慢翻一整圈，之后顺着左边那条道往下飘。
 *
 * 空当从视口下部升到快出视口时才横穿完，路尽量长；回右边的那一趟在收尾前的空当里，
 * 除了它没有别的空当时不横穿，留在右边那条道上。返回幽灵是否到了左边。
 */
function crossKeys(context: Context, keys: TrailKey[]): boolean {
    const { layout, u, lanes } = context;
    const { height, header, server } = layout;
    const gaps = gapsAboveArmful(context);
    const gap = gaps.find(({ top }) => top >= server.bottom);

    if (!gap || gap === gaps.at(-1)) {
        return false;
    }

    const y = (gap.top + gap.bottom) / 2;
    const from = Math.max(y - 0.86 * height, lastKey(keys).s + 0.15 * height);
    const longest = y - header - 8 - ghostHalf.height * u;
    const to = Math.max(from + 0.3 * height, Math.min(from + travel(lanes.left - lanes.right, 0, 0), longest));

    laneRun(context, keys, from, lanes.right, 0.6);
    keys.push(
        key({ s: from, x: lanes.right, y, u }),
        key({ s: to, x: lanes.left, y, u, roll: 360 }),
    );

    return true;
}

/** 冲突向导旁的显形：从左边那条道飘到服务器上方的光里，浮着停一阵，再往左飘回道上。 */
function revealKeys(context: Context, keys: TrailKey[]): Dock {
    const { layout, metrics, u, lanes } = context;
    const { reveal, height, header } = layout;
    const anchor = metrics.anchors.reveal;
    const art = reveal.right - reveal.left;
    const x = reveal.left + anchor.centre[0] * art;
    const y = reveal.top + anchor.centre[1] * (reveal.bottom - reveal.top);
    const docked = art * anchor.unit;

    // 幽灵在视口高度的 70% 到 30% 之间时都停在光里，飘来与飘走都看得见；来去的路按速度上限留够滚动距离
    const reach = travel(x - lanes.left, 0.7 * height - (header + 0.5 * (height - header)), 0.15 * height);
    const from = Math.max(y - 0.7 * height, lastKey(keys).s + reach + 0.15 * height);
    const to = Math.max(y - 0.3 * height, from + 0.25 * height);
    const arrive = from - reach;
    const leave = to + travel(x - lanes.left, 0, 0.12 * height);
    const roll = lastKey(keys).roll;

    // 动身时已降到这幅画上边的高度：往右飘进去时不碰上面那一块内容
    const above = inView(context, arrive, reveal.top - ghostHalf.height * u, u);

    laneRun(context, keys, arrive, lanes.left, 0.5);
    keys.push(
        key({ s: arrive, x: lanes.left, y: above, u, roll }),
        key({ s: from, x, y, u: docked, roll, hold: true }),
        key({ s: to, x, y, u: docked, roll, hold: true }),

        // 平着飘回左边那条道，不从下面的服务器前面经过
        key({ s: leave, x: lanes.left, y: inView(context, leave, y, u), u, roll }),
    );

    return { x, arrive, from, to, leave, art };
}

/**
 * 收尾：樱桃枝从页面右边伸进来，幽灵的眼神落到樱桃上、眼睛放光、飞过去伸手去够；樱桃落进怀里，变成满怀，轻轻落在标语上方。
 *
 * `crossed` 时幽灵在左边那条道上，要先横穿页面才到枝下，见 `dashToBranch`；否则从右边那条道拐过去，见 `turnToBranch`。
 */
function closingKeys(context: Context, keys: TrailKey[], crossed: boolean): Closing {
    const { layout, metrics, u } = context;
    const { armful, width, height } = layout;
    const scale = u / metrics.unit;
    const gap = gapsAboveArmful(context).at(-1);
    const y = gap ? (gap.top + gap.bottom) / 2 : armful.top - ghostHalf.height * u;

    // 枝最粗的一头落在视口右边以外
    const x = width + 4 - metrics.branchReach * scale;
    const times = crossed
        ? dashToBranch(context, keys, y, branchSlide(context, y, scale))
        : turnToBranch(context, keys, y);
    const { slide, turn, into, pickAt, home } = times;
    const reach = Math.max(into + 0.02 * height, pickAt - 0.08 * height);
    const anchor = metrics.anchors.armful;
    const art = armful.right - armful.left;

    // 前面翻过的角度保留下来，后面不再转
    const roll = lastKey(keys).roll;

    keys.push(
        key({ s: into, x: x - bodyHalf * u * 0.6, y, u, roll }),
        key({ s: reach, x, y, u, roll }),
        key({ s: pickAt, x, y, u, roll, bob: 0, hold: true }),
        key({
            roll,
            s: home,
            x: armful.left + anchor.centre[0] * art,
            y: armful.top + anchor.centre[1] * (armful.bottom - armful.top),
            u: art * anchor.unit,
            bob: 0,
            hold: true,
        }),
    );

    return {
        branch: { x, y, scale, from: slide[0], to: slide[1], pick: pickAt },
        home: home + 0.02 * height,
        moon: [pickAt, home],
        slide,
        cherry: { x: x + metrics.cherry[0] * scale, y: y + metrics.cherry[1] * scale },
        turn,
        spot: crossed ? turn + 0.04 * height : into,
        into,
        reach,
        pick: pickAt,
    };
}

/**
 * 樱桃枝从左边那条道上望得见时滑进来的一段：枝的画面从视口底边升上来时开始滑，整幅升进视口前滑到位。
 *
 * `y` 是 “够樱桃” 那一刻身体正中的 y，`scale` 是幽灵的缩放。
 */
function branchSlide(context: Context, y: number, scale: number): readonly [number, number] {
    const { layout, metrics } = context;
    const [top, bottom] = metrics.branchSpan;

    return [y + top * scale - 1.05 * layout.height, y + bottom * scale - 1.05 * layout.height];
}

/**
 * 从左边那条道去枝下：注意到樱桃之后马上动身，先顺着道降到枝所在的那一层，再顺着空当横穿页面飞过去。
 *
 * `y` 是枝所在空当的中心。页面在空当下面剩得不多时，各步按同一个比例缩短，落定赶在滚到底之前；
 * 横穿与落进满怀两段的路最长，分到的滚动距离也最多。
 */
function dashToBranch(
    context: Context,
    keys: TrailKey[],
    y: number,
    slide: readonly [number, number],
): ClosingTimes {
    const { layout, u, lanes } = context;
    const { height, end } = layout;
    const roll = lastKey(keys).roll;

    // 枝滑到位之后眼神往右瞟，再滚动 0.12 屏时注意到樱桃
    const turn = Math.max(slide[1] + 0.12 * height, lastKey(keys).s + 0.05 * height);

    laneRun(context, keys, turn, lanes.left, 0.5);

    const start = key({ s: turn, x: lanes.left, y: laneY(context, turn, 0.5), u, roll });
    const arrive = turn + arrival(start, lanes.left, y, 0.06 * height);

    // 横穿、够樱桃、落定依次占 0.38、0.08、0.26 屏，合起来 0.72 屏
    const span = clamp((end - 0.04 * height - arrive) / 0.72, 0.05 * height, height);
    const into = arrive + 0.38 * span;
    const pickAt = into + 0.08 * span;

    keys.push(start, key({ s: arrive, x: lanes.left, y, u, roll }));

    return { slide, turn, into, pickAt, home: pickAt + 0.26 * span };
}

/**
 * 从右边那条道去枝下：枝所在的空当刚进视口就拐进去，枝同时伸进来；到了枝下时眼睛放光，标语出现时摘下樱桃。
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
        roll: lastKey(keys).roll,
    }));

    return { slide: [enter, into], turn: into, into, pickAt, home };
}

/**
 * 停在某幅画前时小手伸出与灯光亮灭的时机：飞过去时，离停靠处横向还剩那幅画宽度的 `reachAt` 倍时手开始伸出，
 * 剩 `touchAt` 倍时身子碰到画里的机器、灯开始亮，停稳时手完全伸出、灯全亮；离开时反过来。
 */
function dockCues(motion: TrailMotion, dock: Dock): DockCues {
    const away = (s: number): number => Math.abs(sampleTrail(motion, s).x - dock.x);
    const near = (distance: number): number => solve(dock.arrive, dock.from, away, distance);
    const far = (distance: number): number => solve(dock.to, dock.leave, away, distance);
    const reach = reachAt * dock.art;
    const touch = touchAt * dock.art;

    return {
        hand: [near(reach), dock.from, dock.to, far(reach)],
        lamps: [near(touch), dock.from, dock.to, far(touch)],
    };
}

/**
 * 各个姿势完整显示的一段：顶部图标里举着手；到了窗口边换成藏身；飞向服务器时一边歪身子一边伸出手，离开时收回；
 * 到了显形的光里换成显形；之后望见樱桃、伸手去够，最后变成满怀。
 */
function poseSpans(context: Context, stages: Stages): PoseSpan[] {
    const { height } = context.layout;
    const { hero, hide, docked, shown, closing } = stages;
    const beforeSpot = closing.spot - 0.04 * height;
    const spans: PoseSpan[] = [
        { pose: 'rise', from: 0, to: (hero.risen + hero.pass) / 2 },
        { pose: 'float', from: hero.pass, to: hide.enter },
        { pose: hide.pose, from: hide.from, to: hide.release },
        { pose: 'float', from: hide.to, to: docked.hand[0] },
        { pose: 'front', from: docked.hand[1], to: docked.hand[2] },
        { pose: 'float', from: docked.hand[3], to: shown?.hand[0] ?? beforeSpot },
    ];

    if (shown) {
        spans.push(
            { pose: 'reveal', from: shown.hand[1], to: shown.hand[2] },
            { pose: 'float', from: shown.hand[3], to: beforeSpot },
        );
    }

    spans.push(
        { pose: 'spot', from: closing.spot, to: closing.into },
        { pose: 'reach', from: closing.reach, to: closing.pick - 0.03 * height },
        { pose: 'armful', from: closing.pick, to: Number.POSITIVE_INFINITY },
    );

    // 页面很短时几段会挤在一起：每段都不早于前一段
    let floor = 0;

    return spans.map((span) => {
        const from = Math.max(span.from, floor);
        const to = Math.max(span.to, from);

        floor = to;

        return { ...span, from, to };
    });
}

/**
 * 眼神的各站。
 *
 * 飘到标题旁边时望着下面的大标题，标题快被导航栏盖住时改望演示窗口的正中，一直望到收手；
 * 飞向服务器时望着机架，离开时视线从机架上慢慢移回屏幕前；路过两段介绍时望向配图；
 * 飞向显形的光里时转向那一段的标题，离开后望着下面那幅配图，飘过它的大半之后望回屏幕前；
 * 樱桃枝滑进来时望着前方，滑到位之后眼神慢慢往右瞟，注意到樱桃时正好望着它。
 */
function gazeStops(context: Context, motion: TrailMotion, stages: Stages): GazeStop[] {
    const { layout } = context;
    const { height, header, headline, window } = layout;
    const { hero, hide, server, reveal, closing } = stages;
    const lead = blend * height;
    const stops: GazeStop[] = [{ s: 0, aim: ahead }];

    // 在 from 到 to 之间望着 aim，之前用 before 的滚动距离从上一个目标转过来；
    // 上一个目标望得晚了时晚些转、晚些到，转过来的一段至少留一半，眼神不跳
    const hold = (aim: GazeAim, from: number, to: number, before = lead): void => {
        const last = stops.at(-1) ?? { s: 0, aim: ahead };
        const start = Math.max(from - before, last.s);
        const reach = Math.max(from, start + 0.5 * before);

        stops.push({ s: start, aim: last.aim }, { s: reach, aim }, { s: Math.max(to, reach), aim });
    };

    const read = Math.max(hero.pass + 0.01 * height, headline.top - header - 0.01 * height);

    hold(pointAt(centre(headline)), hero.pass, read);
    hold(pointAt(centre(window)), read + lead, hide.release);
    hold(ahead, hide.to, hide.to);
    hold({ kind: 'side', x: -1, y: 0 }, server.arrive, server.to);
    hold(ahead, server.to + 0.44 * height, server.to + 0.44 * height, 0.44 * height);
    mediaLooks(context, stages, hold);

    if (reveal) {
        revealLooks(context, motion, stages, hold);
    }

    // 枝滑到位时开始往右瞟，注意到樱桃时正好望着它
    const glance = Math.max(closing.turn - closing.slide[1], lead);

    hold(pointAt(closing.cherry), closing.turn, Number.POSITIVE_INFINITY, glance);

    return stops;
}

/**
 * 路过服务器与显形之间的两段介绍时望向配图：望着的那一点在正文栏正中、配图高度的 31% 处，
 * 那一点升到视口高度的 72% 处时转过去。第一段望到那一点升到 59% 处；第二段望到动身去显形之前，没有去显形时望到 30% 处。
 */
function mediaLooks(
    context: Context,
    stages: Stages,
    hold: (aim: GazeAim, from: number, to: number, before?: number) => void,
): void {
    const { layout } = context;
    const { height, column, server, reveal } = layout;
    const lead = blend * height;
    const [first, second] = layout.media.filter(({ top, bottom }) => top > server.bottom && bottom <= reveal.top);
    const pointIn = (media: Box): { x: number; y: number } => ({
        x: (column.left + column.right) / 2,
        y: media.top + 0.31 * (media.bottom - media.top),
    });

    if (first) {
        const point = pointIn(first);

        hold(pointAt(point), point.y - 0.72 * height, point.y - 0.59 * height);
        hold(ahead, point.y - 0.59 * height + lead, point.y - 0.59 * height + lead);
    }

    if (!second) {
        return;
    }

    const point = pointIn(second);

    // 没有去显形时望回屏幕前：樱桃枝开始滑进来时已经望着前方
    const until = stages.reveal
        ? stages.reveal.arrive - 0.135 * height
        : Math.min(point.y - 0.3 * height, stages.closing.slide[0] - lead);

    if (point.y - 0.72 * height + lead >= until) {
        return;
    }

    hold(pointAt(point), point.y - 0.72 * height, until);

    if (!stages.reveal) {
        hold(ahead, until + lead, until + lead);
    }
}

/**
 * 显形一段的眼神：动身之前渐渐转向那一段的标题，停在光里时一直望着它；离开时望向下面那幅配图的正中，
 * 飘过配图的大半之后望回屏幕前。
 */
function revealLooks(
    context: Context,
    motion: TrailMotion,
    stages: Stages,
    hold: (aim: GazeAim, from: number, to: number, before?: number) => void,
): void {
    const { layout } = context;
    const { height, revealTitle } = layout;
    const { reveal, closing } = stages;
    const lead = blend * height;

    if (!reveal) {
        return;
    }

    hold(pointAt(centre(revealTitle)), reveal.arrive, reveal.to, 0.135 * height);

    const media = layout.media.find(({ top }) => top >= layout.reveal.top);

    if (!media) {
        hold(ahead, reveal.to + lead, reveal.to + lead);

        return;
    }

    // 幽灵身体正中降到配图高度的 78% 处时望回屏幕前；樱桃枝开始滑进来时已经望着前方
    const line = media.top + 0.78 * (media.bottom - media.top);
    const passed = Math.min(
        solve(reveal.leave, closing.turn, (s) => sampleTrail(motion, s).y, line),
        closing.slide[0] - lead,
    );

    hold(pointAt(centre(media)), reveal.to + lead, passed);
    hold(ahead, passed + lead, passed + lead);
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

/** 在屏幕上横着走 `dx`、竖着走 `dy` 要留出的滚动距离，按速度上限算，至少 `least`。 */
function travel(dx: number, dy: number, least: number): number {
    return Math.max(least, Math.hypot(dx, dy) / pace);
}

/**
 * 从上一帧飘到文档里的 (x, y) 要留出的滚动距离，按速度上限算，至少 `least`。
 *
 * 那一点跟着页面走：滚得越多，它在屏幕上离幽灵越近，要走的路越短；逐次代入求出刚好够用的距离。
 */
function arrival(previous: TrailKey, x: number, y: number, least: number): number {
    let span = least;

    for (let round = 0; round < 8; round += 1) {
        span = Math.max(least, Math.hypot(x - previous.x, y - previous.y - span) / pace);
    }

    return span;
}

/**
 * 在 `from` 到 `to` 之间找出 `value` 正好等于 `target` 的滚动距离，`value` 在这一段上单调；
 * 两头都在 `target` 的同一边时，返回离它近的一头。
 */
function solve(from: number, to: number, value: (s: number) => number, target: number): number {
    const before = value(from) - target;
    const after = value(to) - target;

    if (before * after > 0) {
        return Math.abs(before) <= Math.abs(after) ? from : to;
    }

    let low = from;
    let high = to;

    for (let round = 0; round < 32; round += 1) {
        const middle = (low + high) / 2;

        if ((value(middle) - target) * before > 0) {
            low = middle;
        } else {
            high = middle;
        }
    }

    return (low + high) / 2;
}

/**
 * 三次曲线在各关键帧上的斜率：停靠的帧为 0，顺着窗口边滑的帧取它自己的斜率，
 * 其余按前后两段算，前后走向相反时为 0，不会冲过头。
 */
function tangentsOf(keys: readonly TrailKey[]): [number, number, number][] {
    return keys.map((current, index) => {
        const before = keys[index - 1];
        const after = keys[index + 1];

        if (current.hold) {
            return [0, 0, 0];
        }

        if (current.glide !== undefined) {
            return [0, current.glide, 0];
        }

        if (!before || !after) {
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
function key(value: Pick<TrailKey, 's' | 'x' | 'y' | 'u'> & Partial<TrailKey>): TrailKey {
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
function pick({ x, y, u, roll, bob }: TrailKey): TrailSample {
    return { x, y, u, roll, bob };
}

/** 望向页面上的一点。 */
function pointAt({ x, y }: { x: number; y: number }): GazeAim {
    return { kind: 'point', x, y };
}

/** 一块矩形的正中。 */
function centre({ left, top, right, bottom }: Box): { x: number; y: number } {
    return { x: (left + right) / 2, y: (top + bottom) / 2 };
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
