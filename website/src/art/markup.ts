/*
 * 把绘制脚本拼出的 SVG 片段收进页面：分层的画、整页唯一的 id、收短的数字。
 */

/** 一幅画里的一层。 */
export interface ArtLayer {
    /** 层名，写进 `data-layer`，动画按它找到这一层 */
    name: string;

    /** 一起移动的几层共用的组名，写进 `data-group`；不随别的层移动时省略 */
    group?: string;

    /** 这一层的 SVG 片段，坐标系是整幅画的 `viewBox` */
    markup: string;
}

/** 一幅分层的画：几层叠在同一个 `viewBox` 里，从后往前。 */
export interface Art {
    /** 画面的范围：左、上、宽、高 */
    viewBox: readonly [number, number, number, number];

    /** 页面上的显示宽度，CSS 像素；修圆滤镜收出的边按它放宽 */
    width: number;

    /** 各层，从后往前 */
    layers: readonly ArtLayer[];

    /** 投影原本的颜色；有它时画面里的投影写成 `currentColor`，由页面按主题换色 */
    cast?: string;
}

/** 值不是数字的属性：颜色、id 与引用。 */
const textAttributes = new Set([
    'id',
    'fill',
    'stroke',
    'stop-color',
    'flood-color',
    'color',
    'href',
    'filter',
    'mask',
    'clip-path',
    'type',
    'stroke-linejoin',
    'stroke-linecap',
    'filterUnits',
    'maskUnits',
    'gradientUnits',
    'color-interpolation-filters',
]);

/** 页面上修圆滤镜收出的边宽，CSS 像素：2 倍屏上约一个物理像素。 */
const edgePixels = 0.6;

/**
 * 收进页面之前的处理：每层的 id 加上前缀，保证整页唯一；数字收短到六位有效数字。
 *
 * `prefix` 在整页里要唯一，同一页上的两幅画不能用同一个。
 */
export function renderArt(art: Art, prefix: string): Art {
    return {
        ...art,
        layers: art.layers.map((layer, index) => ({
            ...layer,
            markup: compactNumbers(scopeIds(layer.markup, `${prefix}${index}-`)),
        })),
    };
}

/**
 * 把片段里的 id 依次换成 “前缀 + 序号”，引用跟着换。
 *
 * 同一个 id 定义了两次，或者引用了片段里没有定义的 id，都会报错：拆层时漏掉了定义，或者同一块贴纸放进了同一层两次。
 */
export function scopeIds(markup: string, prefix: string): string {
    const names = new Map<string, string>();

    for (const [, id = ''] of markup.matchAll(/(?<=\s)id="([^"]+)"/g)) {
        if (names.has(id)) {
            throw new Error(`同一层里有两个 id 都是 ${id}`);
        }

        names.set(id, `${prefix}${names.size.toString(36)}`);
    }

    const renamed = (id: string): string => {
        const name = names.get(id);

        if (name === undefined) {
            throw new Error(`引用的 id ${id} 不在这一层里`);
        }

        return name;
    };

    return markup
        .replace(/(?<=\s)id="([^"]+)"/g, (_, id: string) => `id="${renamed(id)}"`)
        .replace(/url\(#([^)]+)\)/g, (_, id: string) => `url(#${renamed(id)})`)
        .replace(/(?<=\s)href="#([^"]+)"/g, (_, id: string) => `href="#${renamed(id)}"`);
}

/**
 * 把属性值里带小数或指数的数字收短到六位有效数字，绝对值小于千分之一的写成 0。
 *
 * 只动数值属性：颜色、id 与引用原样保留。
 */
export function compactNumbers(markup: string): string {
    return markup.replace(/(?<=\s)([\w:-]+)="([^"]*)"/g, (attribute, name: string, value: string) => {
        if (textAttributes.has(name)) {
            return attribute;
        }

        const compacted = value.replace(/-?(?:\d+\.\d*|\.\d+|\d+(?=e))(?:e[-+]?\d+)?/gi, (number) => {
            const parsed = Number(number);

            return Math.abs(parsed) < 1e-3 ? '0' : String(Number(parsed.toPrecision(6)));
        });

        return `${name}="${compacted}"`;
    });
}

/**
 * 按显示宽度放宽一幅画里修圆滤镜收出的边。
 *
 * 绘制脚本先按 1024 px 画出图标、收出约一个单位宽的边，再缩小到导出尺寸；页面上按显示尺寸直接画，边窄于一个像素会出锯齿。
 * `filterScale` 是滤镜所在坐标相对 `viewBox` 的缩放，画面缩进底板时小于 1。
 */
export function sizeArt(art: Omit<Art, 'width'>, width: number, filterScale = 1): Art {
    const edge = (edgePixels * art.viewBox[2]) / width / filterScale;

    return {
        ...art,
        width,
        layers: art.layers.map((layer) => ({ ...layer, markup: softenEdges(layer.markup, edge) })),
    };
}

/**
 * 把修圆滤镜收出的边放宽到 `width`，单位是滤镜所在的坐标；0.5 处的轮廓不动，形状不变，只是边更柔。
 */
function softenEdges(markup: string, width: number): string {
    return markup.replace(/<feFuncA type="linear" slope="([^"]+)" intercept="[^"]+"\/>/g, (_, slope: string) => {
        const softened = Number(slope) / width;

        return `<feFuncA type="linear" slope="${softened}" intercept="${-(softened - 1) / 2}"/>`;
    });
}
