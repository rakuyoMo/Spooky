/*
 * 全片的安排：帧率、各幕的起止、文案、截图的取景与位置。
 *
 * 时间的单位是秒；文字与截图的位置、大小都是成片的像素，取整数，出现之后不再改变，只改不透明度。
 */

import { presence } from './timing.js';

/** 成片的帧率。 */
export const FPS = 60;

/** 四幕与片尾各自的时长，按先后。四幕依次对应躲猫猫的四组图标：藏身、探身、身前、显形。 */
const LENGTHS = { hide: 5.5, rise: 5, front: 7.5, reveal: 11.5, finale: 5.5 };

/** 四幕与片尾的起止，由各自的时长首尾相接算出。 */
export const ACTS = actsFrom(LENGTHS);

/** 全片的时长。 */
export const DURATION = ACTS.finale.end;

/** 从第一帧就在的文字的出现时刻：排在全片开始之前。 */
const FIRST = -1;

/** 留到最后一帧的文字的消失时刻：排在全片结束之后。 */
const LAST = DURATION + 1;

/** 身前一幕里的几个时刻：对话框出现，指示灯亮起，对话框换成连接状态与三条说明，这一幕的文字消失。 */
export const FRONT = {
    dialog: ACTS.front.start + 1.2,
    connect: ACTS.front.start + 3.6,
    points: ACTS.front.start + 4.1,
    clear: ACTS.front.end - 0.2,
};

/** 显形一幕里每张截图停留的时长。 */
export const BEAT = 2.5;

/** 显形一幕里第一张截图出现的时刻：在它之前是这一幕的标题。 */
const FIRST_BEAT = ACTS.reveal.start + 1.5;

/**
 * 显形一幕里依次亮出的四张截图：卡片的 id、顶上的大字与开始的时刻。
 */
export const BEATS = [
    { card: 'commit', caption: '暂存、提交' },
    { card: 'history', caption: '看历史' },
    { card: 'sync', caption: '同步' },
    { card: 'conflict', caption: '解决冲突' },
].map((beat, index) => ({ ...beat, start: FIRST_BEAT + index * BEAT }));

/** 片尾里的两个时刻：收尾的一句出现，换成名字与网址。 */
export const FINALE = {
    line: ACTS.finale.start + 0.5,
    lockup: ACTS.finale.start + 2.4,
};

/**
 * 编码时放关键帧的时刻：各幕的开头、显形一幕每张截图出现的那一刻、片尾换成名字与网址的那一刻。
 *
 * 除了全片的第一帧，这些时刻画面上没有停留着的文字与截图。
 * 关键帧落在文字停留的时候，编码器把整帧重画一遍，文字的边缘会跟着跳一下。
 */
export const KEYFRAMES = [
    ...Object.values(ACTS).map(({ start }) => start),
    ...BEATS.map(({ start }) => start),
    FINALE.lockup,
];

/**
 * 全片的文字。
 *
 * kind 决定字号与颜色，见 film.css；top 是这一块顶边的 y；lines 是各行的内容，一块里的行距由 kind 决定；
 * enter 与 exit 是出现与消失的时刻，fadeIn 与 fadeOut 省略时取 presence 的默认值。
 */
export const TEXTS = [
    // 藏身
    {
        id: 'hide-title',
        kind: 'headline',
        top: 262,
        lines: ['仓库藏在服务器上？'],
        enter: FIRST,
        exit: ACTS.hide.end - 0.15,
    },
    {
        id: 'hide-found',
        kind: 'headline accent',
        top: 392,
        lines: ['找到了。'],
        enter: ACTS.hide.start + 3.25,
        exit: ACTS.hide.end - 0.15,
    },

    // 探身
    {
        id: 'rise-name',
        kind: 'wordmark',
        top: 236,
        lines: ['Spooky'],
        enter: ACTS.rise.start + 0.95,
        exit: ACTS.rise.end - 0.2,
    },
    {
        id: 'rise-tagline',
        kind: 'tagline',
        top: 478,
        lines: ['原生的 macOS Git 客户端'],
        enter: ACTS.rise.start + 1.35,
        exit: ACTS.rise.end - 0.2,
    },
    {
        id: 'rise-promise',
        kind: 'sub',
        top: 588,
        lines: ['服务器上的 Git 仓库，', '用起来就像本地仓库一样顺手。'],
        enter: ACTS.rise.start + 2.4,
        exit: ACTS.rise.end - 0.2,
    },

    // 身前
    {
        id: 'front-title',
        kind: 'headline',
        top: 250,
        lines: ['远在天边，近在眼前。'],
        enter: ACTS.front.start + 0.5,
        exit: FRONT.clear,
    },
    {
        id: 'front-how',
        kind: 'sub',
        top: 384,
        lines: ['一个主机别名，一个路径。'],
        enter: FRONT.dialog + 0.2,
        exit: FRONT.points,
    },
    {
        id: 'front-point-1',
        kind: 'point green',
        top: 650,
        lines: ['不用克隆到本机'],
        enter: FRONT.points + 0.4,
        exit: FRONT.clear,
    },
    {
        id: 'front-point-2',
        kind: 'point cyan',
        top: 762,
        lines: ['Git 在服务器上执行'],
        enter: FRONT.points + 0.75,
        exit: FRONT.clear,
    },
    {
        id: 'front-point-3',
        kind: 'point green',
        top: 874,
        lines: ['用你现有的 SSH'],
        enter: FRONT.points + 1.1,
        exit: FRONT.clear,
    },

    // 显形
    {
        id: 'reveal-title',
        kind: 'headline',
        top: 250,
        lines: ['从第一处改动，', '到合并分支。'],
        enter: ACTS.reveal.start + 0.5,
        exit: FIRST_BEAT,
    },
    ...BEATS.map(({ card, caption, start }) => ({
        id: `reveal-${card}`,
        kind: 'headline',
        top: 262,
        lines: [caption],
        enter: start,
        exit: start + BEAT,
        fadeIn: 0.25,
        fadeOut: 0.2,
    })),

    // 片尾
    {
        id: 'finale-line',
        kind: 'headline',
        top: 250,
        lines: ['仓库在哪儿，', 'Spooky 就在哪儿。'],
        enter: FINALE.line,
        exit: FINALE.lockup,
    },
    {
        id: 'finale-name',
        kind: 'wordmark small',
        top: 452,
        lines: ['Spooky'],
        enter: FINALE.lockup + 0.1,
        exit: LAST,
    },
    {
        id: 'finale-tagline',
        kind: 'tagline',
        top: 612,
        lines: ['原生的 macOS Git 客户端'],
        enter: FINALE.lockup + 0.25,
        exit: LAST,
    },
    {
        id: 'finale-link',
        kind: 'link',
        top: 712,
        lines: ['spooky.rakuyo.dev'],
        enter: FINALE.lockup + 0.4,
        exit: LAST,
    },
    {
        id: 'finale-note',
        kind: 'note',
        top: 834,
        lines: ['免费开源 · macOS 26 或更高版本'],
        enter: FINALE.lockup + 0.55,
        exit: LAST,
    },
];

/**
 * 封面图：成片在 at 时刻的一帧，问句下面另加一行名字与介绍。这一行只在封面图上，成片里没有。
 */
export const COVER = {
    at: 0,
    line: { kind: 'sub', top: 396, lines: ['Spooky · 原生的 macOS Git 客户端'] },
};

/** 截图所在的目录，相对仓库根目录：官网的简体中文、暗色一套。 */
export const SHOT_DIRECTORY = '/website/src/assets/screenshots/zh-cn/dark';

/** 显形一幕四张截图的取景与位置，与 BEATS 一一对应。 */
const BEAT_SHOTS = [
    { file: 'start-commit.webp', crop: [0, 0, 800, 946], left: 140, top: 640 },
    { file: 'history.webp', crop: [536, 284, 880, 886], left: 100, top: 640 },
    { file: 'sync.webp', crop: [0, 0, 900, 518], left: 90, top: 900 },
    { file: 'conflict.webp', crop: [1471, 372, 940, 946], left: 70, top: 640 },
];

/**
 * 全片的截图卡片。
 *
 * file 是截图的文件名，crop 是取景 [x, y, 宽, 高]，按截图的像素一比一画出、不缩放；
 * left 与 top 是卡片左上角在成片里的位置，radius 是圆角；enter 与 exit 是出现与消失的时刻。
 */
export const CARDS = [
    {
        id: 'add-server',
        file: 'add-server.webp',
        crop: [0, 0, 960, 552],
        left: 60,
        top: 480,
        radius: 34,
        enter: FRONT.dialog,
        exit: FRONT.points,
    },
    {
        id: 'connected',
        file: 'hero.webp',
        crop: [520, 104, 800, 76],
        left: 140,
        top: 508,
        radius: 20,
        enter: FRONT.points + 0.1,
        exit: FRONT.clear,
    },
    ...BEATS.map(({ card, start }, index) => ({
        ...BEAT_SHOTS[index],
        id: card,
        radius: 28,
        enter: start,
        exit: start + BEAT,
        fadeIn: 0.3,
        fadeOut: 0.2,
    })),
];

/** 片尾的应用图标：边长与左上角的位置，出现的时刻。 */
export const APP_ICON = { size: 232, left: 424, top: 214, enter: FINALE.lockup };

/**
 * 一块文字或一张卡片在 t 时刻的不透明度。
 *
 * @param {number} t 当前时间
 * @param {{enter: number, exit: number, fadeIn?: number, fadeOut?: number}} item 文字或卡片
 */
export function shown(t, { enter, exit, fadeIn, fadeOut }) {
    return presence(t, enter, exit, fadeIn, fadeOut);
}

/**
 * 按 id 取一张卡片。
 *
 * @param {string} id 卡片的 id
 */
export function cardNamed(id) {
    return CARDS.find((card) => card.id === id);
}

// MARK: - Private

/**
 * 把各段的时长首尾相接，算出每一段的起止。
 *
 * @param {Record<string, number>} lengths 各段的时长，按先后
 * @returns {Record<string, {start: number, end: number}>}
 */
function actsFrom(lengths) {
    let start = 0;

    return Object.fromEntries(Object.entries(lengths).map(([name, length]) => {
        const act = { start, end: start + length };
        start = act.end;

        return [name, act];
    }));
}
