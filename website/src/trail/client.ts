import type { TrailArt } from '../art/trail.ts';
import { poseAt, rampAt } from './cues.ts';
import {
    approach,
    type Box,
    leanOf,
    planTrail,
    sampleTrail,
    spring,
    type TrailLayout,
    type TrailMetrics,
    type TrailPlan,
    type TrailSample,
} from './path.ts';
import { build, place, type Scene } from './scene.ts';
import { apply, drive, stateAt, type Track, tracksOf } from './tracks.ts';

/*
 * 首页小幽灵的页面脚本：取来 `trail.json`，在容器里搭好画面，量出页面布局排好路线，再跟着滚动摆放。
 *
 * 位置、姿势、眼神、小手与灯光都只由滚动的距离决定，交给滚动时间线：浏览器按滚动的距离直接算出来，
 * 与页面的滚动在同一帧里，不落后、不抖；不支持滚动时间线的浏览器由每帧的回调按滚动的距离写上同样的样式。
 * 只有顺着方向的倾斜、停着时的上下飘动、演示窗口里做完一步时的反应随时间变化，由每帧的回调摆在里面一层。
 * 滚动的回调里不读布局；标签页藏起来时停下。访客要求减少动态效果时整个拆掉，页面回到静止的样子。
 */

/** 停稳之后上下飘动一个来回的秒数。 */
const bobPeriod = 3.4;

/** 宽屏上飘动的幅度，CSS 像素；幽灵小时按比例减小。 */
const bobHeight = 5;

/** 飘着时轻轻点头：一个来回的秒数，以及往两边各歪多少度。 */
const nod = { period: 3.9, degrees: 1.1 };

/** 贴纸投影在图标网格里挪开的量：身体转过一个角度时，投影仍落在原来的方向上。 */
const castOffset = [6, 14] as const;

/** 演示窗口里做完一步时，幽灵眼睛亮起的毫秒数。 */
const flashTime = 1200;

/** 演示窗口里做完一步、幽灵不在窗口边时轻轻一跳的毫秒数。 */
const hopTime = 420;

/** 轻轻一跳的高度，CSS 像素；幽灵小时按比例减小。 */
const hopHeight = 10;

/** 身体顺着横向速度倾斜：弹簧的固有角频率与阻尼比。停下时身子晃一下再摆正。 */
const leanSpring = { omega: 7, zeta: 0.55 };

/** 横向速度先平滑一下再定倾角：差距在这么多秒后剩下约三分之一。 */
const velocityLag = 0.06;

/** 演示窗口右边一行右端空着的地方：差异区里文件名下面那一行概要，文字靠左。 */
const gripSelector = '.sd-diff-summary';

/** 演示窗口里做完一步时发出的事件。 */
const demoEvents = ['spooky-demo:staged', 'spooky-demo:committed', 'spooky-demo:pushed'] as const;

/** 跟着滚动距离切换、写在 `<html>` 上的开关。 */
const flags = ['trail', 'trailRest', 'trailHome', 'trailLinked'] as const;

/** 页面上各块内容：幽灵横穿页面时从它们之间的空当过。 */
const blockSelector = [
    '.hero .app-icon',
    '.hero .name',
    '.hero h1',
    '.hero .tagline',
    '.hero-demo .actions',
    '.hero-demo .note',
    '.sd-window',
    '.section-header',
    '.diagram',
    '.more',
    '.feature .text',
    '.feature .media',
    '[data-art="reveal"]',
    '.point',
    '.closing [data-art]',
    '.closing h2',
    '.closing .actions',
    '.closing .summary',
    '.site-footer',
].join(', ');

/** 取来的画；拆掉再开启时不再取第二次。 */
let artRequest: Promise<TrailArt> | undefined;

/** 在首页启动小幽灵；访客切换 “减少动态效果” 时跟着拆掉或重新开始。 */
export function startTrail(): void {
    const root = document.querySelector<HTMLElement>('.trail[data-trail-source]');
    const reduce = matchMedia('(prefers-reduced-motion: reduce)');
    let stop: (() => void) | undefined;

    if (!root) {
        return;
    }

    const update = (): void => {
        if (reduce.matches) {
            stop?.();
            stop = undefined;

            return;
        }

        stop ??= run(root);
    };

    reduce.addEventListener('change', update);
    update();
}

/** 搭好画面、开始跟着滚动；返回拆掉一切的函数。 */
function run(root: HTMLElement): () => void {
    let teardown: (() => void) | undefined;
    let cancelled = false;

    artRequest ??= fetch(root.dataset.trailSource ?? '').then(async (response) => {
        if (!response.ok) {
            throw new Error(`trail.json ${response.status}`);
        }

        return (await response.json()) as TrailArt;
    });

    artRequest
        .then((art) => {
            if (!cancelled) {
                teardown = animate(root, art);
            }
        })
        .catch(() => {
            // 取不到画时页面保持静止的样子
            artRequest = undefined;
        });

    return () => {
        cancelled = true;
        teardown?.();
    };
}

/** 由弹簧带着的一个量：当前的值与速度。 */
interface Channel {
    /** 当前的值 */
    value: number;

    /** 每秒变化多少 */
    speed: number;
}

/** 逐帧摆放里面一层的状态。 */
interface Motion {
    /** 上一帧的时间，毫秒 */
    time: number;

    /** 上一帧的滚动距离 */
    s: number;

    /** 上一帧幽灵在屏幕上的 x，用来算横向速度 */
    x: number;

    /** 平滑过的横向速度，px / s */
    velocity: number;

    /** 身体顺着横向速度的倾角，度 */
    lean: Channel;

    /** 飘动的相位，秒 */
    phase: number;

    /** 演示窗口里做完一步的反应到这个时间为止，毫秒 */
    flash: number;
}

/** 排好的路线连同它的布局与轨道；`driven` 为真时轨道已交给滚动时间线。 */
interface Course {
    /** 页面布局 */
    layout: TrailLayout;

    /** 路线 */
    plan: TrailPlan;

    /** 各条轨道 */
    tracks: readonly Track[];

    /** 轨道是否已交给滚动时间线 */
    driven: boolean;
}

/** 量布局、排路线并跟着滚动摆放；返回拆掉一切的函数。 */
function animate(root: HTMLElement, art: TrailArt): () => void {
    const scene = build(root, art);
    const metrics = metricsOf(art, scene.paw?.paint);
    const timeline = 'ScrollTimeline' in window ? new ScrollTimeline({ source: document.documentElement }) : undefined;
    const animations = new Map<Element, Animation>();
    const motion: Motion = {
        time: 0,
        s: scrollY,
        x: 0,
        velocity: 0,
        lean: { value: 0, speed: 0 },
        phase: 0,
        flash: 0,
    };
    let course: Course | undefined;
    let frame = 0;

    // 量出布局、排好路线，换上滚动时间线的关键帧
    const relayout = (): void => {
        const layout = measure();
        const plan = layout ? planTrail(layout, metrics) : undefined;

        cancelAnimationFrame(frame);
        frame = 0;

        // 首页缺了哪一块时退回静止的样子
        if (!layout || !plan) {
            course = undefined;
            root.style.height = '0';
            delete document.documentElement.dataset.trail;

            return;
        }

        const range = document.documentElement.scrollHeight - document.documentElement.clientHeight;
        const tracks = tracksOf(scene, art, plan, layout);
        const driven = timeline !== undefined && range > 0;

        root.style.height = `${layout.end + layout.height}px`;
        place(scene, art, layout);

        if (driven) {
            drive(tracks, art, plan, range, timeline, animations);
        } else {
            animations.forEach((animation) => animation.cancel());
            animations.clear();
        }

        course = { layout, plan, tracks, driven };

        // 先摆好这一帧，再让页面上的画让出幽灵：两者在同一帧里交接，看不出换过
        motion.time = 0;
        tick(performance.now());
        document.documentElement.dataset.trail = '';
    };

    const tick = (now: number): void => {
        frame = 0;

        if (!course) {
            return;
        }

        const seconds = motion.time ? Math.min((now - motion.time) / 1000, 0.05) : 0;
        const moving = step(root, scene, art, course, motion, now, seconds);

        motion.time = now;

        if (moving) {
            frame = requestAnimationFrame(tick);
        }
    };

    // 滚动的回调只负责叫醒下一帧
    const wake = (): void => {
        if (frame || document.hidden) {
            return;
        }

        motion.time = 0;
        frame = requestAnimationFrame(tick);
    };

    const pause = (): void => {
        if (!document.hidden) {
            wake();

            return;
        }

        cancelAnimationFrame(frame);
        frame = 0;
    };

    // 演示窗口里做完一步时，停在窗口边的幽灵眼睛亮一下，别处的轻轻一跳
    const flash = (): void => {
        motion.flash = performance.now() + flashTime;
        wake();
    };

    // 只改了视口的高度时页面本身的尺寸不变，ResizeObserver 不会报告，能滚动的距离却变了
    const resize = (): void => {
        if (document.documentElement.clientHeight !== course?.layout.height) {
            relayout();
        }
    };

    const observer = new ResizeObserver(relayout);

    observer.observe(document.body);
    addEventListener('resize', resize);
    addEventListener('scroll', wake, { passive: true });
    document.addEventListener('visibilitychange', pause);
    demoEvents.forEach((name) => document.addEventListener(name, flash));
    void document.fonts.ready.then(relayout);

    return () => {
        observer.disconnect();
        cancelAnimationFrame(frame);
        animations.forEach((animation) => animation.cancel());
        removeEventListener('resize', resize);
        removeEventListener('scroll', wake);
        document.removeEventListener('visibilitychange', pause);
        demoEvents.forEach((name) => document.removeEventListener(name, flash));
        scene.lamps?.remove();
        scene.beams.forEach((beam) => beam.style.removeProperty('opacity'));
        root.replaceChildren();
        root.style.removeProperty('height');
        root.removeAttribute('data-still');

        for (const name of flags) {
            delete document.documentElement.dataset[name];
        }
    };
}

/**
 * 摆好一帧：里面一层加上倾斜、飘动与做完一步时的反应，切换跟着滚动距离的几个开关；
 * 轨道没有交给滚动时间线时，另按这一刻的滚动距离写上各个元素的样式。
 *
 * 返回是否还要下一帧：滚动停下、身子停稳、也不飘动时不再请求。
 */
function step(
    root: HTMLElement,
    scene: Scene,
    art: TrailArt,
    course: Course,
    motion: Motion,
    now: number,
    seconds: number,
): boolean {
    const { plan, tracks, driven } = course;
    const s = scrollY;
    const sample = sampleTrail(plan, s);

    if (!driven) {
        apply(tracks, stateAt(art, plan, s));
    }

    // 横向速度只算幽灵自己在屏幕上的移动，平滑之后定倾角
    const velocity = seconds > 0 ? (sample.x - motion.x) / seconds : 0;

    motion.velocity = approach(motion.velocity, velocity, seconds, velocityLag);
    motion.x = sample.x;
    motion.phase += seconds;

    // 停在窗口边时做完一步，眼睛亮一下；在别处时轻轻一跳，跳起的高度从做完那一刻起先升后落
    const flashing = now < motion.flash;
    const atWindow = plan.hide.mode === 'side' && s >= plan.hide.from && s <= plan.hide.to;
    const hop = flashing && !atWindow
        ? Math.sin(Math.PI * Math.min((now - motion.flash + flashTime) / hopTime, 1))
        : 0;

    scene.eyeLayer.classList.toggle('flash', flashing && atWindow);
    toggles(root, plan, s);

    // 投影的偏移按正显示得多的那个姿势的画面比例算
    const blend = poseAt(plan.poses, s);
    const frameWidth = art.poses[blend.t < 0.5 ? blend.from : blend.to].viewBox[2];
    const swaying = sway(scene, art, motion, sample, frameWidth, hop, seconds);
    const scrolled = s !== motion.s;

    motion.s = s;

    return scrolled || swaying || sample.bob > 0 || flashing;
}

/**
 * 里层的倾斜、飘动与轻轻一跳：身体顺着横向速度倾斜，由弹簧带着，停下时晃一下再摆正；飘着时上下浮动、轻轻点头。
 *
 * 投影另补上转动带来的偏移，`frameWidth` 是正显示的姿势画面在图标网格里的宽度。返回身子是否还在晃。
 */
function sway(
    scene: Scene,
    art: TrailArt,
    motion: Motion,
    sample: TrailSample,
    frameWidth: number,
    hop: number,
    seconds: number,
): boolean {
    const [width] = art.size;
    const scale = sample.u / art.unit;
    const leaning = pull(motion.lean, leanOf(motion.velocity), seconds) || Math.abs(motion.velocity) > 0.5;
    const nodding = sample.bob * nod.degrees * Math.sin(2 * Math.PI * (motion.phase / nod.period + 0.3));
    const angle = motion.lean.value + nodding;

    // 上下浮动与跳起都是屏幕上竖直方向的位移，宽屏上按原幅度，幽灵小时按比例减小
    const fit = Math.min(scale / 0.79, 1);
    const bob = sample.bob * Math.sin((motion.phase * 2 * Math.PI) / bobPeriod) * bobHeight;
    const lift = (bob - hop * hopHeight) * fit;
    const [liftX, liftY] = local(0, lift, sample.roll, scale);
    const body = `translate(${liftX.toFixed(2)}px, ${liftY.toFixed(2)}px) rotate(${angle.toFixed(2)}deg)`;

    scene.ghosts.edge.inner.style.transform = body;
    scene.ghosts.paint.inner.style.transform = body;
    scene.ghosts.paw.inner.style.transform = body;

    // 投影画在身体右下方：身体一共转过翻转加倾斜的角度，把投影挪回原来的方向
    const grid = (width / frameWidth) * scale;
    const radians = ((sample.roll + angle) * Math.PI) / 180;
    const [dx, dy] = [castOffset[0] * grid, castOffset[1] * grid];
    const shiftX = dx - (dx * Math.cos(radians) - dy * Math.sin(radians));
    const shiftY = dy - (dx * Math.sin(radians) + dy * Math.cos(radians));
    const [castX, castY] = local(shiftX, shiftY + lift, sample.roll, scale);

    scene.ghosts.shadow.inner.style.transform =
        `translate(${castX.toFixed(2)}px, ${castY.toFixed(2)}px) rotate(${angle.toFixed(2)}deg)`;

    return leaning;
}

/**
 * 跟着滚动距离切换的几个开关：图标与满怀自己显示幽灵的时候，以及示意图里的 SSH 连接开始传输之后。
 */
function toggles(root: HTMLElement, plan: TrailPlan, s: number): void {
    const page = document.documentElement;
    const rest = s < plan.rest;
    const home = s >= plan.home;

    flag(page, 'trailRest', rest);
    flag(page, 'trailHome', home);

    // 示意图里机架的灯亮着时，SSH 连接才在传输
    flag(page, 'trailLinked', rampAt(plan.lamps, s) > 0);

    if (root.hasAttribute('data-still') !== (rest || home)) {
        root.toggleAttribute('data-still', rest || home);
    }
}

/** 量出排路线要用的页面布局；首页缺了哪一块时返回空，页面保持静止。 */
function measure(): TrailLayout | undefined {
    const one = (selector: string): Box | undefined => {
        const found = document.querySelector(selector);

        return found ? boxOf(found) : undefined;
    };
    const hero = one('.hero .app-icon');
    const headline = one('.hero h1');
    const window = one('.sd-window');
    const server = one('[data-art="server"]');
    const reveal = one('[data-art="reveal"]');
    const revealTitle = document.querySelector('[data-art="reveal"]')?.closest('.feature')?.querySelector('h3');
    const armful = one('.closing [data-art]');
    const title = one('.closing h2');
    const heading = union(
        ['.hero .name', '.hero h1', '.hero .tagline'].flatMap((selector) => one(selector) ?? []),
    );
    const column = union([...document.querySelectorAll('.diagram, .point, .feature')].map(boxOf));

    if (!hero || !headline || !window || !server || !reveal || !revealTitle || !armful || !title) {
        return undefined;
    }

    if (!heading || !column) {
        return undefined;
    }

    const height = document.documentElement.clientHeight;
    const page = document.body.getBoundingClientRect().height;
    const grip = one(gripSelector);

    return {
        width: document.documentElement.clientWidth,
        height,
        header: document.querySelector('header.header')?.getBoundingClientRect().bottom ?? 0,
        end: Math.max(page - height, 0),
        column: { left: column.left, right: column.right },
        hero,
        heading,
        headline,
        window,

        // 那一行一直伸到窗口右边时，小手扒在它的右端
        ...(grip && grip.right >= window.right - 2 ? { grip: (grip.top + grip.bottom) / 2 } : {}),
        server,
        media: [...document.querySelectorAll('.feature .media')].map(boxOf).toSorted((a, b) => a.top - b.top),
        reveal,
        revealTitle: boxOf(revealTitle),
        armful,
        title,
        blocks: [...document.querySelectorAll(blockSelector)].map(boxOf),
    };
}

/** 由 JSON 里的画取出排路线要用的尺寸；小手的位置由搭好的画量出。 */
function metricsOf(art: TrailArt, paw: SVGSVGElement | undefined): TrailMetrics {
    const { offset, width, viewBox, cherry } = art.branch;

    return {
        unit: art.unit,
        anchors: art.anchors,
        hideEdge: art.size[0] / 2 - art.paw.edge,
        pawDrop: pawDrop(art, paw),
        branchReach: offset[0] + width,
        branchSpan: [offset[1], offset[1] + (width * viewBox[3]) / viewBox[2]],
        cherry,
    };
}

/** 姿势原大时，小手成品那一层的中心比画面正中低多少 px。 */
function pawDrop(art: TrailArt, paw: SVGSVGElement | undefined): number {
    const layer = paw?.querySelector<SVGGElement>('g[data-layer="paw"]');

    if (!layer) {
        return 0;
    }

    const box = layer.getBBox();
    const [, top, width, height] = art.paw.viewBox;

    return (box.y + box.height / 2 - (top + height / 2)) * (art.size[0] / width);
}

/** 屏幕上的一段位移换进外层自身的坐标：外层转过 `roll` 度、缩放到 `scale`，里层按换出的量平移，落到屏幕上正好是这一段。 */
function local(dx: number, dy: number, roll: number, scale: number): [number, number] {
    const radians = (roll * Math.PI) / 180;
    const cos = Math.cos(radians);
    const sin = Math.sin(radians);

    return [(dx * cos + dy * sin) / scale, (dy * cos - dx * sin) / scale];
}

/** 弹簧带着倾角朝目标走过这么多秒；离目标与速度都足够小时停在目标上。返回它是否还在动。 */
function pull(channel: Channel, target: number, seconds: number): boolean {
    [channel.value, channel.speed] = spring(
        channel.value,
        channel.speed,
        target,
        seconds,
        leanSpring.omega,
        leanSpring.zeta,
    );

    if (Math.abs(channel.value - target) > 0.01 || Math.abs(channel.speed) > 0.01) {
        return true;
    }

    channel.value = target;
    channel.speed = 0;

    return false;
}

/** 元素在文档坐标里的范围。 */
function boxOf(target: Element): Box {
    const rect = target.getBoundingClientRect();

    return {
        left: rect.left,
        top: rect.top + scrollY,
        right: rect.right,
        bottom: rect.bottom + scrollY,
    };
}

/** 几块矩形合起来的范围；一块都没有时返回空。 */
function union(boxes: readonly Box[]): Box | undefined {
    if (boxes.length === 0) {
        return undefined;
    }

    return {
        left: Math.min(...boxes.map(({ left }) => left)),
        top: Math.min(...boxes.map(({ top }) => top)),
        right: Math.max(...boxes.map(({ right }) => right)),
        bottom: Math.max(...boxes.map(({ bottom }) => bottom)),
    };
}

/** 设上或去掉 `<html>` 上的一个开关，值没变时不碰。 */
function flag(root: HTMLElement, name: string, on: boolean): void {
    if ((name in root.dataset) === on) {
        return;
    }

    if (on) {
        root.dataset[name] = '';
    } else {
        delete root.dataset[name];
    }
}
