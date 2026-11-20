import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
    createIconKit,
    type GhostOptions,
    type GhostPose,
    type Point,
    readIconScripts,
    type ServerOptions,
} from './kit.ts';
import { compactNumbers, renderArt, scopeIds, sizeArt } from './markup.ts';
import { ghostPresets } from './parts.ts';
import { createSiteArt, frontStickers } from './scenes.ts';

/*
 * 首页与 404 页上那几幅画的自测：id 的作用域、数字收短、修圆滤镜放宽后的轮廓、拆层的次序与零件的坐标换算。
 *
 * 在 `website/` 下运行：`node --test src/art/art.test.ts`
 */

const scripts = fileURLToPath(new URL('../../../scripts/make-icon', import.meta.url));
const kit = createIconKit(readIconScripts(scripts));

test('id 换成带前缀的序号，引用跟着换；重复定义与悬空引用都报错', () => {
    const markup = '<mask id="a"><rect fill="#fff"/></mask><g mask="url(#a)"><use href="#a"/></g>';

    assert.equal(
        scopeIds(markup, 'hero0-'),
        '<mask id="hero0-0"><rect fill="#fff"/></mask><g mask="url(#hero0-0)"><use href="#hero0-0"/></g>',
    );

    assert.throws(() => scopeIds('<g id="a"/><g id="a"/>', 'x-'));
    assert.throws(() => scopeIds('<g fill="url(#b)"/>', 'x-'));
});

test('数字收短到六位有效数字，极小的值写成 0，颜色与引用原样保留', () => {
    const markup = '<path id="a1.5" d="M1.23456789,0.0000004L10e2,3" fill="#123456" stroke="url(#a1.5)"/>';

    assert.equal(
        compactNumbers(markup),
        '<path id="a1.5" d="M1.23457,0L1000,3" fill="#123456" stroke="url(#a1.5)"/>',
    );
});

test('修圆滤镜的边按显示宽度放宽，透明度 0.5 处的轮廓不动', () => {
    const slope = 46;
    const markup = `<feFuncA type="linear" slope="${slope}" intercept="${-(slope - 1) / 2}"/>`;
    const art = sizeArt({ viewBox: [0, 0, 1024, 1024], layers: [{ name: 'shape', markup }] }, 128);
    const transfer = /slope="([^"]+)" intercept="([^"]+)"/.exec(art.layers[0]?.markup ?? '');
    const [, softened = '', intercept = ''] = transfer ?? [];
    const alpha = (value: number): number => Number(softened) * value + Number(intercept);

    // 0.6 px 在 1024 单位宽、显示 128 px 的画面里是 4.8 个单位：过渡带宽 4.8 倍，中点不动
    const width = (0.6 * 1024) / 128;

    assert.ok(Math.abs(alpha(0.5) - 0.5) < 1e-9);
    assert.ok(Math.abs(alpha(0.5 + width / slope / 2) - 1) < 1e-9);
});

test('探身拆成底板、两组的投影、贴纸边与成品，身前另有落着影子的机身，显形另有光束与亮着的指示灯，每层自带用到的定义', () => {
    const art = createSiteArt(kit);

    assert.deepEqual(
        art.hero.layers.map(({ name }) => name),
        ['plate', 'ghost-shadow', 'rack-shadow', 'ghost-edge', 'rack-edge', 'ghost', 'rack'],
    );

    // 身前：落着幽灵影子的机身盖在机架的成品上、与幽灵同组，页面藏起幽灵时影子跟着藏起
    assert.deepEqual(
        art.server.layers.map(({ name, group }) => [name, group]),
        [
            ['rack-shadow', 'rack'], ['ghost-shadow', 'ghost'], ['rack-edge', 'rack'], ['ghost-edge', 'ghost'],
            ['rack', 'rack'], ['shade', 'ghost'], ['ghost', 'ghost'],
        ],
    );

    // 显形：光束垫在最下面，亮着指示灯的机架盖在机架的成品上，页面按层名让这两层随幽灵的停靠显隐
    assert.deepEqual(
        art.reveal.layers.map(({ name }) => name),
        ['beam', 'server-shadow', 'ghost-shadow', 'server-edge', 'ghost-edge', 'server', 'lamps', 'ghost'],
    );

    // 各层单独收进页面：缺了定义或同一层里定义了两次，renderArt 都会报错
    for (const piece of Object.values(art)) {
        assert.doesNotThrow(() => renderArt(piece, 'test'));
    }
});

test('示意图里的身前是图标的左右镜像：身体、小手、眼睛、指示灯与机身上的影子都翻到另一边，三台机架都有盘位槽', () => {
    const { stickers } = kit.capture('front', 'default', false);
    const original = stickers.find(({ kind }) => kind === 'ghostSticker')?.options as GhostOptions;
    const servers = stickers.filter(({ kind }) => kind === 'serverSticker').map(({ options }) => options as ServerOptions);
    const { ghost, bare, shaded } = frontStickers(kit);
    const mirrored = ([x, y]: Point): Point => [kit.grid - x, y];
    const same = ([x, y]: Point, [expectedX, expectedY]: Point): boolean => Math.hypot(x - expectedX, y - expectedY) < 1e-6;

    // 身体：自身坐标里脊线两侧对称的点，落在画面上互为镜像
    for (const [u, v] of [[0, 0], [150, 300], [-220, 560]] as const) {
        assert.ok(same(ghost.pose.place(-u, v), mirrored(original.pose.place(u, v))));
        assert.equal(ghost.pose.degrees(v), -original.pose.degrees(v));
    }

    // 小手与眼睛
    assert.deepEqual(ghost.hands?.map(({ line }) => line), original.hands?.map(({ line }) => line.map(mirrored)));
    assert.deepEqual(ghost.eyes.map(({ u }) => u), original.eyes.map(({ u }) => -u));
    assert.ok(ghost.eyes.every(({ tilt }) => tilt === -kit.eyeTilt));

    // 机架：指示灯翻到左边，三台的盘位槽都在最上面那台的槽翻过去的位置
    const top = servers.find(({ slot }) => slot);
    const racks = bare.map(({ options }) => options as ServerOptions);

    assert.equal(racks.length, 3);
    assert.deepEqual(racks.map(({ leds }) => leds), servers.map(({ leds }) => leds.map((x) => kit.grid - x)));
    assert.ok(top?.slot && racks.every(({ slot }) => slot?.x === kit.grid - (top.slot?.x ?? 0) - (top.slot?.width ?? 0)));

    // 落着影子的那一组：影子往左挪开，不带影子的那一组没有影子
    const offsets = (group: typeof shaded): number[] =>
        group.flatMap(({ options }) => ((options as ServerOptions | undefined)?.shadows ?? []).map(({ dx }) => dx));

    assert.deepEqual(offsets(shaded), servers.flatMap(({ shadows = [] }) => shadows.map(({ dx }) => -dx)));
    assert.equal(offsets(shaded).length, 3);
    assert.deepEqual(offsets(bare), []);
});

test('小手换算到幽灵自身坐标后，按原来的姿势放回去仍在原处', () => {
    const ghost = kit.capture('rise', 'default', false).stickers.find(({ kind }) => kind === 'ghostSticker');
    const { pose, hands = [] } = ghost?.options as { pose: GhostPose; hands?: { line: readonly Point[] }[] };
    const { raised } = ghostPresets(kit).hands;

    assert.equal(raised.length, hands.length);

    // 脊线按 2 个单位一步搜索，放回去的误差在一个单位以内
    raised.forEach((limb, index) => {
        limb.points.forEach(([u, v], point) => {
            const [x, y] = pose.place(u, v);
            const [expectedX = Number.NaN, expectedY = Number.NaN] = hands[index]?.line[point] ?? [];

            assert.ok(Math.hypot(x - expectedX, y - expectedY) < 1);
        });
    });
});
