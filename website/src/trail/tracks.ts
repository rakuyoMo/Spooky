import type { TrailArt, TrailEye, TrailPose, TrailPoseName } from '../art/trail.ts';
import { clamp, gazeAt, poseAt, progress, rampAt, smoothstep } from './cues.ts';
import { type FrameTrack, scrollFrames, type TrackFrame } from './frames.ts';
import { sampleTrail, type TrailLayout, type TrailPlan, type TrailSample } from './path.ts';
import { imageKey, type Scene } from './scene.ts';

/*
 * 首页小幽灵跟着滚动变化的一切：按滚动的距离算出画面里各样东西的值，排成滚动时间线的关键帧交给浏览器；
 * 浏览器不支持滚动时间线时，由每帧的回调按滚动的距离直接写上同样的样式。
 *
 * 换姿势时新的一张先淡入、旧的一张再淡出：贴纸边与成品始终有一张完全不透明，看不出中间透出背景；
 * 投影本来是半透明的，两张交叉淡入淡出，叠在一起时不会变深。两个姿势之间有过渡画时，按先后一张张换过去。
 */

/** 某个滚动距离上，画面里各样东西的值。 */
export interface TrailState {
    /** 幽灵的位置、大小与翻转 */
    sample: TrailSample;

    /** 各张姿势的画显示多少：贴纸边与成品两档一个值，投影一个值；不在这里的画不显示 */
    weights: Map<string, readonly [number, number]>;

    /** 两只眼睛在姿势画面里的位置、转角与大小 */
    eyes: readonly TrailEye[];

    /** 另画的眼睛显示多少：落进满怀时让给满怀自己的眼睛 */
    eyesShown: number;

    /** 眼睛亮成四角星的程度 */
    lit: number;

    /** 扒着窗口边的小手伸出的程度 */
    paw: number;

    /** 示意图服务器的灯亮的程度 */
    lamps: number;

    /** 显形那台服务器的光束与灯亮的程度 */
    beam: number;

    /** 樱桃枝滑进来的程度 */
    slide: number;

    /** 枝上的樱桃还剩多少 */
    cherries: number;

    /** 满月的不透明度 */
    moon: number;

    /** 举手探身的投影换成页面上颜色的程度 */
    cast: number;
}

/** 一条轨道连同它摆放的元素，以及由那几个数写出的样式。 */
export interface Track extends FrameTrack<TrailState> {
    /** 摆放的元素，样式都相同 */
    targets: readonly Element[];

    /** 由那几个数写出的样式 */
    style: (values: readonly number[]) => Keyframe;
}

/** 取某个滚动距离上画面里各样东西的值。 */
export function stateAt(art: TrailArt, plan: TrailPlan, s: number): TrailState {
    const sample = sampleTrail(plan, s);
    const blend = poseAt(plan.poses, s);
    const chain = chainOf(art, blend.from, blend.to);
    const last = chain.length - 1;
    const step = clamp(Math.floor(blend.t * last), 0, Math.max(last - 1, 0));
    const f = last > 0 ? blend.t * last - step : 0;
    const lower = chain[step] ?? imageKey(blend.from);
    const upper = chain[step + 1] ?? lower;
    const weights = new Map<string, readonly [number, number]>();

    // 新的先淡入、旧的再淡出；投影交叉淡入淡出
    weights.set(lower, [Math.min(1, 2 * (1 - f)), 1 - f]);

    if (upper !== lower) {
        weights.set(upper, [Math.min(1, 2 * f), f]);
    }

    const gaze = gazeAt(plan.gaze, s, sample);
    const below = eyesAt(imageOf(art, lower).eyes, gaze);
    const above = eyesAt(imageOf(art, upper).eyes, gaze);
    const armful = weights.get(imageKey('armful'))?.[0] ?? 0;

    return {
        sample,
        weights,
        eyes: below.map((eye, index) => mixEye(eye, above[index] ?? eye, f)),
        eyesShown: 1 - armful,
        lit: smoothstep(progress(s, plan.lit[0], plan.lit[1])),
        paw: plan.paw ? rampAt(plan.paw, s) : 0,
        lamps: rampAt(plan.lamps, s),
        beam: plan.beam ? rampAt(plan.beam, s) : 0,
        slide: easeOut(progress(s, plan.branch.from, plan.branch.to)),
        cherries: 1 - armful,
        moon: progress(s, plan.moon[0], plan.moon[1]),
        cast: progress(s, plan.plate[0], plan.plate[1]),
    };
}

/** 画面里每个跟着滚动变化的元素各一条轨道。 */
export function tracksOf(scene: Scene, art: TrailArt, plan: TrailPlan, layout: TrailLayout): Track[] {
    const fade = (targets: readonly Element[], value: (state: TrailState) => number): Track => ({
        targets,
        values: (state) => [value(state)],
        tolerance: [0.004],
        style: ([opacity = 0]) => ({ opacity: Number(opacity.toFixed(3)) }),
    });

    const tracks: Track[] = [
        {
            targets: Object.values(scene.ghosts).map(({ outer }) => outer),
            values: ({ sample: { x, y, u, roll } }) => [x, y, u, roll],
            tolerance: [0.25, 0.25, 0.0008, 0.2],
            style: ([x = 0, y = 0, u = 0, roll = 0]) => ({ transform: placement(art, x, y, u, roll) }),
        },
    ];

    for (const [key, image] of scene.images) {
        const shown = (state: TrailState): readonly [number, number] => state.weights.get(key) ?? [0, 0];

        for (const tier of ['edge', 'paint'] as const) {
            const svg = image.tiers[tier];

            if (svg) {
                tracks.push(fade([svg], (state) => shown(state)[0]));
            }
        }

        // 举手探身的投影分成落在底板上与落在页面上的两份，离开底板时换过去
        if (key === imageKey('rise') && scene.casts) {
            tracks.push(
                fade([scene.casts.page], (state) => shown(state)[1] * state.cast),
                fade([scene.casts.plate], (state) => shown(state)[1] * (1 - state.cast)),
            );
        } else if (image.tiers.shadow) {
            tracks.push(fade([image.tiers.shadow], (state) => shown(state)[1]));
        }
    }

    scene.eyes.forEach(({ holder, oval, sparkle }, index) => {
        tracks.push(
            {
                targets: [holder],
                values: ({ eyes }) => {
                    const { x, y, angle, size } = eyes[index] ?? { x: 0, y: 0, angle: 0, size: 1 };

                    return [x, y, angle, size];
                },
                tolerance: [0.15, 0.15, 0.3, 0.004],
                style: ([x = 0, y = 0, angle = 0, size = 1]) => ({
                    transform: `translate(${x.toFixed(2)}px, ${y.toFixed(2)}px) rotate(${angle.toFixed(2)}deg) `
                        + `scale(${size.toFixed(4)})`,
                }),
            },
            fade([oval], (state) => 1 - state.lit),
            fade([sparkle], (state) => state.lit),
        );
    });

    tracks.push(
        fade([scene.eyeLayer], (state) => state.eyesShown),
        fade(scene.cherries, (state) => state.cherries),
        fade([scene.moon], (state) => state.moon),
        fade(scene.beams, (state) => state.beam),
        branchTrack(scene, art, plan, layout),
    );

    if (scene.lamps) {
        tracks.push(fade([scene.lamps], (state) => state.lamps));
    }

    if (scene.paw) {
        tracks.push({
            targets: [scene.paw.shadow, scene.paw.paint],
            values: (state) => [art.paw.slide * (1 - state.paw), state.paw],
            tolerance: [0.1, 0.004],
            style: ([shift = 0, opacity = 0]) => ({
                transform: `translateX(${shift.toFixed(2)}px)`,
                opacity: Number(opacity.toFixed(3)),
            }),
        });
    }

    return tracks;
}

/**
 * 把各条轨道排成滚动时间线上的关键帧。
 *
 * 换姿势时每一步的开头、正中与结尾都另取一帧：新的一张在正中正好完全不透明，旧的一张在正中之前一直完全不透明，
 * 浏览器在这几帧之间按直线插值也保持这一点。`range` 是能滚动的整段距离，大于 0。
 */
export function framesOf(
    tracks: readonly FrameTrack<TrailState>[],
    art: TrailArt,
    plan: TrailPlan,
    range: number,
): TrackFrame[][] {
    const marks = [...plan.keys.map(({ s }) => s), ...blendMarks(art, plan)];

    return scrollFrames(range, marks, (s) => stateAt(art, plan, s), tracks);
}

/** 把各条轨道的关键帧换到各个元素的动画上；元素还没有动画时新建一个。`range` 是能滚动的整段距离，大于 0。 */
export function drive(
    tracks: readonly Track[],
    art: TrailArt,
    plan: TrailPlan,
    range: number,
    timeline: AnimationTimeline,
    animations: Map<Element, Animation>,
): void {
    const frames = framesOf(tracks, art, plan, range);

    tracks.forEach((track, index) => {
        const keyframes = (frames[index] ?? []).map(({ offset, values }) => ({ offset, ...track.style(values) }));

        for (const target of track.targets) {
            const animation = animations.get(target) ?? target.animate([], { timeline, fill: 'both' });

            animations.set(target, animation);
            (animation.effect as KeyframeEffect | null)?.setKeyframes(keyframes);
        }
    });
}

/** 浏览器不支持滚动时间线时，按这一刻的值直接写上各个元素的样式。 */
export function apply(tracks: readonly Track[], state: TrailState): void {
    for (const track of tracks) {
        const style = track.style(track.values(state));

        for (const target of track.targets) {
            Object.assign((target as HTMLElement | SVGElement).style, style);
        }
    }
}

/** 外层的摆放：身体正中落在 (x, y)，转过 `roll` 度，按幽灵自身坐标的单位长度 `u` 缩放。 */
export function placement(art: TrailArt, x: number, y: number, u: number, roll: number): string {
    const [width, height] = art.size;

    return [
        `translate(${(x - width / 2).toFixed(2)}px, ${(y - height / 2).toFixed(2)}px)`,
        `rotate(${roll.toFixed(2)}deg)`,
        `scale(${(u / art.unit).toFixed(4)})`,
    ].join(' ');
}

/** 樱桃枝从页面右边滑进来：两份一起平移，位置与缩放由路线定。 */
function branchTrack(scene: Scene, art: TrailArt, plan: TrailPlan, layout: TrailLayout): Track {
    const { x, y, scale } = plan.branch;
    const left = x + art.branch.offset[0] * scale;
    const top = y + art.branch.offset[1] * scale;
    const away = layout.width - left + 8;

    return {
        targets: scene.branches,
        values: (state) => [(1 - state.slide) * away],
        tolerance: [0.25],
        style: ([shift = 0]) => ({
            transform: `translate(${(left + shift).toFixed(2)}px, ${top.toFixed(2)}px) scale(${scale.toFixed(4)})`,
        }),
    };
}

/**
 * 换姿势的各段里，每一步的开头、正中与结尾所在的滚动距离。
 *
 * 一段里换到了 `t = smoothstep(进度)`，经过 n 张画时第 k 步的开头与正中在 `t = k / (n - 1)` 与 `t = (k + 0.5) / (n - 1)` 处，
 * 由 smoothstep 的反函数换回滚动距离。
 */
function blendMarks(art: TrailArt, plan: TrailPlan): number[] {
    return plan.poses.flatMap((span, index) => {
        const next = plan.poses[index + 1];

        if (!next || next.from <= span.to) {
            return [span.from, span.to];
        }

        const steps = chainOf(art, span.pose, next.pose).length - 1;

        return [span.from, ...Array.from({ length: 2 * steps + 1 }, (_, half) => {
            const t = half / (2 * steps);
            const x = 0.5 - Math.sin(Math.asin(1 - 2 * t) / 3);

            return span.to + (next.from - span.to) * x;
        })];
    });
}

/** 从一个姿势换到另一个时依次经过的画：两头的姿势，中间是按先后排好的过渡画。 */
function chainOf(art: TrailArt, from: TrailPoseName, to: TrailPoseName): string[] {
    if (from === to) {
        return [imageKey(from)];
    }

    const forward = art.morphs[`${from}>${to}`];
    const backward = art.morphs[`${to}>${from}`];
    const between = forward
        ? forward.map((_, index) => imageKey(`${from}>${to}`, index))
        : (backward ?? []).map((_, index) => imageKey(`${to}>${from}`, index)).toReversed();

    return [imageKey(from), ...between, imageKey(to)];
}

/** 键对应的那张姿势的画。 */
function imageOf(art: TrailArt, key: string): TrailPose {
    const [name = '', index] = key.split('#');
    const image = index === undefined
        ? art.poses[name as TrailPoseName]
        : art.morphs[name as keyof TrailArt['morphs']]?.[Number(index)];

    if (!image) {
        throw new Error(`没有这张姿势的画：${key}`);
    }

    return image;
}

/** 眼睛望向 `gaze` 时的位置：在九格里相邻的四格之间按两个方向插值。 */
function eyesAt(grid: TrailPose['eyes'], [gx, gy]: readonly [number, number]): TrailEye[] {
    const x = clamp(gx, -1, 1) + 1;
    const y = clamp(gy, -1, 1) + 1;
    const column = Math.min(Math.floor(x), 1);
    const row = Math.min(Math.floor(y), 1);
    const cell = (r: number, c: number): readonly TrailEye[] => grid[r * 3 + c] ?? [];
    const top = cell(row, column);
    const topRight = cell(row, column + 1);
    const bottom = cell(row + 1, column);
    const bottomRight = cell(row + 1, column + 1);

    return top.map((eye, index) => {
        const upper = mixEye(eye, topRight[index] ?? eye, x - column);
        const lower = mixEye(bottom[index] ?? eye, bottomRight[index] ?? eye, x - column);

        return mixEye(upper, lower, y - row);
    });
}

/** 两只眼睛的位置、转角与大小按 `t` 插值。 */
function mixEye(from: TrailEye, to: TrailEye, t: number): TrailEye {
    return {
        x: from.x + (to.x - from.x) * t,
        y: from.y + (to.y - from.y) * t,
        angle: from.angle + (to.angle - from.angle) * t,
        size: from.size + (to.size - from.size) * t,
    };
}

/** 先快后慢的缓动。 */
function easeOut(t: number): number {
    return 1 - (1 - t) ** 3;
}
