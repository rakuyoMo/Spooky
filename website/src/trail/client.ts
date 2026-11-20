import type { TrailArt, TrailPart, TrailPoseName, TrailTier } from '../art/trail.ts';
import {
    approach,
    type Box,
    leanOf,
    planTrail,
    progress,
    sampleTrail,
    type TrailLayout,
    type TrailMetrics,
    type TrailPlan,
    type TrailSample,
} from './path.ts';

/*
 * 首页小幽灵的页面脚本：取来 `trail.json`，在容器里搭好各档的画，量出页面布局排好路线，再跟着滚动逐帧摆放。
 *
 * 每帧只改 `transform` 与 `opacity`，滚动的回调里不读布局；标签页藏起来时停下。
 * 访客要求减少动态效果时整个拆掉，页面回到静止的样子。
 */

/** 幽灵跟上滚动的快慢：差距在这么多秒后剩下约三分之一。 */
const lag = 0.18;

/** 停稳之后上下飘动一个来回的秒数。 */
const bobPeriod = 3.4;

/** 宽屏上飘动的幅度，CSS 像素；幽灵小时按比例减小。 */
const bobHeight = 5;

/** 贴纸投影在图标网格里挪开的量：身体转过一个角度时，投影仍落在原来的方向上。 */
const castOffset = [6, 14] as const;

/** 演示窗口里做完一步时，幽灵眼睛亮起的毫秒数。 */
const flashTime = 1200;

/** 演示窗口里做完一步、幽灵不在窗口边时轻轻一跳的毫秒数。 */
const hopTime = 420;

/** 轻轻一跳的高度，CSS 像素；幽灵小时按比例减小。 */
const hopHeight = 10;

/** 演示窗口右边一行右端空着的地方：差异区里文件名下面那一行概要，文字靠左。 */
const gripSelector = '.sd-diff-summary';

/** SVG 的命名空间。 */
const svgNamespace = 'http://www.w3.org/2000/svg';

/** 演示窗口里做完一步时发出的事件。 */
const demoEvents = ['spooky-demo:staged', 'spooky-demo:committed', 'spooky-demo:pushed'] as const;

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

/** 搭好的画面里，每帧要改的元素。 */
interface Scene {
    /** 投影、贴纸边、成品三档里的幽灵，以及扒着窗口边的小手；摆放方式相同 */
    ghosts: Record<'shadow' | 'edge' | 'paint' | 'paw', HTMLElement>;

    /** 各个姿势在各档里的画 */
    poses: Map<TrailPoseName, SVGSVGElement[]>;

    /** 举手探身的投影：落在图标底板上的一份与落在页面上的一份 */
    casts: { plate: SVGGElement; page: SVGGElement } | undefined;

    /** 投影与贴纸边两档里的樱桃枝 */
    branches: HTMLElement[];

    /** 满怀背后的满月 */
    moon: HTMLElement;

    /** 盖在示意图服务器上的亮灯机架，其中一层的机身上落着幽灵的影子 */
    lamps: SVGSVGElement | undefined;

    /** 扒着窗口边的小手 */
    paw: SVGSVGElement | undefined;
}

/** 逐帧摆放的状态。 */
interface Motion {
    /** 跟着滚动、缓缓追上的距离 */
    smooth: number;

    /** 上一帧的时间，毫秒 */
    time: number;

    /** 上一帧幽灵在屏幕上的 x，用来算横向速度 */
    x: number;

    /** 平滑过的横向速度，px / s */
    velocity: number;

    /** 飘动的相位，秒 */
    phase: number;

    /** 正在显示的姿势 */
    pose: TrailPoseName | undefined;

    /** 换上的姿势一个比一个叠得高 */
    layer: number;

    /** 眼睛亮着到这个时间为止，毫秒 */
    flash: number;
}

/** 量布局、排路线并逐帧摆放；返回拆掉一切的函数。 */
function animate(root: HTMLElement, art: TrailArt): () => void {
    const scene = build(root, art);
    const metrics = metricsOf(art, scene.paw);
    const motion: Motion = {
        smooth: scrollY,
        time: 0,
        x: 0,
        velocity: 0,
        phase: 0,
        pose: undefined,
        layer: 0,
        flash: 0,
    };
    let plan: TrailPlan | undefined;
    let layout: TrailLayout | undefined;
    let frame = 0;

    // 量出布局、排好路线；滚动距离与幽灵之间的差距保持不变，布局变了幽灵也不跳
    const relayout = (): void => {
        const gap = scrollY - motion.smooth;

        layout = measure();
        plan = layout ? planTrail(layout, metrics) : undefined;
        motion.smooth = scrollY - gap;
        cancelAnimationFrame(frame);

        // 首页缺了哪一块时退回静止的样子
        if (!layout || !plan) {
            root.style.height = '0';
            delete document.documentElement.dataset.trail;

            return;
        }

        root.style.height = `${layout.end + layout.height}px`;
        place(scene, art, layout);

        // 先摆好这一帧，再让页面上的画让出幽灵：两者在同一帧里交接，看不出换过
        motion.time = 0;
        tick(performance.now());
        document.documentElement.dataset.trail = '';
    };

    const tick = (now: number): void => {
        frame = 0;

        if (!plan || !layout) {
            return;
        }

        const seconds = motion.time ? Math.min((now - motion.time) / 1000, 0.05) : 0;
        const settled = step(root, scene, art, plan, layout, motion, now, seconds);

        motion.time = now;

        if (!settled) {
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

    const observer = new ResizeObserver(relayout);

    observer.observe(document.body);
    addEventListener('scroll', wake, { passive: true });
    document.addEventListener('visibilitychange', pause);
    demoEvents.forEach((name) => document.addEventListener(name, flash));
    void document.fonts.ready.then(relayout);

    return () => {
        observer.disconnect();
        cancelAnimationFrame(frame);
        removeEventListener('scroll', wake);
        document.removeEventListener('visibilitychange', pause);
        demoEvents.forEach((name) => document.removeEventListener(name, flash));
        scene.lamps?.remove();
        root.replaceChildren();
        root.style.removeProperty('height');
        root.removeAttribute('data-still');

        for (const name of ['trail', 'trailRest', 'trailHome', 'trailLamps', 'trailServer', 'trailReveal']) {
            delete document.documentElement.dataset[name];
        }
    };
}

/**
 * 摆好一帧：滚动距离缓缓追上，按路线取出幽灵的样子，加上顺着方向的倾斜与上下飘动。
 *
 * 返回是否已经停稳：停稳后不再请求下一帧，直到再次滚动。
 */
function step(
    root: HTMLElement,
    scene: Scene,
    art: TrailArt,
    plan: TrailPlan,
    layout: TrailLayout,
    motion: Motion,
    now: number,
    seconds: number,
): boolean {
    const target = scrollY;

    motion.smooth = approach(motion.smooth, target, seconds, lag);

    if (Math.abs(motion.smooth - target) < 0.05) {
        motion.smooth = target;
    }

    const s = motion.smooth;
    const sample = sampleTrail(plan, s);
    const velocity = seconds > 0 ? (sample.x - motion.x) / seconds : 0;

    motion.velocity = approach(motion.velocity, velocity, seconds, 0.12);
    motion.x = sample.x;
    motion.phase += seconds;

    const flashing = now < motion.flash;
    const lit = flashing && sample.pose === 'hide';
    const pose = lit ? 'hideLit' : sample.pose;

    // 跳起的高度占满幅的比例：从做完那一刻起，先升后落
    const hop = flashing && !lit
        ? Math.sin(Math.PI * Math.min((now - motion.flash + flashTime) / hopTime, 1))
        : 0;

    showPose(scene, motion, pose);
    toggles(root, plan, s);
    position(scene, art, sample, {
        lean: leanOf(motion.velocity),
        phase: motion.phase,
        hop,
    });
    scenery(scene, art, plan, layout, s, pose);

    return (
        motion.smooth === target &&
        Math.abs(motion.velocity) < 0.5 &&
        sample.bob === 0 &&
        !flashing
    );
}

/**
 * 摆放三档里的幽灵与小手：位置、倾斜加翻转、大小；投影另外补上转动带来的偏移。
 *
 * `lean` 是顺着横向速度的倾斜角，`phase` 是飘动的相位（秒），`hop` 是轻轻一跳升到的比例。
 */
function position(
    scene: Scene,
    art: TrailArt,
    sample: TrailSample,
    { lean, phase, hop }: { lean: number; phase: number; hop: number },
): void {
    const [width, height] = art.size;
    const scale = sample.u / art.unit;
    const angle = sample.roll + lean;

    // 宽屏上的幽灵按原幅度飘动与跳起，小的按比例减小
    const fit = Math.min(scale / 0.79, 1);
    const bob = sample.bob * Math.sin((phase * 2 * Math.PI) / bobPeriod) * bobHeight;
    const lift = (bob - hop * hopHeight) * fit;
    const left = sample.x - width / 2;
    const top = sample.y - height / 2 + lift;
    const tail = `rotate(${angle.toFixed(2)}deg) scale(${scale.toFixed(4)})`;
    const transform = `translate3d(${left.toFixed(2)}px, ${top.toFixed(2)}px, 0) ${tail}`;

    // 投影画在身体右下方：身体转过 angle 后，把投影挪回原来的方向
    const pose = art.poses[sample.pose];
    const grid = (width / pose.viewBox[2]) * scale;
    const radians = (angle * Math.PI) / 180;
    const [dx, dy] = [castOffset[0] * grid, castOffset[1] * grid];
    const shiftX = dx - (dx * Math.cos(radians) - dy * Math.sin(radians));
    const shiftY = dy - (dx * Math.sin(radians) + dy * Math.cos(radians));

    scene.ghosts.edge.style.transform = transform;
    scene.ghosts.paint.style.transform = transform;
    scene.ghosts.paw.style.transform = transform;
    scene.ghosts.shadow.style.transform = [
        `translate3d(${(left + shiftX).toFixed(2)}px, ${(top + shiftY).toFixed(2)}px, 0)`,
        tail,
    ].join(' ');
}

/** 换姿势：新姿势的各档淡入并叠在上面，旧的由样式表稍后淡出。 */
function showPose(scene: Scene, motion: Motion, pose: TrailPoseName): void {
    if (motion.pose === pose) {
        return;
    }

    for (const svg of scene.poses.get(motion.pose ?? pose) ?? []) {
        svg.classList.remove('on');
    }

    motion.layer += 1;

    for (const svg of scene.poses.get(pose) ?? []) {
        svg.style.zIndex = String(motion.layer);
        svg.classList.add('on');
    }

    // 小手只在扒着窗口边时出现
    scene.ghosts.paw.firstElementChild?.classList.toggle('on', pose === 'hide' || pose === 'hideLit');
    motion.pose = pose;
}

/**
 * 跟着滚动距离切换的几处：图标与满怀自己显示幽灵的时候，示意图里服务器的指示灯与落在机架上的影子，
 * 以及显形那台服务器的指示灯与光束。
 */
function toggles(root: HTMLElement, plan: TrailPlan, s: number): void {
    const page = document.documentElement;
    const rest = s < plan.rest;
    const home = s >= plan.home;
    const [docked, away] = plan.server;
    const [from, to] = plan.reveal ?? [Number.POSITIVE_INFINITY, 0];

    flag(page, 'trailRest', rest);
    flag(page, 'trailHome', home);
    flag(page, 'trailLamps', s >= docked);
    flag(page, 'trailServer', s >= docked && s <= away);
    flag(page, 'trailReveal', s >= from && s <= to);

    if (root.hasAttribute('data-still') !== (rest || home)) {
        root.toggleAttribute('data-still', rest || home);
    }
}

/** 樱桃枝滑进来、樱桃被摘下，满月淡入，举手探身的投影从底板的颜色换成页面的颜色。 */
function scenery(
    scene: Scene,
    art: TrailArt,
    plan: TrailPlan,
    layout: TrailLayout,
    s: number,
    pose: TrailPoseName,
): void {
    const { branch } = plan;
    const left = branch.x + art.branch.offset[0] * branch.scale;
    const top = branch.y + art.branch.offset[1] * branch.scale;
    const reach = progress(s, branch.from, branch.to);
    const slide = (1 - easeOut(reach)) * (layout.width - left + 8);

    for (const element of scene.branches) {
        element.style.transform = [
            `translate3d(${(left + slide).toFixed(2)}px, ${top.toFixed(2)}px, 0)`,
            `scale(${branch.scale.toFixed(4)})`,
        ].join(' ');
        element.classList.toggle('picked', s >= branch.pick);
    }

    scene.moon.style.opacity = progress(s, plan.moon[0], plan.moon[1]).toFixed(3);

    if (scene.casts && pose === 'rise') {
        const page = progress(s, plan.plate[0], plan.plate[1]);

        scene.casts.page.style.opacity = page.toFixed(3);
        scene.casts.plate.style.opacity = (1 - page).toFixed(3);
    }
}

/** 樱桃枝的尺寸与满月的位置只随布局变：排好路线后摆一次。 */
function place(scene: Scene, art: TrailArt, layout: TrailLayout): void {
    const [, , viewWidth, viewHeight] = art.moon.viewBox;
    const armful = layout.armful;
    const width = armful.right - armful.left;
    const centreX = armful.left + art.moon.centre[0] * width;
    const centreY = armful.top + art.moon.centre[1] * (armful.bottom - armful.top);
    const height = (art.moon.width * viewHeight) / viewWidth;

    Object.assign(scene.moon.style, {
        width: `${art.moon.width}px`,
        height: `${height}px`,
        transform: [
            `translate(${(centreX - art.moon.width / 2).toFixed(2)}px,`,
            `${(centreY - height / 2).toFixed(2)}px)`,
        ].join(' '),
    });

    for (const element of scene.branches) {
        element.style.width = `${art.branch.width}px`;
        element.style.height = `${(art.branch.width * art.branch.viewBox[3]) / art.branch.viewBox[2]}px`;
    }
}

/** 在容器里搭好各档：满月、投影、贴纸边、成品与叠在窗口上的小手。 */
function build(root: HTMLElement, art: TrailArt): Scene {
    const tier = (name: string): HTMLElement => element('div', 'trail-tier', root, name);
    const moonTier = tier('moon');
    const tiers = { shadow: tier('shadow'), edge: tier('edge'), paint: tier('paint') };
    const front = tier('front');
    const ghost = (parent: HTMLElement): HTMLElement => sized(element('div', 'trail-ghost', parent), art.size);
    const ghosts = {
        shadow: ghost(tiers.shadow),
        edge: ghost(tiers.edge),
        paint: ghost(tiers.paint),
        paw: ghost(front),
    };
    const poses = new Map<TrailPoseName, SVGSVGElement[]>();

    // 每个姿势按档拆开，放进对应那一档里的幽灵
    for (const [name, part] of Object.entries(art.poses) as [TrailPoseName, TrailPart][]) {
        const svgs = (['shadow', 'edge', 'paint'] as const).flatMap((each) => {
            const svg = svgOf(part, [each]);

            if (svg) {
                ghosts[each].append(svg);
            }

            return svg ? [svg] : [];
        });

        poses.set(name, svgs);
    }

    const paw = svgOf(art.paw, ['shadow', 'edge', 'paint']);

    if (paw) {
        paw.classList.add('trail-paw');
        ghosts.paw.append(paw);
    }

    const branches = [
        branchOf(art.branch, ['shadow'], tiers.shadow),
        branchOf(art.branch, ['edge', 'paint'], tiers.edge),
    ];
    const moon = element('div', 'trail-moon', moonTier);

    moon.append(
        svgOf(art.moon, ['shadow', 'edge', 'paint']) ??
            document.createElementNS(svgNamespace, 'svg'),
    );
    moon.style.opacity = '0';

    return {
        ghosts,
        poses,
        casts: plateCast(art, poses.get('rise')?.[0]),
        branches,
        moon,
        lamps: lampsOf(art),
        paw,
    };
}

/**
 * 举手探身的投影另画一份底板上的颜色：浅色主题里页面上的投影是紫色，图标底板上的投影仍是图标自己的颜色。
 *
 * 返回两份投影各自所在的组，由滚动距离调它们的不透明度。
 */
function plateCast(art: TrailArt, shadow: SVGSVGElement | undefined): Scene['casts'] {
    if (!shadow) {
        return undefined;
    }

    const page = document.createElementNS(svgNamespace, 'g');
    const plate = document.createElementNS(svgNamespace, 'g');

    page.append(...shadow.childNodes);

    // 第二份的 id 换一个前缀，不与第一份重复
    plate.innerHTML = page.innerHTML.replaceAll('trail-rise-', 'trail-rise-plate-');
    plate.style.color = art.plateCast;
    page.style.opacity = '0';
    shadow.append(page, plate);

    return { plate, page };
}

/** 樱桃枝的一部分：几档的层画进一个 SVG，樱桃单独成组，摘下时淡去。 */
function branchOf(part: TrailPart, tiers: readonly TrailTier[], parent: HTMLElement): HTMLElement {
    const holder = element('div', 'trail-branch', parent);
    const svg = document.createElementNS(svgNamespace, 'svg');

    svg.setAttribute('viewBox', part.viewBox.join(' '));
    svg.innerHTML = tiers
        .flatMap((tier) => part.layers.filter((layer) => layer.tier === tier))
        .map(({ group, markup }) => (group === 'cherries' ? `<g data-cherries="">${markup}</g>` : markup))
        .join('');
    holder.append(svg);

    return holder;
}

/** 亮灯的机架盖在示意图的服务器上，由样式表在幽灵来过之后淡入；落着影子的一层只在幽灵停在机架身前时显示。 */
function lampsOf(art: TrailArt): SVGSVGElement | undefined {
    const server = document.querySelector('[data-art="server"]');
    const svg = svgOf(art.lamps, ['shadow', 'edge', 'paint']);

    if (!server || !svg) {
        return undefined;
    }

    svg.dataset.layer = 'lamps';
    server.append(svg);

    return svg;
}

/** 量出排路线要用的页面布局；首页缺了哪一块时返回空，页面保持静止。 */
function measure(): TrailLayout | undefined {
    const one = (selector: string): Box | undefined => {
        const found = document.querySelector(selector);

        return found ? boxOf(found) : undefined;
    };
    const hero = one('.hero .app-icon');
    const window = one('.sd-window');
    const server = one('[data-art="server"]');
    const reveal = one('[data-art="reveal"]');
    const armful = one('.closing [data-art]');
    const title = one('.closing h2');
    const heading = union(
        ['.hero .name', '.hero h1', '.hero .tagline'].flatMap((selector) => one(selector) ?? []),
    );
    const column = union([...document.querySelectorAll('.diagram, .point, .feature')].map(boxOf));

    if (!hero || !window || !server || !reveal || !armful || !title || !heading || !column) {
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
        window,

        // 那一行一直伸到窗口右边时，小手扒在它的右端
        ...(grip && grip.right >= window.right - 2 ? { grip: (grip.top + grip.bottom) / 2 } : {}),
        server,
        reveal,
        armful,
        title,
        blocks: [...document.querySelectorAll(blockSelector)].map(boxOf),
    };
}

/** 由 JSON 里的画取出排路线要用的尺寸；小手的位置由搭好的画量出。 */
function metricsOf(art: TrailArt, paw: SVGSVGElement | undefined): TrailMetrics {
    return {
        unit: art.unit,
        anchors: art.anchors,
        hideEdge: art.size[0] / 2 - art.paw.edge,
        pawDrop: pawDrop(art, paw),
        branchReach: art.branch.offset[0] + art.branch.width,
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

/** 一幅画里属于这几档的层，画进一个 SVG；一层都没有时返回空。 */
function svgOf(part: TrailPart, tiers: readonly TrailTier[]): SVGSVGElement | undefined {
    const layers = tiers.flatMap((tier) => part.layers.filter((layer) => layer.tier === tier));

    if (layers.length === 0) {
        return undefined;
    }

    const svg = document.createElementNS(svgNamespace, 'svg');

    svg.setAttribute('viewBox', part.viewBox.join(' '));
    svg.innerHTML = layers.map(({ name, markup }) => `<g data-layer="${name}">${markup}</g>`).join('');

    return svg;
}

/** 新建一个带样式类的元素放进容器；给了档名时记在 `data-tier` 上。 */
function element(tag: 'div', className: string, parent: HTMLElement, tier?: string): HTMLElement {
    const created = document.createElement(tag);

    created.className = className;

    if (tier) {
        created.dataset.tier = tier;
    }

    parent.append(created);

    return created;
}

/** 按画面原大的宽高定好元素的尺寸。 */
function sized(target: HTMLElement, [width, height]: readonly [number, number]): HTMLElement {
    target.style.width = `${width}px`;
    target.style.height = `${height}px`;

    return target;
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

/** 先快后慢的缓动。 */
function easeOut(t: number): number {
    return 1 - (1 - t) ** 3;
}
