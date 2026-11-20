import type { TrailArt, TrailPart, TrailPose, TrailPoseName, TrailTier } from '../art/trail.ts';
import type { Box, TrailLayout } from './path.ts';

/*
 * 首页小幽灵的画面：在容器里搭好各档的元素，由 `tracks.ts` 按滚动的距离摆放。
 *
 * 跟着滚动变化的东西各占一个元素，只改它的 `transform` 或 `opacity`：浏览器能按滚动的距离直接合成出来，不经页面的脚本。
 */

/** 一档里的幽灵：外层按滚动摆放位置、大小与翻转，里层另加倾斜、飘动与轻轻一跳。 */
export interface Ghost {
    /** 外层 */
    outer: HTMLElement;

    /** 里层，姿势的画、眼睛与小手都在这里 */
    inner: HTMLElement;
}

/** 一张姿势的画：三档里各一个元素，以及眼睛望向各处时的位置。 */
export interface PoseImage {
    /** 投影、贴纸边与成品三档；举手探身的投影另分成两份，见 `Scene.casts` */
    tiers: Partial<Record<TrailTier, SVGSVGElement>>;

    /** 眼睛望向各处时的位置 */
    eyes: TrailPose['eyes'];
}

/** 一只眼睛。 */
export interface EyeParts {
    /** 外层，按滚动摆放位置、转角与大小 */
    holder: HTMLElement;

    /** 平时的竖椭圆 */
    oval: SVGSVGElement;

    /** 亮着时的四角星 */
    sparkle: SVGSVGElement;
}

/** 搭好的画面里，跟着滚动变化的元素。 */
export interface Scene {
    /** 投影、贴纸边、成品三档里的幽灵，以及叠在窗口上面那一档里的小手；外层的摆放相同 */
    ghosts: Record<'shadow' | 'edge' | 'paint' | 'paw', Ghost>;

    /** 各张姿势的画，键见 `imageKey` */
    images: Map<string, PoseImage>;

    /** 举手探身的投影：落在页面上的一份与落在图标底板上的一份 */
    casts: { page: SVGSVGElement; plate: SVGSVGElement } | undefined;

    /** 两只眼睛，从左到右 */
    eyes: EyeParts[];

    /** 两只眼睛外面那一层：落进满怀时一起淡去，演示窗口里做完一步时亮一下 */
    eyeLayer: HTMLElement;

    /** 扒着窗口边的小手：落在窗口上的影子一份，成品一份 */
    paw: { shadow: SVGSVGElement; paint: SVGSVGElement } | undefined;

    /** 投影一档与贴纸边、成品一档里的樱桃枝 */
    branches: HTMLElement[];

    /** 枝上的樱桃，摘下时淡去 */
    cherries: SVGSVGElement[];

    /** 满怀背后的满月 */
    moon: HTMLElement;

    /** 演示窗口落在页面上的投影，垫在幽灵下面 */
    windowCast: HTMLElement;

    /** 盖在示意图服务器上的亮灯机架，机身上落着幽灵的影子 */
    lamps: SVGSVGElement | undefined;

    /** 显形那台服务器的光束与亮着指示灯的机身 */
    beams: SVGSVGElement[];
}

/** SVG 的命名空间。 */
const svgNamespace = 'http://www.w3.org/2000/svg';

/** 一张姿势的画在 `Scene.images` 里的键：姿势是它的名字，两个姿势之间的过渡画是 “换出去>换进来#序号”。 */
export function imageKey(pose: string, index?: number): string {
    return index === undefined ? pose : `${pose}#${index}`;
}

/**
 * 在容器里搭好各档：垫在最下面的满月与演示窗口的投影，幽灵的投影、贴纸边、成品，以及叠在窗口上面的小手。
 *
 * 各张姿势的画按固定的次序叠放，换姿势时只调不透明度；成品那一档最上面是两只眼睛。
 */
export function build(root: HTMLElement, art: TrailArt): Scene {
    const tier = (name: string): HTMLElement => element('div', 'trail-tier', root, name);
    const back = tier('back');
    const tiers = { shadow: tier('shadow'), edge: tier('edge'), paint: tier('paint') };
    const front = tier('front');
    const ghost = (parent: HTMLElement): Ghost => {
        const outer = sized(element('div', 'trail-ghost', parent), art.size);

        return { outer, inner: element('div', 'trail-body', outer) };
    };
    const ghosts = {
        shadow: ghost(tiers.shadow),
        edge: ghost(tiers.edge),
        paint: ghost(tiers.paint),
        paw: ghost(front),
    };
    const images = new Map<string, PoseImage>();

    // 每张画按档拆开，放进对应那一档里的幽灵
    const add = (key: string, pose: TrailPose): void => {
        const parts: PoseImage['tiers'] = {};

        for (const each of ['shadow', 'edge', 'paint'] as const) {
            const svg = svgOf(pose, [each]);

            if (svg) {
                svg.classList.add('trail-pose');
                ghosts[each].inner.append(svg);
                parts[each] = svg;
            }
        }

        images.set(key, { tiers: parts, eyes: pose.eyes });
    };

    for (const [name, pose] of Object.entries(art.poses) as [TrailPoseName, TrailPose][]) {
        add(imageKey(name), pose);
    }

    for (const [name, poses] of Object.entries(art.morphs)) {
        poses?.forEach((pose, index) => add(imageKey(name, index), pose));
    }

    const eyeLayer = element('div', 'trail-eyes', ghosts.paint.inner);
    const branches = [
        branchOf(art.branch, ['shadow'], tiers.shadow),
        branchOf(art.branch, ['edge', 'paint'], tiers.edge),
    ];
    const moon = element('div', 'trail-moon', back);

    moon.append(
        svgOf(art.moon, ['shadow', 'edge', 'paint']) ??
            document.createElementNS(svgNamespace, 'svg'),
    );

    return {
        ghosts,
        images,
        casts: plateCast(art, images.get(imageKey('rise'))?.tiers.shadow),
        eyes: [eyeOf(art, eyeLayer, 0), eyeOf(art, eyeLayer, 1)],
        eyeLayer,
        paw: pawOf(art, ghosts.paw.inner),
        branches: branches.map(({ holder }) => holder),
        cherries: branches.flatMap(({ cherries }) => cherries),
        moon,
        windowCast: element('div', 'trail-window-cast', back),
        lamps: lampsOf(art),
        beams: [...document.querySelectorAll<SVGSVGElement>(
            '[data-art="reveal"] > :is([data-layer="beam"], [data-layer="lamps"])',
        )],
    };
}

/** 樱桃枝的尺寸、满月的位置与演示窗口投影的范围只随布局变：排好路线后摆一次。 */
export function place(scene: Scene, art: TrailArt, layout: TrailLayout): void {
    placeWindowCast(scene.windowCast, layout.window);

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

    for (const holder of scene.branches) {
        holder.style.width = `${art.branch.width}px`;
        holder.style.height = `${(art.branch.width * art.branch.viewBox[3]) / art.branch.viewBox[2]}px`;
    }
}

/** 一幅画里属于这几档的层，画进一个 SVG；一层都没有时返回空。 */
export function svgOf(part: TrailPart, tiers: readonly TrailTier[]): SVGSVGElement | undefined {
    const layers = tiers.flatMap((tier) => part.layers.filter((layer) => layer.tier === tier));

    if (layers.length === 0) {
        return undefined;
    }

    const svg = document.createElementNS(svgNamespace, 'svg');

    svg.setAttribute('viewBox', part.viewBox.join(' '));
    svg.innerHTML = layers.map(({ name, markup }) => `<g data-layer="${name}">${markup}</g>`).join('');

    return svg;
}

/**
 * 一只眼睛：竖椭圆与四角星叠在一起，另有一份四角星在演示窗口里做完一步时亮一下。
 *
 * 竖椭圆外面另包一层，亮一下时由样式表把它淡去；按滚动摆放的不透明度写在里面的 SVG 上，两者互不干扰。
 */
function eyeOf(art: TrailArt, parent: HTMLElement, index: number): EyeParts {
    const { oval, sparkles, radius } = art.eye;
    const holder = element('div', 'trail-eye', parent);
    const ovalHolder = element('div', 'trail-eye-oval', holder);
    const shape = (markup: string, into: HTMLElement): SVGSVGElement => {
        const svg = document.createElementNS(svgNamespace, 'svg');

        svg.setAttribute('viewBox', `${-radius} ${-radius} ${2 * radius} ${2 * radius}`);
        Object.assign(svg.style, {
            left: `${-radius}px`,
            top: `${-radius}px`,
            width: `${2 * radius}px`,
            height: `${2 * radius}px`,
        });
        svg.innerHTML = markup;
        into.append(svg);

        return svg;
    };

    const parts = {
        holder,
        oval: shape(oval, ovalHolder),
        sparkle: shape(sparkles[index] ?? '', holder),
    };

    shape(sparkles[index + 2] ?? '', holder).classList.add('trail-eye-flash');

    return parts;
}

/**
 * 扒着窗口边的小手：落在窗口上的影子与成品各在一个外层里，一起左右滑动、淡入淡出。
 *
 * 影子到窗口的边为止；成品不裁，它的根部自己淡入身体，小手像是从身体里伸出来。
 */
function pawOf(art: TrailArt, parent: HTMLElement): Scene['paw'] {
    const shadow = svgOf(art.paw, ['shadow']);
    const paint = svgOf(art.paw, ['paint']);

    if (!shadow || !paint) {
        return undefined;
    }

    const edge = art.paw.edge.toFixed(2);
    const outer = element('div', 'trail-paw', parent);

    // 裁剪框上下左右都伸到画面以外，只有右边停在窗口的边上
    outer.style.clipPath = `polygon(-100% -100%, ${edge}px -100%, ${edge}px 200%, -100% 200%)`;
    outer.append(shadow);

    element('div', 'trail-paw', parent).append(paint);

    return { shadow, paint };
}

/**
 * 举手探身的投影另画一份底板上的颜色：浅色主题里页面上的投影是紫色，图标底板上的投影仍是图标自己的颜色。
 *
 * 返回两份投影，由滚动距离调它们的不透明度。
 */
function plateCast(art: TrailArt, page: SVGSVGElement | undefined): Scene['casts'] {
    if (!page) {
        return undefined;
    }

    const plate = page.cloneNode(false) as SVGSVGElement;

    // 第二份的 id 换一个前缀，不与第一份重复
    plate.innerHTML = page.innerHTML.replaceAll('trail-rise-', 'trail-rise-plate-');
    plate.style.color = art.plateCast;
    page.after(plate);

    return { page, plate };
}

/** 樱桃枝的一部分：几档的层各画进一个 SVG，樱桃的层另记下来，摘下时淡去。 */
function branchOf(
    part: TrailPart,
    tiers: readonly TrailTier[],
    parent: HTMLElement,
): { holder: HTMLElement; cherries: SVGSVGElement[] } {
    const holder = element('div', 'trail-branch', parent);
    const cherries: SVGSVGElement[] = [];

    for (const layer of tiers.flatMap((tier) => part.layers.filter((each) => each.tier === tier))) {
        const svg = document.createElementNS(svgNamespace, 'svg');

        svg.setAttribute('viewBox', part.viewBox.join(' '));
        svg.innerHTML = layer.markup;
        holder.append(svg);

        if (layer.group === 'cherries') {
            cherries.push(svg);
        }
    }

    return { holder, cherries };
}

/** 亮灯的机架盖在示意图的服务器上，连同机身上落着的影子。 */
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

/**
 * 演示窗口落在页面上的投影摆到窗口所在的地方：尺寸与圆角照窗口排版时的样子，窗口整窗缩小时跟着缩到同样的比例。
 *
 * `box` 是量到的窗口范围，文档坐标。
 */
function placeWindowCast(cast: HTMLElement, box: Box): void {
    const frame = document.querySelector<HTMLElement>('.sd-window');

    if (!frame) {
        return;
    }

    const style = getComputedStyle(frame);

    // 量到的范围是缩小之后的：除以窗口缩小的比例，就是它排版时的尺寸
    const zoom = new DOMMatrixReadOnly(style.transform).a;

    Object.assign(cast.style, {
        width: `${((box.right - box.left) / zoom).toFixed(3)}px`,
        height: `${((box.bottom - box.top) / zoom).toFixed(3)}px`,
        borderRadius: style.borderRadius,
        transform: `translate(${box.left.toFixed(3)}px, ${box.top.toFixed(3)}px) scale(${zoom.toFixed(5)})`,
    });
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
