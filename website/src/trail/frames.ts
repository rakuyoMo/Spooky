/*
 * 滚动时间线的关键帧：把随滚动距离变化的几样量按距离取样，再去掉按直线插值也贴合的帧。
 *
 * 浏览器在相邻两帧之间按直线插值，各帧的位置是在能滚动的整段距离里的比例。这里只有不碰页面的纯函数。
 */

/** 一条轨道：从某个滚动距离上的样子取出几个数，以及按直线插值时各自允许的误差。 */
export interface FrameTrack<State> {
    /** 这时的几个数 */
    values: (state: State) => readonly number[];

    /** 各个数按直线插值时允许的误差 */
    tolerance: readonly number[];
}

/** 轨道上的一帧。 */
export interface TrackFrame {
    /** 在能滚动的整段距离里的位置，0 到 1 */
    offset: number;

    /** 这时的几个数 */
    values: readonly number[];
}

/** 每隔多少 px 取一次样：拐得最急的地方，相邻两次取样之间按直线走也只偏开零点几 px。 */
const sampleStep = 2;

/**
 * 把几条轨道排成滚动时间线上的关键帧。
 *
 * 整段距离每隔 `sampleStep` 取一次样，`marks` 里的距离另各取一次；每次取样只算一次 `stateAt`，各条轨道共用。
 * 之后每条轨道各自去掉按直线插值也贴合的帧，误差不超过它的 `tolerance`。`range` 是能滚动的整段距离，大于 0。
 */
export function scrollFrames<State>(
    range: number,
    marks: readonly number[],
    stateAt: (s: number) => State,
    tracks: readonly FrameTrack<State>[],
): TrackFrame[][] {
    const points = new Set<number>([0, range]);

    for (let s = sampleStep; s < range; s += sampleStep) {
        points.add(s);
    }

    for (const mark of marks) {
        if (mark > 0 && mark < range) {
            points.add(mark);
        }
    }

    const distances = [...points].toSorted((a, b) => a - b);
    const states = distances.map(stateAt);

    return tracks.map((track) =>
        simplify(
            distances.map((s, index) => ({ offset: s / range, values: track.values(states[index] as State) })),
            track.tolerance,
        ),
    );
}

/**
 * 去掉按直线插值也贴合的帧：首尾两帧之间离直线最远的一帧超出误差时留下它，再对两边各自这样做。
 *
 * 各个数的偏离先除以各自的误差，取最大的一个比较。
 */
function simplify(frames: readonly TrackFrame[], tolerance: readonly number[]): TrackFrame[] {
    const keep = new Uint8Array(frames.length);
    const pending: [number, number][] = [[0, frames.length - 1]];

    keep[0] = 1;
    keep[frames.length - 1] = 1;

    while (pending.length > 0) {
        const [from, to] = pending.pop() ?? [0, 0];
        const [worst, index] = farthest(frames, from, to, tolerance);

        if (worst > 1) {
            keep[index] = 1;
            pending.push([from, index], [index, to]);
        }
    }

    return frames.filter((_, index) => keep[index] === 1);
}

/** `from` 与 `to` 两帧之间离直线最远的一帧：偏离按误差折算后的大小，以及它的序号。 */
function farthest(
    frames: readonly TrackFrame[],
    from: number,
    to: number,
    tolerance: readonly number[],
): [number, number] {
    const start = frames[from];
    const end = frames[to];
    let worst = 0;
    let index = from;

    if (!start || !end) {
        return [worst, index];
    }

    for (let middle = from + 1; middle < to; middle += 1) {
        const frame = frames[middle];

        if (!frame) {
            continue;
        }

        const t = (frame.offset - start.offset) / (end.offset - start.offset);

        // 各个数里偏得最多的一个，按它自己的误差折算
        const off = frame.values.reduce((most, value, channel) => {
            const first = start.values[channel] ?? 0;
            const line = first + ((end.values[channel] ?? 0) - first) * t;

            return Math.max(most, Math.abs(value - line) / (tolerance[channel] ?? 1));
        }, 0);

        if (off > worst) {
            worst = off;
            index = middle;
        }
    }

    return [worst, index];
}
