// 渲染宣传片：在无窗口的 Chromium 里逐帧画出 src/ 的画面并截图，交给 ffmpeg 编码成 H.264 的 MP4。
//
// 用法（在本目录执行，先 npm ci）：
//   node render.mjs                           渲染全片到 out/hide-and-seek.mp4
//   node render.mjs --from 10.5 --to 18       只渲染一段，输出到 out/hide-and-seek-10.5-18.mp4
//   node render.mjs --stills 4.4,8.5,16       导出几个时刻的静帧到 out/stills/
//   node render.mjs --cover                   导出封面图到 out/cover.png
//
// 其它选项：--fps 改帧率（预览用），--qp 改量化参数（越小越清晰、文件越大），--out 指定输出的视频文件。
// Chromium 的位置由环境变量 CHROME 指定，省略时按系统取默认位置。
//
// 关键帧只放在页面给出的时刻（画面上没有文字停留的时候），量化参数全片恒定，不用 B 帧，也不用去块滤波：
// 文字停着不动时，编码后的画面也不动。

import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { parseArgs } from 'node:util';

import ffmpegPath from 'ffmpeg-static';
import puppeteer from 'puppeteer-core';

/** 本目录，以及仓库根目录：页面要用仓库里的图标绘制脚本与官网截图，静态服务从仓库根目录提供文件。 */
const here = import.meta.dirname;
const repository = resolve(here, '../../..');

/** 舞台页面相对仓库根目录的路径。 */
const pagePath = '/artifacts/promo/hide-and-seek/src/index.html';

/** 成片的像素尺寸，与 src/stickers.js 的 STAGE 相同。 */
const size = { width: 1080, height: 1920 };

/** 静态服务按扩展名给出的内容类型。 */
const contentTypes = {
    '.css': 'text/css; charset=utf-8',
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.png': 'image/png',
    '.ttf': 'font/ttf',
    '.webp': 'image/webp',
};

const { values: options } = parseArgs({
    options: {
        from: { type: 'string' },
        to: { type: 'string' },
        fps: { type: 'string' },
        qp: { type: 'string', default: '12' },
        out: { type: 'string' },
        stills: { type: 'string' },
        cover: { type: 'boolean' },
    },
});

const server = await serve();
const browser = await launch();

try {
    const page = await openStage(browser, `http://127.0.0.1:${server.address().port}${pagePath}`);
    const film = await page.evaluate(() => {
        const { duration, fps, keyframes } = window.film;

        return { duration, fps, keyframes };
    });

    if (options.cover) {
        await exportCover(page);
    } else if (options.stills) {
        await exportStills(page, options.stills.split(',').map(Number));
    } else {
        await exportVideo(page, film);
    }
} finally {
    await browser.close();
    server.close();
}

/**
 * 启动只读的静态服务，从仓库根目录提供文件，只监听本机。
 *
 * @returns {Promise<import('node:http').Server>}
 */
async function serve() {
    const created = createServer(async (request, response) => {
        const path = normalize(decodeURIComponent(new URL(request.url, 'http://localhost').pathname));
        const file = join(repository, path);

        // 只提供仓库目录里面的文件。
        if (!file.startsWith(repository + sep)) {
            response.writeHead(403).end();
            return;
        }

        try {
            const body = await readFile(file);
            response.writeHead(200, { 'content-type': contentTypes[extname(file)] ?? 'application/octet-stream' });
            response.end(body);
        } catch {
            response.writeHead(404).end();
        }
    });

    created.listen(0, '127.0.0.1');
    await once(created, 'listening');

    return created;
}

/**
 * 启动无窗口的 Chromium。
 *
 * 文字一律按灰度抗锯齿、不做字形微调：同一行字无论不透明度是多少，每一帧栅格出来的形状都相同。
 */
async function launch() {
    const fallback = process.platform === 'darwin'
        ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
        : '/usr/bin/chromium';

    return puppeteer.launch({
        executablePath: process.env.CHROME ?? fallback,
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-lcd-text',
            '--font-render-hinting=none',
            '--force-color-profile=srgb',
            '--hide-scrollbars',
        ],
    });
}

/**
 * 打开舞台页面，等它把字体、截图与第一帧都准备好。
 *
 * @param {import('puppeteer-core').Browser} launched 浏览器
 * @param {string} url 舞台页面的地址
 */
async function openStage(launched, url) {
    const page = await launched.newPage();

    page.on('console', (message) => console.log(`[页面] ${message.text()}`));

    page.on('pageerror', (error) => {
        console.error(`[页面出错] ${error.message}`);
        process.exitCode = 1;
    });

    await page.setViewport({ ...size, deviceScaleFactor: 1 });
    await page.goto(url);
    await page.waitForFunction(() => window.film !== undefined, { timeout: 60_000 });

    return page;
}

/**
 * 画出一个时刻并截图。
 *
 * @param {import('puppeteer-core').Page} page 舞台页面
 * @param {number} time 时间，秒
 * @returns {Promise<Uint8Array>} PNG
 */
async function capture(page, time) {
    await page.evaluate((t) => window.film.renderAt(t), time);

    return page.screenshot({ type: 'png', optimizeForSpeed: true });
}

/**
 * 导出几个时刻的静帧。
 *
 * @param {import('puppeteer-core').Page} page 舞台页面
 * @param {number[]} times 各个时刻，秒
 */
async function exportStills(page, times) {
    const directory = join(here, 'out', 'stills');
    await mkdir(directory, { recursive: true });

    for (const time of times) {
        const file = join(directory, `${time.toFixed(2).padStart(5, '0')}.png`);
        await writeFile(file, await capture(page, time));
        console.log(file);
    }
}

/**
 * 导出封面图：成片的第一帧，问句下面另加一行名字与介绍。
 *
 * @param {import('puppeteer-core').Page} page 舞台页面
 */
async function exportCover(page) {
    const file = join(here, 'out', 'cover.png');
    await mkdir(join(here, 'out'), { recursive: true });

    await page.evaluate(() => window.film.renderCover());
    await writeFile(file, await page.screenshot({ type: 'png' }));
    console.log(file);
}

/**
 * 逐帧截图并编码成视频。
 *
 * @param {import('puppeteer-core').Page} page 舞台页面
 * @param {{duration: number, fps: number, keyframes: number[]}} film 全片的时长、帧率与放关键帧的时刻
 */
async function exportVideo(page, film) {
    const fps = Number(options.fps ?? film.fps);
    const from = Number(options.from ?? 0);
    const to = Number(options.to ?? film.duration);
    const whole = from === 0 && to === film.duration;

    const output = options.out
        ? resolve(options.out)
        : join(here, 'out', whole ? 'hide-and-seek.mp4' : `hide-and-seek-${from}-${to}.mp4`);

    await mkdir(join(output, '..'), { recursive: true });

    const first = Math.round(from * fps);
    const last = Math.round(to * fps);

    // 关键帧的时刻换成从这一段开头算起的时间，只留落在这一段中间的；开头的一帧本来就是关键帧。
    const keyframes = film.keyframes
        .map((time) => time - from)
        .filter((time) => time > 0 && time < to - from)
        .sort((one, other) => one - other);

    const encoder = startEncoder({ fps, frames: last - first, keyframes, output });
    const started = Date.now();

    for (let index = first; index < last; index += 1) {
        const frame = await capture(page, index / fps);

        // 编码器来不及读时等它腾出空间，帧不在内存里堆积。
        if (!encoder.stdin.write(frame)) {
            await once(encoder.stdin, 'drain');
        }

        const done = index - first + 1;

        if (done % fps === 0 || index === last - 1) {
            const total = last - first;
            const elapsed = (Date.now() - started) / 1000;
            const remaining = (elapsed / done) * (total - done);

            console.log(`${done} / ${total} 帧，已用 ${elapsed.toFixed(0)} 秒，还需约 ${remaining.toFixed(0)} 秒`);
        }
    }

    encoder.stdin.end();
    const [code] = await once(encoder, 'close');

    if (code !== 0) {
        throw new Error(`ffmpeg 以 ${code} 退出`);
    }

    console.log(output);
}

/**
 * 启动 ffmpeg：从标准输入读 PNG 帧，编码成 H.264、yuv420p 的 MP4，按 BT.709 标注色彩。
 *
 * @param {object} settings
 * @param {number} settings.fps 帧率
 * @param {number} settings.frames 总帧数
 * @param {number[]} settings.keyframes 放关键帧的时刻，从第一帧算起的秒数
 * @param {string} settings.output 输出的文件
 */
function startEncoder({ fps, frames, keyframes, output }) {
    return spawn(ffmpegPath, [
        '-y',
        '-loglevel', 'error',
        '-f', 'image2pipe',
        '-framerate', String(fps),
        '-c:v', 'png',
        '-i', '-',
        '-vf', 'scale=out_color_matrix=bt709:out_range=tv,format=yuv420p',
        '-c:v', 'libx264',
        '-preset', 'veryslow',
        '-profile:v', 'high',

        // 量化参数全片恒定：静止的区域编码一次就到位，此后的帧原样沿用。
        // 按 CRF 编码时每个宏块的量化参数随时间调整，静止的文字会被一次次细微地修正。
        '-qp', options.qp,

        // 关键帧只放在指定的时刻：不按固定的间隔放，也不让编码器在画面变化大的地方自己加。
        '-g', String(frames),
        '-sc_threshold', '0',
        ...(keyframes.length > 0 ? ['-force_key_frames', keyframes.join(',')] : []),

        // 不用 B 帧：B 帧里静止的细线会按邻近的运动去预测，亮度略有偏差，看上去隔一帧闪一下。
        '-bf', '0',

        // 不用去块滤波：静止的区域里宏块的编码方式一变，滤波的强度跟着变，宏块边上的一列像素会跳一下。
        // 量化参数取得低，画面上没有要它掩盖的方块。
        //
        // 不用心理视觉优化：它多花码率去保留噪点与纹理的观感，这里的画面是平涂的色块与文字。
        //
        // 参考帧取 5 帧：veryslow 预设默认的 16 帧会把 Level 从 5.0 抬到 5.1。
        '-x264-params', 'no-deblock=1:psy-rd=0,0:ref=5',

        '-color_primaries', 'bt709',
        '-color_trc', 'bt709',
        '-colorspace', 'bt709',
        '-color_range', 'tv',
        '-movflags', '+faststart',
        output,
    ], { stdio: ['pipe', 'inherit', 'inherit'] });
}
