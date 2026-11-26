import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { columnCount, graphRows } from './graph.ts';
import { inlineRanges } from './inline.ts';
import type { DemoState, RepoData } from './model.ts';
import {
    canCommit,
    commit,
    createState,
    fileBadges,
    fileCheck,
    headBranch,
    historyCommits,
    multilineParts,
    push,
    remainingCharacters,
    selectFile,
    selectLine,
    selectRef,
    selectView,
    sideDiff,
    stageSelection,
    toggleFile,
    unpushedCommits,
} from './model.ts';
import { quickScore } from './quick.ts';
import { demoKeys, demoStrings, format } from './text.ts';

/*
 * 演示窗口里纯规则部分的自测：暂存、提交与推送的 Git 语义，快捷操作的匹配，提交图，行内差异与文案。
 *
 * 在 `website/` 下运行：`node --test src/demo/demo.test.ts`
 */

const repoUrl = new URL('./data/repo.json', import.meta.url);
const data = JSON.parse(readFileSync(repoUrl, 'utf8')) as RepoData;

test('从分支进入历史时显示全部提交，后退可以恢复分支范围', () => {
    const ref = 'refs/heads/feature/units-toggle';
    const branch = selectRef(createState(data), data, ref);
    const branchCommits = historyCommits(branch, data);

    // 直接打开历史时，分支之外的提交也能访问，仍在列表里的选中项继续保留
    const all = selectView(branch, data, 'history');

    assert.equal(all.historyRef, null);
    assert.equal(historyCommits(all, data).length, all.commits.length);
    assert.ok(all.commits.length > branchCommits.length);
    assert.equal(all.selectedCommit, branch.selectedCommit);

    // 后退带回该分支之前看到的提交列表
    const restored = selectView(all, data, 'history', branch.historyRef);

    assert.deepEqual(historyCommits(restored, data), branchCommits);
});

test('按行暂存：选中的行进入索引，文件变成半选，再点勾选框暂存或取消整个文件', () => {
    const path = 'src/readings.ts';
    const state = stageFirstChange(selectFile(createState(data), path), path);
    const file = state.files.find((candidate) => candidate.path === path);

    assert.ok(file);
    assert.equal(fileCheck(file), 'mixed');
    assert.deepEqual(fileBadges(file), { staged: 'M', unstaged: 'M' });

    // 半选时点勾选框暂存全部，全选时再点取消全部
    const all = toggleFile(state, path);
    const none = toggleFile(all, path);

    assert.equal(checkOf(all, path), 'on');
    assert.equal(checkOf(none, path), 'off');
});

test('未跟踪的文件：没有暂存时两侧都写未跟踪，暂存一部分后已暂存一侧是 A', () => {
    const untracked = data.files.find((file) => file.untracked);

    assert.ok(untracked);

    const before = createState(data).files.find((file) => file.path === untracked.path);

    assert.ok(before);
    assert.deepEqual(fileBadges(before), { staged: null, unstaged: '?' });

    // 只暂存第一行之后，文件在索引里是新增，工作区里还有没暂存的改动
    const state = stageFirstChange(selectFile(createState(data), untracked.path), untracked.path);
    const after = state.files.find((file) => file.path === untracked.path);

    assert.ok(after);
    assert.deepEqual(fileBadges(after), { staged: 'A', unstaged: 'M' });
});

test('提交与推送：已暂存的改动离开工作区，分支多领先一个；推送后领先清零，上游指向新提交', () => {
    const start = createState(data);
    const ahead = headBranch(start, data).ahead;
    const fullyStaged = start.files.filter((file) => fileCheck(file) === 'on').length;

    // 没有标题时不能提交
    assert.equal(canCommit({ ...start, subject: '  ' }), false);
    assert.equal(canCommit(start), true);

    const committed = commit(start, data, new Date('2026-11-19T10:00:00Z'));
    const branch = headBranch(committed, data);

    assert.equal(committed.files.length, start.files.length - fullyStaged);
    assert.equal(branch.ahead, ahead + 1);
    assert.match(branch.hash, /^[0-9a-f]{40}$/);
    assert.equal(committed.commits[0]?.hash, branch.hash);
    assert.equal(unpushedCommits(committed, data).size, ahead + 1);

    const pushed = push(committed, data);
    const upstream = pushed.remoteBranches.find((remote) => remote.name === branch.upstream);

    assert.equal(headBranch(pushed, data).ahead, 0);
    assert.equal(upstream?.hash, branch.hash);
    assert.equal(unpushedCommits(pushed, data).size, 0);
});

test('剩余字数：两个框都空时不显示，标题去掉首尾空白再计', () => {
    assert.equal(remainingCharacters('', ''), null);
    assert.equal(remainingCharacters('  ab  ', ''), 48);
    assert.equal(remainingCharacters('', 'body'), 50);
});

test('快捷操作的匹配：完全相同 > 前缀 > 词首连续 > 中间连续 > 分散，对不上时没有结果', () => {
    const exact = quickScore('main', 'main');
    const prefix = quickScore('dark-mode', 'dark');
    const wordStart = quickScore('feature/dark-mode', 'dark');
    const inside = quickScore('feature/undark', 'dark');
    const scattered = quickScore('feature/do-a-rake-k', 'dark');

    const scores = [exact, prefix, wordStart, inside, scattered];

    // 每一种都能匹配上，分数逐个变低
    assert.ok(scores.every((score) => score !== null));
    assert.deepEqual(
        [...scores].sort((a, b) => (b ?? 0) - (a ?? 0)),
        scores,
    );
    assert.equal(new Set(scores).size, scores.length);
    assert.equal(quickScore('main', 'dark'), null);
});

test('提交图：每个提交一行，合并进来的分支多占一列', () => {
    const rows = graphRows(data.commits);
    const widest = Math.max(...rows.map((row) => columnCount(row)));

    assert.equal(rows.length, data.commits.length);
    assert.ok(widest >= 2);
});

test('行内差异：成对的删除行与新增行只标出改动的词，整行重写时不标', () => {
    const ranges = inlineRanges([
        { kind: 'd', text: 'const limit = 10;' },
        { kind: 'a', text: 'const limit = 25;' },
    ]);

    assert.deepEqual(ranges.get(0), [[14, 16]]);
    assert.deepEqual(ranges.get(1), [[14, 16]]);

    const rewritten = inlineRanges([
        { kind: 'd', text: 'alpha' },
        { kind: 'a', text: 'omega bravo' },
    ]);

    assert.equal(rewritten.size, 0);
});

test('文案：任何一种语言缺键时报错并列出缺的键，格式说明符按 App 的写法代入', () => {
    const full = Object.fromEntries(demoKeys.map((key) => [key, key]));
    const { [demoKeys[0]]: _dropped, ...partial } = full;

    assert.throws(
        () => demoStrings({ en: full, 'zh-cn': partial }, 'en'),
        (error: unknown) => error instanceof Error && error.message.includes(demoKeys[0]),
    );
    assert.equal(demoStrings({ en: full }, 'en')[demoKeys[0]], demoKeys[0]);

    assert.equal(format('%@ (%ld Commits)', ['History', 66]), 'History (66 Commits)');
    assert.equal(format('%2$@ → %1$@', ['a', 'b']), 'b → a');
    assert.equal(format('100%%', []), '100%');
});

test('标题框粘贴多行文字：开头的空行之后第一行是标题，其余去掉首尾空行后另起一行接到正文后面', () => {
    assert.deepEqual(multilineParts('\n\nSubject\r\n\r\nFirst\rSecond\u2028Third\n\n', ''), {
        subject: 'Subject',
        body: 'First\nSecond\nThird',
    });

    // 已有正文时另起一行接在后面
    assert.deepEqual(multilineParts('Subject\nMore', 'Existing'), {
        subject: 'Subject',
        body: 'Existing\nMore',
    });

    // 第一行之后只有空行、或者全是空行时，正文不变
    assert.deepEqual(multilineParts('Subject\n\n', 'Existing'), {
        subject: 'Subject',
        body: 'Existing',
    });
    assert.deepEqual(multilineParts('\n\n', 'Existing'), {
        subject: '',
        body: 'Existing',
    });
});

// MARK: - Helpers

/** 在选中的文件里点第一个改动行的行号，再按 Stage Lines。 */
function stageFirstChange(state: DemoState, path: string): DemoState {
    const file = state.files.find((candidate) => candidate.path === path);
    const hunk = file ? sideDiff(file, 'unstaged').hunks[0] : undefined;
    const row = hunk?.rows.find((candidate) => candidate.kind !== 'c');

    assert.ok(row);

    return stageSelection(selectLine({ ...state, side: 'unstaged' }, 0, row.op, false));
}

/** 一个文件的勾选框状态。 */
function checkOf(state: DemoState, path: string): ReturnType<typeof fileCheck> | undefined {
    const file = state.files.find((candidate) => candidate.path === path);

    return file ? fileCheck(file) : undefined;
}
