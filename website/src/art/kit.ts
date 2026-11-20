import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import vm from 'node:vm';

/*
 * 在 Node 里执行 App 应用图标的绘制脚本（仓库的 `scripts/make-icon/`），取出拼 SVG 片段的函数与常量。
 *
 * 绘制脚本是接在一起执行的普通脚本：拼 SVG 的函数都是纯函数，只有把画面画进 Canvas 的两步要用浏览器。
 * 这里垫一个空的 `Path2D`，把那两步换成记下画面，各组图标交给贴纸画法的配色、背景与贴纸就都能原样取出。
 */

/** 一份绘制脚本。 */
export interface IconScript {
    /** 文件名 */
    name: string;

    /** 源码 */
    source: string;
}

/** 画面里的一个点。 */
export type Point = readonly [number, number];

/** 图标组的名字，与绘制脚本里 `renderIcon` 的参数相同。 */
export type IconGroup = 'rise' | 'front' | 'hide' | 'reveal' | 'midnight' | 'perch' | 'cherryPick' | 'armful';

/** 默认图标或深色图标。 */
export type IconStyle = 'default' | 'dark';

/** 图标的配色，键见绘制脚本里的 `ARMFUL_PALETTES` 与各组的颜色表；这里只列出直接用到的几项。 */
export interface Palette {
    /** 贴纸落在底板上的影子 */
    cast: string;

    /** 贴纸边 */
    edge: string;

    /** 底板自上而下的渐变 */
    plate: readonly string[];

    /** 其余颜色，由绘制脚本里的贴纸取用 */
    readonly [key: string]: unknown;
}

/** 一块贴纸，见绘制脚本的 `sticker.js`。 */
export interface Sticker {
    /** 剪影与成品共用的滤镜定义 */
    defs: string;

    /** 染成一种颜色的剪影：往外描粗是贴纸边，模糊是投影 */
    outline: (fill: string) => string;

    /** 成品 */
    paint: (palette: Palette, lit: boolean) => string;

    /** 造出这块贴纸的函数名，如 `ghostSticker` */
    kind?: string;

    /** 造这块贴纸时传入的参数 */
    options?: unknown;
}

/** 造幽灵姿态的参数，见 `ghostPose`。 */
export interface GhostPoseOptions {
    /** 头顶在画面里的位置 */
    top: Point;

    /** 幽灵的大小，1 是自身坐标的原大 */
    scale: number;

    /** 脊线在头部与下摆处的倾角，度，正值是头往右歪 */
    lean: Point;
}

/** 幽灵的姿态：自身坐标与画面坐标之间的换算，见 `ghostPose`。 */
export interface GhostPose {
    /** 幽灵的大小 */
    scale: number;

    /** 自身坐标里的点在画面里的位置：u 是离脊线的距离，往右为正；v 是从头顶沿脊线往下的距离 */
    place: (u: number, v: number) => Point;

    /** v 处身体顺时针转过的度数 */
    degrees: (v: number) => number;

    /** 造这个姿态时传入的参数 */
    options?: GhostPoseOptions;
}

/** 幽灵的一只小手：渐细的笔画。 */
export interface GhostHand {
    /** 中线经过的点，画面坐标，从根部到手尖 */
    line: readonly Point[];

    /** 根部的粗细 */
    from: number;

    /** 手尖的粗细 */
    to: number;
}

/** 幽灵的一只眼睛，见 `ghostSticker`。 */
export interface GhostEye {
    /** 在幽灵自身坐标里离脊线的距离 */
    u: number;

    /** 在幽灵自身坐标里离头顶的距离 */
    v: number;

    /** 相对近处那只的大小，省略为 1 */
    size?: number;

    /** 相对身体顺时针转的度数，省略时取绘制脚本的默认值 */
    tilt?: number;
}

/** 造幽灵贴纸的参数，见 `ghostSticker`。 */
export interface GhostOptions {
    /** 姿态 */
    pose: GhostPose;

    /** 从身上顶出来的小手 */
    hands?: readonly GhostHand[];

    /** 眼睛 */
    eyes: readonly GhostEye[];
}

/** 别的东西落在服务器机身上的影子，见 `serverSticker`。 */
export interface ServerShadow {
    /** 染成一种颜色的剪影 */
    shape: (fill: string) => string;

    /** 往右挪开的量 */
    dx: number;

    /** 往下挪开的量 */
    dy: number;

    /** 不透明度 */
    opacity: number;
}

/** 造服务器贴纸的参数，见 `serverSticker`。 */
export interface ServerOptions {
    /** 左边的 x */
    x: number;

    /** 上边的 y */
    y: number;

    /** 宽度 */
    width: number;

    /** 高度 */
    height: number;

    /** 盘位槽：左边的 x 与宽高，竖直居中 */
    slot?: { x: number; width: number; height: number };

    /** 两盏指示灯圆心的 x，竖直居中 */
    leds: readonly number[];

    /** 指示灯的半径 */
    ledRadius: number;

    /** 别的东西落在机身上的影子 */
    shadows?: readonly ServerShadow[];
}

/** 一颗樱桃的圆心与半径，见 `cherrySticker`。 */
export interface CherryOptions {
    /** 圆心的 x */
    x: number;

    /** 圆心的 y */
    y: number;

    /** 半径 */
    radius: number;
}

/** 樱桃梗的几条渐细笔画与分叉处的结，见 `stemSticker`。 */
export interface StemOptions {
    /** 各条梗的中线 */
    lines: readonly (readonly Point[])[];

    /** 分叉处的结 */
    knot: CherryOptions;
}

/** 满月旁的一颗四角星，见 `moonMarkup`。 */
export interface MoonStar {
    /** 中心的 x */
    x: number;

    /** 中心的 y */
    y: number;

    /** 从中心到角尖的长度 */
    size: number;

    /** 颜色 */
    color: string;
}

/** 幽灵近处那只眼睛：竖椭圆的两个半轴，以及眼睛没有写 `tilt` 时相对身体顺时针转的度数，`STICKER_GHOST_EYE`。 */
export interface EyeShape {
    /** 横半轴 */
    radiusX: number;

    /** 竖半轴 */
    radiusY: number;

    /** 相对身体顺时针转的度数 */
    tilt: number;
}

/** 眼睛亮成的四角星，见 `sparkleData`。 */
export interface SparkleKit {
    /** 左右两个角尖到中心的距离与眼睛横半轴之比，`ARMFUL_SPARKLES.reachX` */
    reachX: number;

    /** 上下两个角尖到中心的距离与眼睛竖半轴之比，`ARMFUL_SPARKLES.reachY` */
    reachY: number;

    /** 修圆角尖的描边宽度，按幽灵的大小缩放，`ARMFUL_SPARKLES.rounding` */
    rounding: number;

    /** 自上而下由浅琥珀到深橙的渐变色，`ARMFUL_LIT.eye` */
    colors: readonly string[];

    /** 四周一圈光的颜色，`ARMFUL_LIT.eyeGlow` */
    glow: string;

    /** 中心在 (x, y)、角尖到中心的距离为 `reachX` 与 `reachY` 的四角星路径数据，`sparkleData` */
    data: (x: number, y: number, reachX: number, reachY: number) => string;
}

/** 满怀的两只眼睛，`ARMFUL_EYES`：竖椭圆的中心与两个半轴都在满怀这一团放到画面上之前的坐标里。 */
export interface ArmfulEyes {
    /** 各自绕中心顺时针转的度数 */
    tilt: number;

    /** 近处的一只与远处的一只 */
    ovals: readonly { x: number; y: number; radiusX: number; radiusY: number }[];
}

/** 满怀这一团放到画面上的姿态：绕 `pivot` 顺时针转 `degrees` 度、缩到 `scale` 倍，再平移 `shift`。 */
export interface ArmfulPose {
    /** 旋转与缩放的中心 */
    pivot: Point;

    /** 顺时针转的度数 */
    degrees: number;

    /** 缩放倍数 */
    scale: number;

    /** 最后的平移 */
    shift: Point;
}

/** 绘制脚本里拼 SVG 片段的几个工具，见 `sticker.js`。 */
export interface SvgTools {
    /** 蒙版与滤镜的作用范围，`SVG_WIDE` */
    wide: string;

    /** 线性渐变，`svgLinear` */
    linear: (id: string, line: readonly number[], stops: readonly unknown[]) => string;

    /** 只在形体内部显示的内容，`svgMasked` */
    masked: (id: string, shape: string, content: string) => string;

    /** 模糊成一片柔光或影子，`svgBlurred` */
    blurred: (id: string, content: string, options: BlurOptions) => string;

    /** 形体内侧沿着轮廓的一道柔边，`svgInnerBand` */
    innerBand: (id: string, hole: string, options: BlurOptions & { color: string }) => string;
}

/** 模糊成一片柔光或影子的参数，见 `svgBlurred`。 */
export interface BlurOptions {
    /** 模糊之前往右挪开的量 */
    dx?: number;

    /** 模糊之前往下挪开的量 */
    dy?: number;

    /** 模糊的标准差 */
    blur: number;

    /** 模糊之后透明度放大的倍数 */
    gain?: number;

    /** 整片的不透明度 */
    opacity: number;
}

/** 一组图标交给贴纸画法的内容。 */
export interface IconCapture {
    /** 这一组这一版的配色 */
    palette: Palette;

    /** 指示灯是否亮着、眼睛是否亮成四角星 */
    lit: boolean;

    /** 填进底板的画面里，贴纸这一团身后的部分：炭黑的底色与背景，满幅坐标 */
    background: string;

    /** 共用一圈贴纸边的各块贴纸，从后往前；满怀的贴纸不是一块块拼的，这里为空 */
    stickers: readonly Sticker[];

    /** 贴纸这一团画出来的样子，满幅坐标 */
    cluster: string;

    /** 背景里从服务器往上投出的那束光，满幅坐标；只有显形有，别的组为空 */
    beam: string;
}

/** 底板下方的投影，Canvas 的投影参数，1024 网格。 */
export interface PlateShadow {
    /** 往下挪开的量 */
    offsetY: number;

    /** Canvas 的 `shadowBlur`，是高斯模糊标准差的两倍 */
    blur: number;

    /** 投影的颜色 */
    color: string;
}

/** 绘制脚本里官网要用到的部分。 */
export interface IconKit {
    /** 图标网格的边长 */
    grid: number;

    /** 底板，缩进在图标网格里 */
    plate: {
        /** 左上角的 x 与 y */
        origin: number;

        /** 边长 */
        size: number;

        /** 连续圆角的路径数据 */
        data: string;

        /** 下方的投影 */
        shadow: PlateShadow;
    };

    /** 几组图标共用的颜色 */
    colors: {
        /** 满月与星星的三档紫色，从深到浅 */
        purples: readonly string[];

        /** 机架上分支符号的线、节点与节点中心 */
        branch: { line: string; node: string; core: string };
    };

    /** 满怀的满月与三颗小星，`ARMFUL_MOON` */
    armfulMoon: { moon: CherryOptions; stars: readonly MoonStar[] };

    /** 满怀里幽灵身体的轮廓锚点与整团的姿态，`ARMFUL_BODY` 与 `ARMFUL_POSE`；跟着滚动的幽灵按它们对齐满怀 */
    armfulGhost: { body: readonly Point[]; pose: ArmfulPose };

    /** 满怀的两只眼睛：跟着滚动的幽灵另画的眼睛落在满怀时移到这里 */
    armfulEyes: ArmfulEyes;

    /** 幽灵近处那只眼睛的形状与默认的倾斜 */
    ghostEye: EyeShape;

    /** 眼睛亮成的四角星 */
    sparkle: SparkleKit;

    /** 拼 SVG 片段的工具 */
    svg: SvgTools;

    /** 取出一组图标在给定样式与指示灯下交给贴纸画法的内容 */
    capture: (group: IconGroup, style: IconStyle, lit: boolean) => IconCapture;

    /** 抱着樱桃的幽灵这一团，`armfulClusterMarkup` */
    armfulCluster: (palette: Palette, lit: boolean) => string;

    /** 共用一圈贴纸边的一团贴纸，`stickerClusterMarkup` */
    cluster: (palette: Palette, lit: boolean, stickers: readonly Sticker[]) => string;

    /** 幽灵的姿态，`ghostPose` */
    ghostPose: (options: GhostPoseOptions) => GhostPose;

    /** 幽灵的贴纸，`ghostSticker` */
    ghostSticker: (options: GhostOptions) => Sticker;

    /** 一台服务器的贴纸，`serverSticker` */
    serverSticker: (options: ServerOptions) => Sticker;

    /** 一颗樱桃的贴纸，`cherrySticker` */
    cherrySticker: (options: CherryOptions) => Sticker;

    /** 樱桃梗的贴纸，`stemSticker` */
    stemSticker: (options: StemOptions) => Sticker;

    /** 从结垂到两颗樱桃的两条梗的中线，`cherryStemLines` */
    cherryStemLines: (knot: CherryOptions, near: CherryOptions, far: CherryOptions) => Point[][];

    /** 紫色的满月与四角星，`moonMarkup` */
    moon: (moon: CherryOptions, stars: readonly MoonStar[]) => string;

    /** 一块新贴纸在 SVG 里用的 id，`stickerId` */
    stickerId: (name: string) => string;
}

/** 排在前面的三份：各组共用的工具与配色；其余各组的脚本按文件名接在后面。 */
const sharedScripts = ['kit.js', 'sticker.js', 'armful.js'];

/**
 * 读取绘制脚本目录里的全部脚本，按执行的先后排好。
 *
 * `directory` 是仓库的 `scripts/make-icon/`。
 */
export function readIconScripts(directory: string): IconScript[] {
    const groups = readdirSync(directory)
        .filter((name) => name.endsWith('.js') && !sharedScripts.includes(name))
        .sort();

    return [...sharedScripts, ...groups].map((name) => ({
        name,
        source: readFileSync(join(directory, name), 'utf8'),
    }));
}

/**
 * 执行绘制脚本，返回官网要用到的函数与常量。
 *
 * 每块贴纸记下造它的函数名与参数，每个幽灵姿态记下造它的参数：拆层与给幽灵换姿势时要靠它们认出各块。
 */
export function createIconKit(scripts: readonly IconScript[]): IconKit {
    const context = vm.createContext({ Path2D: class {} });

    vm.runInContext(
        scripts.map(({ source }) => source).join('\n'),
        context,
        { filename: 'make-icon' },
    );

    // 函数声明是脚本全局对象上的属性，替换之后脚本里的调用也走替换后的版本；`const` 常量要在脚本里求值才取得到
    const global = context as Record<string, unknown>;
    const value = <T>(name: string): T => vm.runInContext(name, context) as T;
    const callable = <T>(name: string): T => functionNamed<T>(global, name);

    tagStickers(global);
    tagPoses(global);

    const capture = captureIcons(global);
    const origin = value<number>('PLATE_ORIGIN');
    const size = value<number>('PLATE_SIZE');
    const sparkles = value<{ reachX: number; reachY: number; rounding: number }>('ARMFUL_SPARKLES');
    const lit = value<{ eye: string[]; eyeGlow: string }>('ARMFUL_LIT');
    const squareData = callable<(left: number, top: number, size: number, radius: number) => string>(
        'continuousSquareData',
    );

    return {
        grid: value<number>('GRID'),
        plate: {
            origin,
            size,
            data: squareData(origin, origin, size, value<number>('PLATE_RADIUS')),
            shadow: value<PlateShadow>('PLATE_SHADOW'),
        },
        colors: {
            purples: value<string[]>('ARMFUL_PURPLES'),
            branch: value<IconKit['colors']['branch']>('HIDE_AND_SEEK_BRANCH'),
        },
        armfulMoon: value<IconKit['armfulMoon']>('ARMFUL_MOON'),
        armfulGhost: { body: value<Point[]>('ARMFUL_BODY'), pose: value<ArmfulPose>('ARMFUL_POSE') },
        armfulEyes: value<ArmfulEyes>('ARMFUL_EYES'),
        ghostEye: value<EyeShape>('STICKER_GHOST_EYE'),
        sparkle: {
            reachX: sparkles.reachX,
            reachY: sparkles.reachY,
            rounding: sparkles.rounding,
            colors: lit.eye,
            glow: lit.eyeGlow,
            data: callable('sparkleData'),
        },
        svg: {
            wide: value<string>('SVG_WIDE'),
            linear: callable('svgLinear'),
            masked: callable('svgMasked'),
            blurred: callable('svgBlurred'),
            innerBand: callable('svgInnerBand'),
        },
        capture,
        armfulCluster: callable('armfulClusterMarkup'),
        cluster: callable('stickerClusterMarkup'),
        ghostPose: callable('ghostPose'),
        ghostSticker: callable('ghostSticker'),
        serverSticker: callable('serverSticker'),
        cherrySticker: callable('cherrySticker'),
        stemSticker: callable('stemSticker'),
        cherryStemLines: callable('cherryStemLines'),
        moon: callable('moonMarkup'),
        stickerId: callable('stickerId'),
    };
}

/**
 * 给名字以 `Sticker` 结尾的函数造出的贴纸记下函数名与参数。
 *
 * 包了一层的贴纸（如 `steadyGhostSticker` 展开 `ghostSticker` 的结果）沿用里面那块的记录。
 */
function tagStickers(global: Record<string, unknown>): void {
    const names = Object.keys(global).filter(
        (name) => name.endsWith('Sticker') && typeof global[name] === 'function',
    );

    for (const name of names) {
        const make = functionNamed<(options: unknown) => Sticker>(global, name);

        global[name] = (options: unknown) => {
            const sticker = make(options);
            sticker.kind ??= name;
            sticker.options ??= options;

            return sticker;
        };
    }
}

/** 给 `ghostPose` 造出的姿态记下造它的参数。 */
function tagPoses(global: Record<string, unknown>): void {
    const make = functionNamed<(options: GhostPoseOptions) => GhostPose>(global, 'ghostPose');

    global['ghostPose'] = (options: GhostPoseOptions) => Object.assign(make(options), { options });
}

/**
 * 换掉画进 Canvas 的两步，返回取出一组图标内容的函数。
 *
 * 各组的入口 `paint…Icon` 先同步拼好整幅画面再交给 `stickerScene`，所以调用一次入口、不等它结束，就记下了这一组的配色、贴纸与画面；
 * 显形背景里的那束光在拼的时候另记一份。
 */
function captureIcons(global: Record<string, unknown>): IconKit['capture'] {
    const stickerCluster = functionNamed<IconKit['cluster']>(global, 'stickerClusterMarkup');
    const armfulCluster = functionNamed<IconKit['armfulCluster']>(global, 'armfulClusterMarkup');
    const beamOf = functionNamed<(options: unknown) => string>(global, 'beamMarkup');

    let scene = '';
    let beam = '';
    let recorded: Omit<IconCapture, 'background' | 'beam'> | undefined;

    global['stickerScene'] = (_pixels: number, markup: string) => {
        scene = markup;

        return Promise.resolve(null);
    };

    global['drawPlateScene'] = () => undefined;

    global['beamMarkup'] = (options: unknown) => {
        beam = beamOf(options);

        return beam;
    };

    global['stickerClusterMarkup'] = (palette: Palette, lit: boolean, stickers: readonly Sticker[]) => {
        const cluster = stickerCluster(palette, lit, stickers);
        recorded = { palette, lit, stickers: [...stickers], cluster };

        return cluster;
    };

    global['armfulClusterMarkup'] = (palette: Palette, lit: boolean) => {
        const cluster = armfulCluster(palette, lit);
        recorded = { palette, lit, stickers: [], cluster };

        return cluster;
    };

    return (group, style, lit) => {
        const entry = `paint${group.charAt(0).toUpperCase()}${group.slice(1)}Icon`;
        const paint = functionNamed<(...args: unknown[]) => Promise<void>>(global, entry);

        scene = '';
        beam = '';
        recorded = undefined;
        void paint(null, 1, 1024, style, lit);

        // 入口在上一行里同步写下了记录，类型推断看不到闭包里的赋值
        const found = recorded as Omit<IconCapture, 'background' | 'beam'> | undefined;

        // 画面是 “底色 + 背景 + 贴纸这一团” 拼成的；对不上说明绘制脚本拼画面的方式变了，这里要跟着改
        if (!found || !scene.endsWith(found.cluster)) {
            throw new Error(`没能从绘制脚本取出 ${group} 图标的贴纸`);
        }

        return {
            ...found,
            background: scene.slice(0, scene.length - found.cluster.length),
            beam,
        };
    };
}

/** 绘制脚本全局对象上的一个函数；没有时报错，说明绘制脚本改了名字。 */
function functionNamed<T>(global: Record<string, unknown>, name: string): T {
    const found = global[name];

    if (typeof found !== 'function') {
        throw new Error(`绘制脚本里没有函数 ${name}`);
    }

    return found as T;
}
