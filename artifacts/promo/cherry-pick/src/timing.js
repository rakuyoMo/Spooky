/*
 * 时间线上的小工具：进度、缓动、出现与消失、眨眼。
 *
 * 全片的每一帧都是时间 t（秒）的纯函数，这里的函数都只依赖传入的参数。
 */

/** 把数值截在 [low, high] 之间。 */
export const clamp = (value, low = 0, high = 1) => Math.min(high, Math.max(low, value));

/** 从 from 到 to 的线性插值，amount 为 0 时取 from、为 1 时取 to。 */
export const lerp = (from, to, amount) => from + (to - from) * amount;

/** 两个等长数组逐项线性插值。 */
export const lerpEach = (from, to, amount) => from.map((value, index) => lerp(value, to[index], amount));

/** t 在 [from, to] 这一段里走过的比例，截在 0–1。 */
export const span = (t, from, to) => clamp((t - from) / (to - from));

/** 先快后慢。 */
export const easeOut = (x) => 1 - (1 - x) ** 3;

/** 先慢后快。 */
export const easeIn = (x) => x ** 3;

/** 两头慢、中间快。 */
export const easeInOut = (x) => (x < 0.5 ? 4 * x ** 3 : 1 - (-2 * x + 2) ** 3 / 2);

/** 两头慢、中间匀：比 easeInOut 平缓，起步与收住都不急。 */
export const easeInOutSine = (x) => (1 - Math.cos(Math.PI * x)) / 2;

/** 先快后慢，到头时略冲过一点再回来；overshoot 越大冲得越多。 */
export const easeOutBack = (x, overshoot = 1.70158) => 1
    + (overshoot + 1) * (x - 1) ** 3
    + overshoot * (x - 1) ** 2;

/**
 * 出现又消失的量：enter 之后的 fadeIn 秒内从 0 升到 1，exit 之前的 fadeOut 秒内降回 0。
 *
 * 文字与截图只用它改不透明度，位置与大小始终不变。
 */
export const presence = (t, enter, exit, fadeIn = 0.3, fadeOut = 0.25) => Math.min(
    span(t, enter, enter + fadeIn),
    1 - span(t, exit - fadeOut, exit),
);

/** 一个来回：在 [from, to] 里从 0 升到 1 再落回 0。 */
export const pulse = (t, from, to) => Math.sin(Math.PI * span(t, from, to));

/**
 * 眨眼的程度：在 times 里的每个时刻闭一次眼，0 是睁着，1 是闭上。
 *
 * @param {number} t 当前时间
 * @param {number[]} times 各次眨眼开始的时刻
 * @param {number} length 一次眨眼的时长
 */
export const blinking = (t, times, length = 0.17) => Math.max(
    0,
    ...times.map((time) => pulse(t, time, time + length)),
);

/** 周期为 period 秒的正弦摆动，取值 −1 到 1；phase 是起始的相位（圈）。 */
export const sway = (t, period, phase = 0) => Math.sin(2 * Math.PI * (t / period + phase));

/**
 * 越摆越小的摆动：从 from 时刻起每 period 秒摆一个来回，幅度每过一秒缩到原来的 e^(−decay)；from 之前为 0。
 *
 * 起摆的那一刻在平衡位置，先往正的一侧摆。
 */
export const ringing = (t, from, period, decay) => (t < from
    ? 0
    : Math.exp(-decay * (t - from)) * Math.sin((2 * Math.PI * (t - from)) / period));
