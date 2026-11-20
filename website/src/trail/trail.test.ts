import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { createIconKit, readIconScripts } from '../art/kit.ts';
import { createTrailArt } from '../art/trail.ts';
import { clamp, gazeAt, poseAt, rampAt } from './cues.ts';
import type { FrameTrack, TrackFrame } from './frames.ts';
import {
    approach,
    type Box,
    findGaps,
    ghostHalf,
    planTrail,
    sampleTrail,
    spring,
    type TrailLayout,
    type TrailMetrics,
    type TrailPlan,
} from './path.ts';
import { imageKey } from './scene.ts';
import { framesOf, type TrailState } from './tracks.ts';

/*
 * 首页小幽灵路线的自测：起点与终点和静止的画重合，顺着窗口边滑，停靠的时机，伸手、亮灯与眼神跟着滚动的时机，
 * 横穿的空当，不在正文后面停留，收尾各步的先后，插值的连续，滚动时间线的关键帧，以及趋近与弹簧与帧率无关。
 *
 * 两份布局取自首页在宽 1440 与宽 390 的视口里量出的位置。
 *
 * 在 `website/` 下运行：`node --test src/trail/trail.test.ts`
 */

/** 画的尺寸，取自构建时写出的 JSON。 */
const metrics: TrailMetrics = {
    unit: 0.19,
    anchors: {
        hero: { centre: [0.5, 0.46487], unit: 0.000746536 },
        server: { centre: [0.641895, 0.649859], unit: 0.00106635 },
        reveal: { centre: [0.465985, 0.382626], unit: 0.000847458 },
        armful: { centre: [0.434487, 0.520837], unit: 0.00110837 },
    },
    hideEdge: 27.09,
    pawDrop: 14,
    branchReach: 170.86,
    branchSpan: [-101.56, 15.04],
    cherry: [90.97, -11.74],
};

/** 应用图标的绘制脚本所在的目录。 */
const scripts = fileURLToPath(new URL('../../../scripts/make-icon', import.meta.url));

/** 跟着滚动的画：排滚动时间线的关键帧时用到。 */
const art = createTrailArt(createIconKit(readIconScripts(scripts)));

/** 宽 1440、高 900 的视口里量出的首页布局。 */
const wide = layout({
    width: 1440,
    height: 900,
    end: 5698,
    column: [184, 1256],
    hero: [656, 160, 784, 288],
    heading: [416, 308, 1024, 511],
    headline: [453, 348, 987, 427],
    window: [80, 700, 1360, 1500],
    server: [959, 2031, 1119, 2179],
    media: [[673, 2909, 1256, 3185], [184, 3737, 767, 4298], [184, 4629, 1256, 5299]],
    reveal: [184, 4410, 363, 4581],
    revealTitle: [411, 4431, 1019, 4466],
    armful: [643, 5911, 797, 6065],
    title: [400, 6093, 1040, 6207],
    blocks: [
        [656, 160, 784, 288], [687, 308, 753, 340], [453, 348, 987, 427], [416, 447, 1024, 511],
        [40, 543, 1400, 591], [40, 611, 1400, 636], [80, 700, 1360, 1500], [352, 1735, 1088, 1910],
        [184, 1974, 1256, 2356], [184, 2384, 1256, 2412], [184, 2476, 437, 2797], [457, 2476, 710, 2797],
        [730, 2476, 983, 2797], [1003, 2476, 1256, 2797], [184, 2937, 601, 3157], [673, 2909, 1256, 3185],
        [352, 3441, 1088, 3673], [839, 3921, 1256, 4114], [184, 3737, 767, 4298], [184, 4410, 363, 4581],
        [411, 4431, 1019, 4559], [184, 4629, 1256, 5299], [184, 5363, 437, 5633], [457, 5363, 710, 5633],
        [730, 5363, 983, 5633], [1003, 5363, 1256, 5633], [643, 5911, 797, 6065], [400, 6093, 1040, 6207],
        [567, 6235, 873, 6283], [400, 6311, 1040, 6359], [0, 6509, 1440, 6598],
    ],
});

/** 宽 390、高 844 的视口里量出的首页布局。 */
const narrow = layout({
    width: 390,
    height: 844,
    end: 7324,
    column: [20, 370],
    hero: [151, 104, 239, 192],
    heading: [20, 212, 370, 429],
    headline: [52, 252, 338, 294],
    window: [16, 593, 374, 1902],
    server: [115, 3074, 275, 3222],
    media: [[20, 4589, 370, 4790], [20, 5427, 370, 5763], [20, 6237, 370, 6456]],
    reveal: [20, 5827, 199, 5998],
    revealTitle: [20, 6026, 370, 6055],
    armful: [118, 7437, 272, 7591],
    title: [20, 7619, 370, 7690],
    blocks: [
        [151, 104, 239, 192], [162, 212, 228, 244], [52, 252, 338, 294], [20, 314, 370, 429],
        [16, 461, 374, 509], [16, 529, 374, 553], [16, 593, 374, 1902], [20, 2268, 370, 2477],
        [20, 2517, 370, 3375], [20, 3403, 370, 3431], [20, 3471, 370, 3622], [20, 3642, 370, 3793],
        [20, 3813, 370, 4016], [20, 4036, 370, 4249], [20, 4313, 370, 4557], [20, 4589, 370, 4790],
        [20, 4934, 370, 5143], [20, 5183, 370, 5395], [20, 5427, 370, 5763], [20, 5827, 199, 5998],
        [20, 6026, 370, 6209], [20, 6237, 370, 6456], [20, 6496, 370, 6673], [20, 6693, 370, 6871],
        [20, 6891, 370, 7076], [20, 7096, 370, 7229], [118, 7437, 272, 7591], [20, 7619, 370, 7690],
        [42, 7718, 348, 7766], [20, 7794, 370, 7865], [0, 8001, 390, 8168],
    ],
});

for (const [name, page] of [
    ['宽屏', wide],
    ['手机', narrow],
] as const) {
    test(`${name}：起点与顶部图标里的幽灵重合，终点与收尾的满怀重合，往回滚回到同一处`, () => {
        const plan = planTrail(page, metrics);
        const hero = anchored(page.hero, metrics.anchors.hero);
        const armful = anchored(page.armful, metrics.anchors.armful);
        const start = sampleTrail(plan, 0);
        const finish = sampleTrail(plan, page.end);

        // 起点：位置与大小都和图标里的那只一样，姿势是举手探身
        assert.ok(near(start, hero) && poseOf(plan, 0) === 'rise');

        // 终点：落在满怀那幅画里，停稳不飘
        assert.ok(near(finish, armful) && poseOf(plan, page.end) === 'armful' && finish.bob === 0);
        assert.ok(plan.home <= page.end, '滚到底之前就已落定');

        // 关键帧、姿势与眼神的各站都按滚动的距离排好：一切只由滚动的距离决定
        assert.ok(ascending(plan.keys.map(({ s }) => s), true));
        assert.ok(ascending(plan.poses.flatMap(({ from, to }) => [from, to])));
        assert.ok(ascending(plan.gaze.map(({ s }) => s)));
    });

    test(`${name}：机架身前的位置从视口高度 78% 处升到导航栏以下 30% 处的一段里，幽灵停在那里抬着手、望着机架，灯全亮；离开时视线慢慢移回前方`, () => {
        const plan = planTrail(page, metrics);
        const server = anchored(page.server, metrics.anchors.server);
        const from = server.y - 0.78 * page.height;
        const to = server.y - page.header - 0.3 * (page.height - page.header);
        const [lampsOn, docked, leaving, lampsOff] = plan.lamps;

        for (let s = from; s <= to; s += 10) {
            assert.ok(near(sampleTrail(plan, s), server) && poseOf(plan, s) === 'front', `s = ${s} 时还没停稳`);
            assert.ok(rampAt(plan.lamps, s) === 1 && facing(plan, s, [-1, 0]), `s = ${s} 时灯没全亮或没望着机架`);
        }

        // 飞过来时，横向离停靠处还剩画宽的 0.65 倍时小手开始伸出，剩 0.56 倍时身子碰到机器、灯开始亮起；离开时反过来
        const front = plan.poses.findIndex(({ pose }) => pose === 'front');
        const handOut = plan.poses[front - 1]?.to ?? Number.NaN;
        const handIn = plan.poses[front + 1]?.from ?? Number.NaN;
        const width = page.server.right - page.server.left;
        const apart = (s: number): number => Math.abs(sampleTrail(plan, s).x - server.x) / width;

        assert.ok(handOut < lampsOn && lampsOn < docked && leaving < lampsOff && lampsOff < handIn);
        assert.ok([handOut, handIn].every((s) => Math.abs(apart(s) - 0.65) < 1e-3));
        assert.ok([lampsOn, lampsOff].every((s) => Math.abs(apart(s) - 0.56) < 1e-3));

        // 开始离开之后，视线在 0.44 屏里从机架上一路移回屏幕前，不往回转
        let previous = Number.NEGATIVE_INFINITY;

        for (let s = leaving; s <= leaving + 0.44 * page.height; s += 5) {
            const [x] = gazeOf(plan, s);

            assert.ok(x >= previous - 1e-9, `s = ${Math.round(s)} 时视线往回转了`);
            previous = x;
        }

        assert.ok(facing(plan, leaving + 0.44 * page.height, [0, 0]));

        // 离开的路上，身体还没出这幅画的右边时一直在画的下边以上：不从下面的标题后面经过
        const leave = plan.keys.find(({ s }) => s > leaving);

        assert.ok(leave && leave.x > page.server.right);

        for (let s = leaving; s <= leave.s; s += 10) {
            const { x, y, u } = sampleTrail(plan, s);
            const clear = bodyBox(x, y, u).left >= page.server.right || y < page.server.bottom;

            assert.ok(clear, `s = ${Math.round(s)} 时落到了画的下边以下`);
        }
    });

    test(`${name}：路过服务器与显形之间的两段介绍时，眼神落在配图里的同一点上、跟着它走，两段之间望着前方`, () => {
        const plan = planTrail(page, metrics);
        const [first, second] = page.media
            .filter(({ top, bottom }) => top > page.server.bottom && bottom <= page.reveal.top)
            .map(({ top, bottom }) => ({
                x: (page.column.left + page.column.right) / 2,
                y: top + 0.31 * (bottom - top),
            }));

        assert.ok(first && second);

        // 第一段：那一点从视口高度的 72% 处升到 59% 处的一段里望着它
        for (let s = first.y - 0.72 * page.height; s <= first.y - 0.59 * page.height; s += 10) {
            assert.ok(looksAt(plan, s, first), `s = ${Math.round(s)} 时没望着第一幅配图`);
        }

        // 两段之间望着前方
        for (let s = first.y - 0.53 * page.height; s <= second.y - 0.78 * page.height; s += 10) {
            assert.ok(facing(plan, s, [0, 0]), `s = ${Math.round(s)} 时没望着前方`);
        }

        // 第二段：那一点升到 72% 处时望着它，一直望到动身飘进显形的光里之前
        const docked = anchored(page.reveal, metrics.anchors.reveal);
        const arrive = plan.keys[plan.keys.findIndex((current) => current.hold && near(current, docked)) - 1];

        assert.ok(arrive);

        for (let s = second.y - 0.72 * page.height; s <= arrive.s - 0.135 * page.height; s += 10) {
            assert.ok(looksAt(plan, s, second), `s = ${Math.round(s)} 时没望着第二幅配图`);
        }
    });

    test(`${name}：显形的幽灵在视口高度 70% 到 30% 之间时停在光里，光束与灯全亮、望着那一段的标题；离开后望着下面的配图，飘过它的大半之后望回前方`, () => {
        const plan = planTrail(page, metrics);
        const docked = anchored(page.reveal, metrics.anchors.reveal);
        const beam = plan.beam;

        assert.ok(beam);

        for (let s = docked.y - 0.7 * page.height; s < docked.y - 0.3 * page.height; s += 10) {
            assert.ok(near(sampleTrail(plan, s), docked) && poseOf(plan, s) === 'reveal', `s = ${s} 时不在光里`);
            assert.ok(
                rampAt(beam, s) === 1 && looksAt(plan, s, centre(page.revealTitle)),
                `s = ${s} 时灯没全亮或没望着标题`,
            );
        }

        // 飞来时身子碰到画里的服务器才开始亮，离开时走出同样远时已经熄灭
        const [beamOn, , leaving, beamOff] = beam;
        const width = page.reveal.right - page.reveal.left;
        const apart = (s: number): number => Math.abs(sampleTrail(plan, s).x - docked.x) / width;

        assert.ok([beamOn, beamOff].every((s) => Math.abs(apart(s) - 0.56) < 1e-3));

        // 灯灭之后幽灵往左飘：高度不变，不从下面的服务器前面经过，最后整个在这幅画的左边
        const away = plan.keys.find(({ s }) => s > beamOff);

        assert.ok(away && Math.abs(away.y - docked.y) < 1 && poseOf(plan, away.s) === 'float');
        assert.ok(away.x + ghostHalf.width * away.u <= page.reveal.left);

        // 离开时望向下面那幅配图的正中，身体正中降到配图高度的 78% 处之后望回前方；樱桃枝开始滑进来时已经望着前方
        const media = page.media.find(({ top }) => top >= page.reveal.top);

        assert.ok(media);

        const line = media.top + 0.78 * (media.bottom - media.top);
        const passed = Math.min(
            crossing(leaving, page.end, (s) => sampleTrail(plan, s).y, line),
            plan.branch.from - 0.06 * page.height,
        );

        for (let s = leaving + 0.06 * page.height; s < passed; s += 10) {
            assert.ok(looksAt(plan, s, centre(media)), `s = ${Math.round(s)} 时没望着配图`);
        }

        assert.ok(facing(plan, passed + 0.06 * page.height, [0, 0]));
    });

    test(`${name}：飘在道上、横穿空当与够樱桃时，身体不压在文字后面`, () => {
        const plan = planTrail(page, metrics);
        const moving = new Set(['float', 'spot', 'reach']);

        // 演示窗口不透明，幽灵顺着它的边滑下去时整个藏在后面；显形那幅画是幽灵要停进去的地方：两块都不算文字
        const text = page.blocks.filter(({ top }) => top !== page.window.top && top !== page.reveal.top);

        for (const current of plan.keys.filter(({ s }) => moving.has(poseOf(plan, s) ?? ''))) {
            const body = bodyBox(current.x, current.y, current.u);
            const hit = text.find((block) => overlaps(body, block));

            assert.equal(hit, undefined, `s = ${Math.round(current.s)} 的 ${poseOf(plan, current.s)} 压住了正文`);
        }

        // 离开服务器之后到摘下樱桃，两帧之间的路上也不压住：换道只走空当
        const leave = plan.keys.find(({ s, hold }) => s > plan.lamps[1] && !hold);

        for (let s = leave?.s ?? 0; s < plan.branch.pick; s += 10) {
            const { x, y, u } = sampleTrail(plan, s);
            const hit = text.find((block) => overlaps(bodyBox(x, y, u), block));

            assert.equal(hit, undefined, `s = ${Math.round(s)} 时压住了正文`);
        }
    });

    test(`${name}：第一次横穿页面时慢慢翻一整圈，樱桃枝最粗的一头落在视口右边以外`, () => {
        const plan = planTrail(page, metrics);
        const rolled = plan.keys.flatMap((current, index) => {
            const before = plan.keys[index - 1];

            return before && current.roll !== before.roll ? [[before, current] as const] : [];
        });

        // 只有一段在翻：从右往左横穿的那一段，翻一整圈
        assert.equal(rolled.length, 1);

        const [before, after] = rolled[0] ?? [];

        assert.equal((after?.roll ?? 0) - (before?.roll ?? 0), 360);
        assert.ok((before?.x ?? 0) > (after?.x ?? 0));

        assert.ok(plan.branch.x + metrics.branchReach * plan.branch.scale >= page.width);
        assert.ok(
            plan.branch.from < plan.branch.to &&
                plan.branch.to < plan.branch.pick &&
                plan.branch.pick < plan.home,
        );
    });

    test(`${name}：樱桃枝滑进来时幽灵望着前方，滑到位之后眼神慢慢往右瞟，再滚动 0.12 屏时正好望向樱桃、眼睛开始放光；之后从道上飞到枝下才摘`, () => {
        const plan = planTrail(page, metrics);
        const { branch, lit } = plan;
        const cherry = {
            x: branch.x + metrics.cherry[0] * branch.scale,
            y: branch.y + metrics.cherry[1] * branch.scale,
        };

        // 枝滑进来的一段里望着前方
        for (let s = branch.from; s <= branch.to; s += 2) {
            assert.ok(facing(plan, s, [0, 0]), `s = ${Math.round(s)} 时没望着前方`);
        }

        // 滑到位之后眼神一路往右瞟，不往回转；再滚动 0.12 屏时注意到樱桃：正好望着它，眼睛开始放光
        let previous = 0;

        for (let s = branch.to; s <= lit[0]; s += 2) {
            const [x] = gazeOf(plan, s);

            assert.ok(x >= previous - 1e-9, `s = ${Math.round(s)} 时眼神往回转了`);
            previous = x;
        }

        assert.ok(Math.abs(lit[0] - branch.to - 0.12 * page.height) < 1e-6);
        assert.ok(looksAt(plan, lit[0], cherry));

        // 注意到樱桃时还在左边那条道上；之后一路往枝那边去，到了枝下才摘
        const lane = sampleTrail(plan, branch.from).x;
        const [arrive, into] = plan.keys.filter(({ s, y }) => s > lit[0] && y === branch.y);

        assert.ok(arrive && into);
        assert.ok(Math.abs(sampleTrail(plan, lit[0]).x - lane) < 1e-9 && Math.abs(arrive.x - lane) < 1e-9);

        const dashing = (arrive.s + into.s) / 2;
        const { x } = sampleTrail(plan, dashing);

        assert.ok(poseOf(plan, dashing) === 'spot' && x > lane && x < branch.x);
        assert.ok(into.s < branch.pick && poseOf(plan, branch.pick) === 'armful');
    });

    test(`${name}：位置随滚动连续变化，不跳`, () => {
        const plan = planTrail(page, metrics);
        let previous = sampleTrail(plan, 0);

        for (let s = 0.5; s <= page.end; s += 0.5) {
            const sample = sampleTrail(plan, s);

            assert.ok(Math.hypot(sample.x - previous.x, sample.y - previous.y) < 12, `s = ${s} 处跳了一下`);
            previous = sample;
        }
    });

    test(`${name}：眼神随滚动连续变化，不跳；视口很高、几段眼神挤在一起时也一样`, () => {
        for (const extra of [0, 300, 700]) {
            const plan = planTrail({ ...page, height: page.height + extra, end: page.end - extra }, metrics);
            let previous = gazeOf(plan, 0);

            for (let s = 0.5; s <= page.end - extra; s += 0.5) {
                const gaze = gazeOf(plan, s);
                const step = Math.hypot(gaze[0] - previous[0], gaze[1] - previous[1]);

                assert.ok(step < 0.05, `视口高 ${page.height + extra} 时 s = ${s} 处眼神跳了 ${step.toFixed(3)}`);
                previous = gaze;
            }
        }
    });

    test(`${name}：滚动时间线的关键帧从 0 排到 1，两帧之间按直线插值也贴着路线`, () => {
        const plan = planTrail(page, metrics);
        const position: FrameTrack<TrailState> = {
            values: ({ sample: { x, y } }) => [x, y],
            tolerance: [0.25, 0.25],
        };
        const [frames = []] = framesOf([position], art, plan, page.end);

        // 偏移不按先后排或超出 0 到 1 时，浏览器拒收整组关键帧
        assert.equal(frames[0]?.offset, 0);
        assert.equal(frames.at(-1)?.offset, 1);
        assert.ok(ascending(frames.map(({ offset }) => offset), true));

        // 每隔 1 px，按直线插值出的位置都离路线不到半个像素
        for (let s = 0; s <= page.end; s += 1) {
            const [x = 0, y = 0] = valuesAt(frames, s / page.end);
            const along = sampleTrail(plan, s);
            const off = Math.hypot(x - along.x, y - along.y);

            assert.ok(off < 0.5, `s = ${s} 处差了 ${off.toFixed(2)} px`);
        }
    });

    test(`${name}：换姿势时，按直线插值的每一处都有一张画完全不透明、最多两张同时显示，不透出背景`, () => {
        const plan = planTrail(page, metrics);
        const images = [
            ...Object.keys(art.poses).map((pose) => imageKey(pose)),
            ...Object.entries(art.morphs).flatMap(([pair, steps = []]) =>
                steps.map((_, index) => imageKey(pair, index)),
            ),
        ];
        const tracks = images.map((key): FrameTrack<TrailState> => ({
            values: ({ weights }) => [weights.get(key)?.[0] ?? 0],
            tolerance: [0.004],
        }));
        const frames = framesOf(tracks, art, plan, page.end);

        for (let s = 0; s <= page.end; s += 0.5) {
            const shown = frames.map((track) => valuesAt(track, s / page.end)[0] ?? 0);

            assert.ok(Math.max(...shown) > 0.99, `s = ${s} 处没有一张完全不透明`);
            assert.ok(shown.filter((value) => value > 0.01).length <= 2, `s = ${s} 处同时显示了三张`);
        }
    });
}

test('宽屏上扒着窗口右边时，跟着视口顺着窗口边往下滑；滑到窗口下部时边收手边接着往下飘，不在右下角停留', () => {
    const plan = planTrail(wide, metrics);
    const { from, to } = plan.hide;
    const paw = plan.paw;

    assert.ok(paw);

    const [pawOut, gripped, release, freed] = paw;
    const grip = sampleTrail(plan, from);

    // 滑的一段里，幽灵在视口里只缓缓往下挪：看上去是页面往上走，幽灵扒着窗口边往下溜
    for (let s = from; s <= release; s += 10) {
        const sample = sampleTrail(plan, s);
        const drift = sample.y - s - (grip.y - from);

        assert.ok(poseOf(plan, s) === 'hide' && Math.abs(sample.x - grip.x) < 1e-9, `s = ${s} 时离开了窗口边`);
        assert.ok(drift >= -1e-6 && drift <= 0.11 * (s - from) + 1e-6, `s = ${s} 时没跟住视口`);
    }

    // 到了窗口边才伸出小手，之后一直扒着；开始收手时小手还在窗口下边以上
    const paw0 = sampleTrail(plan, release).y + metrics.pawDrop * (grip.u / metrics.unit);

    assert.ok(pawOut === from && rampAt(paw, gripped) === 1 && rampAt(paw, release) === 1);
    assert.ok(paw0 < wide.window.bottom);

    // 收手与换回飘着的姿势同时进行，这一段里接着往下飘：在视口里不往上走，不像停在窗口边那样跟着页面上移
    let previous = Number.NEGATIVE_INFINITY;

    for (let s = release; s <= to; s += 2) {
        const y = sampleTrail(plan, s).y - s;

        assert.ok(y >= previous - 1e-9, `s = ${s} 时跟着页面往上走了`);
        previous = y;
    }

    assert.ok(freed === to && poseOf(plan, to) === 'float');
});

test('窗口右边空不下半个身子时，改成从窗口上边探出头；回不到右边时不横穿，照样落进满怀', () => {
    const plan = planTrail(narrow, metrics);

    assert.equal(plan.hide.mode, 'top');
    assert.equal(plan.paw, undefined);

    // 宽屏扒在窗口右边；一离开就换成飘着的姿势，不带着扒窗口的样子走
    const side = planTrail(wide, metrics);

    assert.equal(side.hide.mode, 'side');
    assert.equal(poseOf(side, (side.hide.from + side.hide.to) / 2), 'hide');
    assert.equal(poseOf(side, side.hide.to + 1), 'float');

    // 去掉所有空当：内容一块接一块
    const packed: TrailLayout = {
        ...wide,
        blocks: wide.blocks.map((block, index, all) => ({
            ...block,
            bottom: Math.max(block.bottom, all[index + 1]?.top ?? block.bottom),
        })),
    };
    const solid = planTrail(packed, metrics);

    assert.ok(solid.keys.every(({ roll }) => roll === 0));
    assert.equal(solid.beam, undefined);
    assert.equal(poseOf(solid, packed.end), 'armful');

    // 只留下满怀上方的空当：横穿过去就回不到右边的樱桃枝下
    const lone: TrailLayout = {
        ...packed,
        blocks: packed.blocks.map((block, index) =>
            block.bottom === wide.armful.top ? (wide.blocks[index] ?? block) : block,
        ),
    };

    assert.ok(planTrail(lone, metrics).keys.every(({ roll }) => roll === 0));
});

test('示意图上面的内容伸到服务器右边时，幽灵先顺着道降到示意图的高度，飘到机架身前的路上不从它前面经过', () => {
    const diagram = wide.blocks.findIndex(({ top, bottom }) => top <= wide.server.top && bottom >= wide.server.bottom);
    const top = wide.blocks[diagram]?.top ?? Number.NaN;

    // 宽屏上示意图上面是一段居中的标题；把它加宽到正文栏的右边，平板竖着拿时就是这样
    const stretched: TrailLayout = {
        ...wide,
        blocks: wide.blocks.map((block, index) =>
            index === diagram - 1 ? { ...block, right: wide.column.right } : block,
        ),
    };
    const header = stretched.blocks[diagram - 1];
    const plan = planTrail(stretched, metrics);

    assert.ok(header);

    // 从离开窗口到停在机架身前，每 10 px 取一个样
    for (let s = plan.hide.to; s < plan.lamps[1]; s += 10) {
        const { x, y, u } = sampleTrail(plan, s);

        assert.ok(!overlaps(bodyBox(x, y, u), header), `s = ${Math.round(s)} 时压住了示意图上面的内容`);
    }

    // 动身的那一帧：挡路时已经整个降到示意图上边以下，不挡路时还在它上面，径直飞过去
    const setOff = ({ keys, lamps: [, docked] }: TrailPlan): Box => {
        const { x = Number.NaN, y = Number.NaN, u = Number.NaN } = keys.findLast(({ s }) => s < docked) ?? {};

        return bodyBox(x, y, u);
    };

    assert.ok(setOff(plan).top >= top);
    assert.ok(setOff(planTrail(wide, metrics)).bottom < top);
});

test('枝下面的页面剩得不多时，收尾各步按同一个比例缩短，落定仍在滚到底之前', () => {
    // 视口高了 400，能滚的距离就少了 400
    const tall: TrailLayout = { ...wide, height: wide.height + 400, end: wide.end - 400 };
    const plan = planTrail(tall, metrics);
    const usual = planTrail(wide, metrics);
    const flight = ({ branch, home }: TrailPlan): number => home - branch.pick;

    assert.ok(plan.home <= tall.end);
    assert.equal(poseOf(plan, tall.end), 'armful');

    // 缩短了，但各帧仍按先后排开：没有挤成一帧接一帧
    assert.ok(flight(plan) < flight(usual));
    assert.ok(plan.keys.every((current, index) => index === 0 || current.s - (plan.keys[index - 1]?.s ?? 0) > 2));
});

test('空当：竖直方向上没有内容的一段，比幽灵高才算；交叠与包含的内容合在一起', () => {
    const blocks: Box[] = [
        { left: 0, top: 0, right: 10, bottom: 100 },
        { left: 0, top: 50, right: 10, bottom: 80 },
        { left: 20, top: 90, right: 30, bottom: 160 },
        { left: 0, top: 300, right: 10, bottom: 400 },
        { left: 0, top: 430, right: 10, bottom: 500 },
    ];

    assert.deepEqual(
        findGaps(blocks, 100).map(({ top, bottom }) => [top, bottom]),
        [[160, 300]],
    );
});

test('趋近与弹簧都与帧率无关：两个半帧与一整帧走到同一处，弹簧的速度也一样', () => {
    const whole = approach(0, 100, 1 / 30, 0.18);
    const halves = approach(approach(0, 100, 1 / 60, 0.18), 100, 1 / 60, 0.18);

    assert.ok(Math.abs(whole - halves) < 1e-9);

    const [value, speed] = spring(0, 0, 100, 1 / 30, 17, 0.78);
    const [halfValue, halfSpeed] = spring(0, 0, 100, 1 / 60, 17, 0.78);
    const [doubledValue, doubledSpeed] = spring(halfValue, halfSpeed, 100, 1 / 60, 17, 0.78);

    assert.ok(Math.abs(value - doubledValue) < 1e-9 && Math.abs(speed - doubledSpeed) < 1e-9);
});

/** 某个滚动距离上完整显示的姿势；正在换姿势时没有。 */
function poseOf(plan: TrailPlan, s: number): string | undefined {
    const { from, to } = poseAt(plan.poses, s);

    return from === to ? from : undefined;
}

/** 某个滚动距离上眼睛望向的方向，身体自身坐标。 */
function gazeOf(plan: TrailPlan, s: number): [number, number] {
    return gazeAt(plan.gaze, s, sampleTrail(plan, s));
}

/** 眼睛是否正望着身体自身坐标里的方向 `expected`，容许浮点误差。 */
function facing(plan: TrailPlan, s: number, expected: readonly [number, number]): boolean {
    const [x, y] = gazeOf(plan, s);

    return Math.abs(x - expected[0]) < 1e-9 && Math.abs(y - expected[1]) < 1e-9;
}

/** 眼睛是否正望着页面上的一点：眼神转回屏幕上的方向后，与身体正中到那一点的方向一致。 */
function looksAt(plan: TrailPlan, s: number, point: { x: number; y: number }): boolean {
    const sample = sampleTrail(plan, s);
    const [gx, gy] = gazeAt(plan.gaze, s, sample);
    const radians = (sample.roll * Math.PI) / 180;
    const x = gx * Math.cos(radians) - gy * Math.sin(radians);
    const y = gx * Math.sin(radians) + gy * Math.cos(radians);
    const dx = point.x - sample.x;
    const dy = point.y - sample.y;

    return Math.hypot(x, y) > 0.01 && Math.abs(x * dy - y * dx) < 1e-6 * Math.hypot(dx, dy) && x * dx + y * dy > 0;
}

/** 在 `from` 到 `to` 之间二分找出单调的 `value` 正好等于 `target` 的滚动距离。 */
function crossing(from: number, to: number, value: (s: number) => number, target: number): number {
    let low = from;
    let high = to;

    for (let round = 0; round < 60; round += 1) {
        const middle = (low + high) / 2;

        if (value(middle) < target) {
            low = middle;
        } else {
            high = middle;
        }
    }

    return high;
}

/** 一列数是否从小到大排好；`strict` 时不能相等。 */
function ascending(values: readonly number[], strict = false): boolean {
    return values.every((value, index) => {
        const before = values[index - 1] ?? Number.NEGATIVE_INFINITY;

        return strict ? value > before : value >= before;
    });
}

/** 浏览器在一条轨道的某个位置上按直线插值出的几个数。 */
function valuesAt(frames: readonly TrackFrame[], offset: number): number[] {
    let low = 0;
    let high = frames.length - 1;

    // 二分找到 offset 所在的两帧
    while (high - low > 1) {
        const middle = (low + high) >> 1;

        if ((frames[middle]?.offset ?? 0) <= offset) {
            low = middle;
        } else {
            high = middle;
        }
    }

    const from = frames[low];
    const to = frames[high];

    if (!from || !to || to.offset <= from.offset) {
        return [...(from?.values ?? [])];
    }

    const t = clamp((offset - from.offset) / (to.offset - from.offset), 0, 1);

    return from.values.map((value, index) => value + ((to.values[index] ?? value) - value) * t);
}

/** 静止的画里幽灵的位置与单位长度。 */
function anchored(box: Box, anchor: TrailMetrics['anchors']['hero']): { x: number; y: number; u: number } {
    const width = box.right - box.left;

    return {
        x: box.left + anchor.centre[0] * width,
        y: box.top + anchor.centre[1] * (box.bottom - box.top),
        u: width * anchor.unit,
    };
}

/** 位置与单位长度是否和期望的一样，容许浮点误差。 */
function near(actual: { x: number; y: number; u: number }, expected: { x: number; y: number; u: number }): boolean {
    return (
        Math.abs(actual.x - expected.x) < 1e-6 &&
        Math.abs(actual.y - expected.y) < 1e-6 &&
        Math.abs(actual.u - expected.u) < 1e-9
    );
}

/** 一块矩形的正中。 */
function centre({ left, top, right, bottom }: Box): { x: number; y: number } {
    return { x: (left + right) / 2, y: (top + bottom) / 2 };
}

/** 幽灵身体的范围，不算贴纸边以外的投影。 */
function bodyBox(x: number, y: number, u: number): Box {
    const width = ghostHalf.width * u;
    const height = ghostHalf.height * u;

    return { left: x - width, top: y - height, right: x + width, bottom: y + height };
}

/** 两块矩形是否交叠。 */
function overlaps(a: Box, b: Box): boolean {
    return a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;
}

/** 由简写的数组拼出一份布局，导航栏高 64。 */
function layout(value: {
    width: number;
    height: number;
    end: number;
    column: [number, number];
    hero: Rect;
    heading: Rect;
    headline: Rect;
    window: Rect;
    server: Rect;
    media: Rect[];
    reveal: Rect;
    revealTitle: Rect;
    armful: Rect;
    title: Rect;
    blocks: Rect[];
}): TrailLayout {
    return {
        width: value.width,
        height: value.height,
        header: 64,
        end: value.end,
        column: { left: value.column[0], right: value.column[1] },
        hero: box(value.hero),
        heading: box(value.heading),
        headline: box(value.headline),
        window: box(value.window),
        server: box(value.server),
        media: value.media.map(box),
        reveal: box(value.reveal),
        revealTitle: box(value.revealTitle),
        armful: box(value.armful),
        title: box(value.title),
        blocks: value.blocks.map(box),
    };
}

/** 一块矩形的简写：左、上、右、下。 */
type Rect = [number, number, number, number];

/** 简写换成矩形。 */
function box([left, top, right, bottom]: Rect): Box {
    return { left, top, right, bottom };
}
