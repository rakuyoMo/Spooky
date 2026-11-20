import type { TrailPoseName } from '../art/trail.ts';

/*
 * 跟着滚动变化的几样东西：幽灵换姿势、眼睛望向哪里，以及先亮起再熄灭的灯光、伸出又缩回的小手。
 *
 * 它们的时机都由路线排好，这里按滚动的距离取出那时的值，只有不碰页面的纯函数。
 */

/** 一段先升后落的量：在 [0] 到 [1] 之间从 0 渐渐升到 1，在 [2] 到 [3] 之间渐渐落回 0。 */
export type Ramp = readonly [number, number, number, number];

/** 一个姿势完整显示的一段；相邻两段之间渐渐换成后一段的姿势。 */
export interface PoseSpan {
    /** 姿势 */
    pose: TrailPoseName;

    /** 从这个滚动距离起完整显示 */
    from: number;

    /** 到这个滚动距离为止完整显示 */
    to: number;
}

/** 某个滚动距离上的姿势：正从 `from` 换成 `to`，换到了 `t`，0 到 1；不在过渡里时两者相同。 */
export interface PoseBlend {
    /** 换出去的姿势 */
    from: TrailPoseName;

    /** 换进来的姿势 */
    to: TrailPoseName;

    /** 换到了多少 */
    t: number;
}

/**
 * 眼睛望向的目标：`ahead` 是望着屏幕前；`side` 是身体自身坐标里的一个方向，x 往右、y 往下为正，长度不超过 1；
 * `point` 是页面上的一点，跟着页面走。
 */
export type GazeAim =
    | { kind: 'ahead' }
    | { kind: 'side'; x: number; y: number }
    | { kind: 'point'; x: number; y: number };

/** 眼神的一站：滚到这里时正好望着 `aim`，两站之间渐渐转过去。 */
export interface GazeStop {
    /** 滚动的距离 */
    s: number;

    /** 望向的目标 */
    aim: GazeAim;
}

/** 幽灵在某个滚动距离上的位置、单位长度与翻过的角度：望向页面上的一点时，按它算出眼睛转向哪边。 */
export interface GazeOrigin {
    /** 身体正中的 x */
    x: number;

    /** 身体正中的 y */
    y: number;

    /** 幽灵自身坐标的一个单位有多少 CSS 像素 */
    u: number;

    /** 累计翻过的角度 */
    roll: number;
}

/** 望向页面上的一点时，离身体正中不到这么多个自身单位的点只让眼睛偏过去一部分，贴得很近时眼神不乱晃。 */
const gazeReach = 600;

/** 取某个滚动距离上的姿势：落在某一段里时就是那一段的姿势，落在两段之间时按先慢后快再慢的进度换过去。 */
export function poseAt(spans: readonly PoseSpan[], s: number): PoseBlend {
    const index = lastAtOrBefore(spans, s, ({ from }) => from);
    const span = spans[Math.max(index, 0)];
    const next = spans[index + 1];

    if (!span) {
        throw new Error('没有排好姿势');
    }

    if (index < 0 || !next || s <= span.to) {
        return { from: span.pose, to: span.pose, t: 0 };
    }

    return { from: span.pose, to: next.pose, t: smoothstep(progress(s, span.to, next.from)) };
}

/**
 * 取某个滚动距离上眼睛望向的方向，换进身体自身坐标：x 往右、y 往下为正，长度不超过 1。
 *
 * 两站之间按先慢后快再慢的进度从前一站的方向转到后一站；望向页面上的一点时，方向按 `origin` 算。
 */
export function gazeAt(stops: readonly GazeStop[], s: number, origin: GazeOrigin): [number, number] {
    const index = Math.max(lastAtOrBefore(stops, s, (stop) => stop.s), 0);
    const stop = stops[index];
    const next = stops[index + 1];

    if (!stop) {
        throw new Error('没有排好眼神');
    }

    const [x0, y0] = aimAt(stop.aim, origin);
    const t = next && next.s > stop.s ? smoothstep(progress(s, stop.s, next.s)) : 0;
    const [x1, y1] = next ? aimAt(next.aim, origin) : [x0, y0];

    // 翻过的角度要转回来：屏幕上的方向换成身体自身的方向
    const radians = (origin.roll * Math.PI) / 180;
    const x = x0 + (x1 - x0) * t;
    const y = y0 + (y1 - y0) * t;

    return [x * Math.cos(radians) + y * Math.sin(radians), y * Math.cos(radians) - x * Math.sin(radians)];
}

/** 取一段先升后落的量在某个滚动距离上的值：升与落都先慢后快再慢。 */
export function rampAt(ramp: Ramp, s: number): number {
    const [riseFrom, riseTo, fallFrom, fallTo] = ramp;

    return smoothstep(progress(s, riseFrom, riseTo)) * (1 - smoothstep(progress(s, fallFrom, fallTo)));
}

/** `value` 在 `from` 到 `to` 之间走了多少，0 到 1。 */
export function progress(value: number, from: number, to: number): number {
    return to > from ? clamp((value - from) / (to - from), 0, 1) : Number(value >= to);
}

/** 两头斜率为 0 的缓动。 */
export function smoothstep(t: number): number {
    return t * t * (3 - 2 * t);
}

/** 把值限制在范围内。 */
export function clamp(value: number, low: number, high: number): number {
    return Math.min(Math.max(value, low), high);
}

/** 一个目标的方向，屏幕上的方向；望向页面上的一点时按幽灵这时的位置算。 */
function aimAt(aim: GazeAim, origin: GazeOrigin): readonly [number, number] {
    switch (aim.kind) {
        case 'ahead':
            return [0, 0];

        case 'side':
            return [aim.x, aim.y];

        case 'point': {
            const dx = aim.x - origin.x;
            const dy = aim.y - origin.y;
            const reach = Math.max(Math.hypot(dx, dy), gazeReach * origin.u);

            return [dx / reach, dy / reach];
        }
    }
}

/** 按 `at` 排好的一列里，最后一个 `at` 不超过 `value` 的序号；第一个就超过时为 -1。 */
function lastAtOrBefore<T>(items: readonly T[], value: number, at: (item: T) => number): number {
    let low = -1;
    let high = items.length;

    while (high - low > 1) {
        const middle = (low + high) >> 1;
        const item = items[middle];

        if (item !== undefined && at(item) <= value) {
            low = middle;
        } else {
            high = middle;
        }
    }

    return low;
}
