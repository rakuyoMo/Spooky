import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
    approach,
    type Box,
    findGaps,
    ghostHalf,
    planTrail,
    sampleTrail,
    type TrailLayout,
    type TrailMetrics,
} from './path.ts';

/*
 * 首页小幽灵路线的自测：起点与终点和静止的画重合，停靠的时机，横穿的空当，不在正文后面停留，收尾各步的先后，以及插值的连续。
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
};

/** 宽 1440、高 900 的视口里量出的首页布局。 */
const wide = layout({
    width: 1440,
    height: 900,
    end: 5698,
    column: [184, 1256],
    hero: [656, 160, 784, 288],
    heading: [416, 308, 1024, 511],
    window: [80, 700, 1360, 1500],
    server: [959, 2031, 1119, 2179],
    reveal: [184, 4410, 363, 4581],
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
    window: [16, 593, 374, 1902],
    server: [115, 3074, 275, 3222],
    reveal: [20, 5827, 199, 5998],
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
        assert.ok(near(start, hero) && start.pose === 'rise');

        // 终点：落在满怀那幅画里，停稳不飘
        assert.ok(near(finish, armful) && finish.pose === 'armful' && finish.bob === 0);
        assert.ok(plan.home <= page.end, '滚到底之前就已落定');

        // 关键帧按滚动的距离逐个变大，路线只由滚动的距离决定
        assert.ok(plan.keys.every((current, index) => index === 0 || current.s > (plan.keys[index - 1]?.s ?? 0)));
    });

    test(`${name}：机架身前的位置在视口高度 25% 到 75% 之间时，幽灵已停在那里抬着手；影子落在机架上的一段就是这个姿势的一段，之后平着飘回右边`, () => {
        const plan = planTrail(page, metrics);
        const server = anchored(page.server, metrics.anchors.server);
        const from = server.y - 0.75 * page.height;
        const to = server.y - 0.25 * page.height;
        const [docked, away] = plan.server;

        for (let s = from; s <= to; s += 10) {
            const sample = sampleTrail(plan, s);

            assert.ok(near(sample, server) && sample.pose === 'front', `s = ${s} 时还没停稳`);
        }

        assert.ok(docked <= from && away >= to);

        // 来的路上与离开之后都是飘着的姿势：机架上没有幽灵时不留影子
        assert.equal(sampleTrail(plan, docked - 1).pose, 'left');
        assert.equal(sampleTrail(plan, docked).pose, 'front');
        assert.equal(sampleTrail(plan, away - 1).pose, 'front');
        assert.equal(sampleTrail(plan, away).pose, 'right');

        // 离开的路上，身体还没出这幅画的右边时一直在画的下边以上：不从下面的标题后面经过
        const leave = plan.keys.find(({ s }) => s > away);

        assert.ok(leave && leave.x > page.server.right);

        for (let s = away; s <= leave.s; s += 10) {
            const { x, y, u } = sampleTrail(plan, s);
            const clear = bodyBox(x, y, u).left >= page.server.right || y < page.server.bottom;

            assert.ok(clear, `s = ${Math.round(s)} 时落到了画的下边以下`);
        }
    });

    test(`${name}：显形的幽灵在视口高度 30% 到 70% 之间时停在光里，这一段里灯与光束亮着，之后平着飘回左边`, () => {
        const plan = planTrail(page, metrics);
        const docked = anchored(page.reveal, metrics.anchors.reveal);
        const [lit = Number.NaN, dark = Number.NaN] = plan.reveal ?? [];

        for (let s = docked.y - 0.7 * page.height; s < docked.y - 0.3 * page.height; s += 10) {
            const sample = sampleTrail(plan, s);

            assert.ok(near(sample, docked) && sample.pose === 'reveal', `s = ${s} 时不在光里`);
            assert.ok(s >= lit && s <= dark, `s = ${s} 时灯没亮`);
        }

        // 灯灭之后幽灵往左飘：高度不变，不从下面的服务器前面经过，最后整个在这幅画的左边
        const away = sampleTrail(plan, dark + 0.12 * page.height);

        assert.ok(Math.abs(away.y - docked.y) < 1 && away.pose === 'left');
        assert.ok(away.x + ghostHalf.width * away.u <= page.reveal.left);
    });

    test(`${name}：飘在道上、横穿空当与够樱桃时，身体不压在文字后面`, () => {
        const plan = planTrail(page, metrics);
        const moving = new Set(['float', 'left', 'right', 'spot', 'reach']);

        // 演示窗口不透明，幽灵顺着它的边滑下去时整个藏在后面；显形那幅画是幽灵要停进去的地方：两块都不算文字
        const text = page.blocks.filter(({ top }) => top !== page.window.top && top !== page.reveal.top);

        for (const current of plan.keys.filter(({ pose }) => moving.has(pose))) {
            const body = bodyBox(current.x, current.y, current.u);
            const hit = text.find((block) => overlaps(body, block));

            assert.equal(hit, undefined, `s = ${Math.round(current.s)} 的 ${current.pose} 压住了正文`);
        }

        // 离开服务器之后到摘下樱桃，两帧之间的路上也不压住：换道只走空当
        const leave = plan.keys.find(({ s, hold }) => s > plan.server[0] && !hold);

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

    test(`${name}：樱桃枝先伸进来，幽灵到了枝所在的一层先望着它，再眼睛放光，然后才横穿过去`, () => {
        const plan = planTrail(page, metrics);

        // 停在枝所在那一层、还没动身的几帧：到了、眼睛放光、动身
        const waiting = plan.keys.filter(({ y, x, hold }) => hold && y === plan.branch.y && x !== plan.branch.x);
        const [arrive, spot, leave] = waiting;

        assert.equal(waiting.length, 3);
        assert.ok(arrive && spot && leave);

        // 枝伸进来的那一段在幽灵到之前就结束了
        assert.ok(plan.branch.to <= arrive.s);

        // 先望着枝，再眼睛放光，这两段都留在原处
        const looking = sampleTrail(plan, (arrive.s + spot.s) / 2);
        const lit = sampleTrail(plan, (spot.s + leave.s) / 2);

        assert.ok(looking.pose === 'right' && looking.x === arrive.x);
        assert.ok(lit.pose === 'spot' && lit.x === arrive.x);

        // 动身之后一路往枝那边去，眼睛一直亮着，到了才摘
        const dashing = sampleTrail(plan, leave.s + 0.15 * page.height);

        assert.ok(dashing.pose === 'spot' && dashing.x > arrive.x && dashing.x < plan.branch.x);
        assert.ok(leave.s < plan.branch.pick);
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
}

test('窗口右边空不下半个身子时，改成从窗口上边探出头；回不到右边时不横穿，照样落进满怀', () => {
    const plan = planTrail(narrow, metrics);

    assert.equal(plan.hide.mode, 'top');

    // 宽屏扒在窗口右边；一离开就换成飘着的姿势，不带着扒窗口的样子走
    const side = planTrail(wide, metrics);

    assert.equal(side.hide.mode, 'side');
    assert.equal(sampleTrail(side, (side.hide.from + side.hide.to) / 2).pose, 'hide');
    assert.equal(sampleTrail(side, side.hide.to + 1).pose, 'float');

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
    assert.equal(solid.reveal, undefined);
    assert.equal(sampleTrail(solid, packed.end).pose, 'armful');

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
    for (let s = plan.hide.to; s < plan.server[0]; s += 10) {
        const { x, y, u } = sampleTrail(plan, s);

        assert.ok(!overlaps(bodyBox(x, y, u), header), `s = ${Math.round(s)} 时压住了示意图上面的内容`);
    }

    // 动身的那一帧：挡路时已经整个降到示意图上边以下，不挡路时还在它上面，径直飞过去
    const setOff = ({ keys, server: [docked] }: typeof plan): Box => {
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
    const flight = ({ branch, home }: typeof plan): number => home - branch.pick;

    assert.ok(plan.home <= tall.end);
    assert.equal(sampleTrail(plan, tall.end).pose, 'armful');

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

test('趋近与帧率无关：两个半帧与一整帧走到同一处', () => {
    const whole = approach(0, 100, 1 / 30, 0.18);
    const halves = approach(approach(0, 100, 1 / 60, 0.18), 100, 1 / 60, 0.18);

    assert.ok(Math.abs(whole - halves) < 1e-9);
});

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
    window: Rect;
    server: Rect;
    reveal: Rect;
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
        window: box(value.window),
        server: box(value.server),
        reveal: box(value.reveal),
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
