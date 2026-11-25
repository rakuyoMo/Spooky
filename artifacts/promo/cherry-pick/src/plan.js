/*
 * 全片的安排：帧率、各幕的起止、文案、截图的取景与位置。
 *
 * 时间的单位是秒；文字与截图的位置、大小都是成片的像素，取整数，出现之后不再改变，只改不透明度。
 */

import { presence } from './timing.js';

/** 成片的帧率。 */
export const FPS = 60;

/** 四幕各自的时长，按先后。四幕依次对应 cherry-pick 系列的四组图标：午夜、栖枝、采撷、满怀；片尾在满怀一幕里。 */
const LENGTHS = { midnight: 3.6, perch: 7.9, pick: 2.2, armful: 7.05 };

/** 四幕的起止，由各自的时长首尾相接算出。 */
export const ACTS = actsFrom(LENGTHS);

/** 全片的时长。 */
export const DURATION = ACTS.armful.end;

/** 从第一帧就在的文字的出现时刻：排在全片开始之前。 */
const FIRST = -1;

/** 留到最后一帧的文字的消失时刻：排在全片结束之后。 */
const LAST = DURATION + 1;

/** 午夜一幕里的一个时刻：大标语换成名字。 */
export const MIDNIGHT = {
    name: ACTS.midnight.start + 1.8,
};

/** 栖枝一幕里的三个时刻：镜头停住、整棵树落定，幽灵落到枝上，眼睛亮成四角星。 */
export const PERCH = {
    halt: ACTS.perch.start + 0.95,
    land: ACTS.perch.start + 1.35,
    spark: ACTS.perch.start + 1.6,
};

/** 栖枝一幕里每张截图停留的时长。 */
const BEAT = 1.5;

/** 栖枝一幕里第一张截图出现的时刻：在它之前，幽灵飞下来落到枝头、望见樱桃。 */
const FIRST_BEAT = ACTS.perch.start + 1.9;

/**
 * 栖枝一幕里截图与它顶上的大字淡入、淡出的时长，两者用同一组。
 *
 * 卡片的投影漫到大字的脚下：两者同时停住，大字停住之后它的四周才不再变化。
 */
const BEAT_FADE = { fadeIn: 0.3, fadeOut: 0.2 };

/**
 * 栖枝一幕里依次亮出的四张截图：卡片的 id、顶上的大字与开始的时刻。每换一张，幽灵换一个样子：
 * 停在落下的地方，朝樱桃飘过去，停在樱桃跟前，从枝上飘起来凑上去；最后一张是 “摘取”，紧接着它就伸手去摘。
 *
 * 大字的一行可以是一段文字，也可以由几段拼成：带 gloss 的一段在字的上面标一行小字。
 */
export const BEATS = [
    { card: 'lines', caption: '挑几行，暂存' },
    { card: 'files', caption: '挑文件，提交' },
    { card: 'sides', caption: '挑一边，解决冲突' },
    { card: 'commits', caption: ['挑提交，', { base: '摘取', gloss: 'cherry-pick' }] },
].map((beat, index) => ({ ...beat, start: FIRST_BEAT + index * BEAT }));

/** 采撷一幕里的两个时刻：镜头推近到位，小手搭上樱桃。 */
export const PICK = {
    close: ACTS.pick.start + 0.95,
    touch: ACTS.pick.start + 1.1,
};

/** 满怀一幕里的几个时刻：梗从枝上断开，樱桃抱进怀里，收尾的一句出现，换成名字与网址。 */
export const ARMFUL = {
    snap: ACTS.armful.start + 0.42,
    hug: ACTS.armful.start + 1.25,
    line: ACTS.armful.start + 1.55,
    lockup: ACTS.armful.start + 3.55,
};

/**
 * 编码时放关键帧的时刻：大标语换成名字的那一刻、每张截图出现的那一刻、采撷一幕的开头、
 * 樱桃抱进怀里的那一刻、片尾换成名字与网址的那一刻。
 *
 * 除了全片的第一帧，这些时刻画面上没有停留着的文字与截图。关键帧落在文字停留的时候，编码器把整帧重画一遍，
 * 文字的边缘会跟着跳一下。栖枝与满怀两幕的开头不在其中：前一幕的文字这时还在画面上。
 */
export const KEYFRAMES = [
    MIDNIGHT.name,
    ...BEATS.map(({ start }) => start),
    ACTS.pick.start,
    ARMFUL.hug,
    ARMFUL.lockup,
];

/**
 * 全片的文字。
 *
 * kind 决定字号与颜色，见 film.css；top 是这一块顶边的 y；lines 是各行的内容，一块里的行距由 kind 决定；
 * enter 与 exit 是出现与消失的时刻，fadeIn 与 fadeOut 省略时取 presence 的默认值。
 */
export const TEXTS = [
    // 午夜：大标语，从第一帧就在
    {
        id: 'far',
        kind: 'couplet',
        top: 290,
        lines: [[{ base: '远', gloss: '仓库' }, '在天边，']],
        enter: FIRST,
        exit: MIDNIGHT.name,
    },
    {
        id: 'near',
        kind: 'couplet accent',
        top: 514,
        lines: [[{ base: '近', gloss: '操作' }, '在眼前。']],
        enter: FIRST,
        exit: MIDNIGHT.name,
    },

    // 午夜：名字与一句话的介绍，留到栖枝一幕里幽灵落到枝上的那一刻；
    // 镜头下降、幽灵落向枝头时，画的动静都在画面下方，不从字的背后经过
    {
        id: 'name',
        kind: 'wordmark',
        top: 196,
        lines: ['Spooky'],
        enter: MIDNIGHT.name + 0.1,
        exit: PERCH.land,
    },
    {
        id: 'tagline',
        kind: 'tagline',
        top: 438,
        lines: ['原生的 macOS Git 客户端'],
        enter: MIDNIGHT.name + 0.35,
        exit: PERCH.land,
    },
    {
        id: 'promise',
        kind: 'sub',
        top: 548,
        lines: ['服务器上的 Git 仓库，', '用起来就像本地仓库一样顺手。'],
        enter: MIDNIGHT.name + 0.6,
        exit: PERCH.land,
    },

    // 栖枝：四张截图顶上的大字
    ...BEATS.map(({ card, caption, start }) => ({
        id: `beat-${card}`,
        kind: 'headline',
        top: 196,
        lines: [caption],
        enter: start,
        exit: start + BEAT,
        ...BEAT_FADE,
    })),

    // 采撷：标题，留到满怀一幕里樱桃抱进怀里的那一刻；幽灵在它下面接着把樱桃摘下来
    {
        id: 'pick-title',
        kind: 'headline',
        top: 250,
        lines: ['不用克隆，'],
        enter: ACTS.pick.start + 0.4,
        exit: ARMFUL.hug,
    },
    {
        id: 'pick-reach',
        kind: 'headline accent',
        top: 372,
        lines: ['伸手就摘。'],
        enter: PICK.touch - 0.05,
        exit: ARMFUL.hug,
    },
    {
        id: 'pick-how',
        kind: 'sub small',
        top: 526,
        lines: ['Git 在服务器上执行 · 用你现有的 SSH'],
        enter: PICK.touch + 0.25,
        exit: ARMFUL.hug,
    },

    // 满怀与片尾
    {
        id: 'closing',
        kind: 'headline',
        top: 250,
        lines: ['仓库在哪儿，', 'Spooky 就在哪儿。'],
        enter: ARMFUL.line,
        exit: ARMFUL.lockup,
    },
    {
        id: 'finale-name',
        kind: 'wordmark small',
        top: 420,
        lines: ['Spooky'],
        enter: ARMFUL.lockup + 0.1,
        exit: LAST,
    },
    {
        id: 'finale-tagline',
        kind: 'tagline',
        top: 580,
        lines: ['原生的 macOS Git 客户端'],
        enter: ARMFUL.lockup + 0.25,
        exit: LAST,
    },
    {
        id: 'finale-link',
        kind: 'link',
        top: 680,
        lines: ['spooky.rakuyo.dev'],
        enter: ARMFUL.lockup + 0.4,
        exit: LAST,
    },
    {
        id: 'finale-note',
        kind: 'note',
        top: 802,
        lines: ['免费开源 · macOS 26 或更高版本'],
        enter: ARMFUL.lockup + 0.55,
        exit: LAST,
    },
];

/**
 * 封面图：成片在 at 时刻的一帧，大标语下面另加一行名字与介绍。这一行只在封面图上，成片里没有。
 */
export const COVER = {
    at: 0,
    line: { kind: 'tagline', top: 702, lines: ['Spooky · 原生的 macOS Git 客户端'] },
};

/** 截图所在的目录，相对仓库根目录：官网的简体中文、暗色一套。 */
export const SHOT_DIRECTORY = '/website/src/assets/screenshots/zh-cn/dark';

/**
 * 栖枝一幕四张截图的取景与位置，与 BEATS 一一对应。
 *
 * 这一幕是远景，幽灵与樱桃树缩在画面下方，上方大半幅都给截图；四张的顶边对齐。
 * 取景的底边落在截图里一行的下缘；冲突向导的一张取到下面那个框的底边，再留出一点边距。
 * 卡片的底边留在幽灵与樱桃树的上方：最长的一张连同贴纸边到 y = 1338；细枝伸进画面的地方顶到 y = 1384，
 * 幽灵凑到樱桃跟前时头顶到 y = 1385。
 * 满月挂在画面左半边的高处：头一张短，只挡住它的上沿；后三张挡住它的大半，底下露出一段。
 */
const BEAT_SHOTS = [
    { file: 'staging.webp', crop: [0, 0, 872, 698], left: 104, top: 356 },
    { file: 'start-commit.webp', crop: [0, 80, 800, 922], left: 140, top: 356 },
    { file: 'conflict.webp', crop: [1493, 362, 896, 966], left: 92, top: 356 },
    { file: 'history.webp', crop: [540, 336, 852, 920], left: 114, top: 356 },
];

/**
 * 全片的截图卡片：栖枝一幕的四张。
 *
 * file 是截图的文件名，crop 是取景 [x, y, 宽, 高]，按截图的像素一比一画出、不缩放；
 * left 与 top 是卡片左上角在成片里的位置，radius 是圆角；enter 与 exit 是出现与消失的时刻。
 */
export const CARDS = BEATS.map(({ card, start }, index) => ({
    ...BEAT_SHOTS[index],
    id: card,
    radius: 28,
    enter: start,
    exit: start + BEAT,
    ...BEAT_FADE,
}));

/** 片尾的应用图标：边长与左上角的位置，出现的时刻。 */
export const APP_ICON = { size: 232, left: 424, top: 182, enter: ARMFUL.lockup };

/**
 * 一块文字或一张卡片在 t 时刻的不透明度。
 *
 * @param {number} t 当前时间
 * @param {{enter: number, exit: number, fadeIn?: number, fadeOut?: number}} item 文字或卡片
 */
export function shown(t, { enter, exit, fadeIn, fadeOut }) {
    return presence(t, enter, exit, fadeIn, fadeOut);
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
