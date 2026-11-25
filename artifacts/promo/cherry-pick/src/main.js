/* global stickerSerial:writable */

import { paintArmful } from './acts/armful.js';
import { paintMidnight } from './acts/midnight.js';
import { paintPerch } from './acts/perch.js';
import { paintPick } from './acts/pick.js';
import { COVER, DURATION, FPS, KEYFRAMES } from './plan.js';
import { paintSky } from './sky.js';
import { ART_LAYERS, buildStage } from './stage.js';
import { widen } from './stickers.js';

/*
 * 入口：等字体与截图就绪后搭好舞台，把 “画出 t 时刻这一帧” 与 “画出封面图” 交给渲染脚本调用。
 *
 * 每一帧都只由时间决定：页面里没有定时器，也没有 CSS 动画与过渡。
 */

/** 夜空与四幕的画，从后往前。 */
const painters = [paintSky, paintMidnight, paintPerch, paintPick, paintArmful];

// 两套字体都是可变字体，各加载一次就覆盖全部字重；文字排版之前必须就绪，否则先按后备字体排一遍。
await Promise.all([
    document.fonts.load('900 92px "Noto Sans SC"', '仓库'),
    document.fonts.load('800 188px "Inter"', 'Spooky'),
]);

const stage = await buildStage(document.getElementById('stage'));

/**
 * 画出 t 时刻的一帧。
 *
 * @param {number} t 时间，秒
 * @param {boolean} cover 是否画成封面图：多亮出只在封面上的一行
 */
function renderAt(t, cover = false) {
    // 贴纸的 id 每帧从头编号：同一时刻总是得到同样的内容，没变化的层不用重画。
    stickerSerial = 0;

    const art = Object.fromEntries(ART_LAYERS.map((name) => [name, '']));

    for (const paint of painters) {
        for (const [name, markup] of Object.entries(paint(t) ?? {})) {
            art[name] += markup;
        }
    }

    // 绘制脚本的蒙版与滤镜只覆盖 1024 见方的图标，放大到整幅竖屏画面之后再交给舞台。
    stage.draw(Object.fromEntries(Object.entries(art).map(([name, markup]) => [name, widen(markup)])));
    stage.show(t, cover);
}

renderAt(0);

/** 交给渲染脚本的接口：时长、帧率、放关键帧的时刻，以及画出某一时刻与画出封面图的函数。 */
window.film = {
    duration: DURATION,
    fps: FPS,
    keyframes: KEYFRAMES,
    renderAt,
    renderCover: () => renderAt(COVER.at, true),
};
