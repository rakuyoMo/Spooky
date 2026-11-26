import type { CommitData, DemoState, RepoData } from './model.ts';
import { headBranch, reachableFrom } from './model.ts';

/**
 * 快捷操作的匹配与排序：视图、分支、远端分支与标签按名字打分，文件按文件名再按路径打分，
 * 提交按提交信息或哈希查找。
 */

/** 结果的种类，排在前面的种类整组排在前面。 */
export const quickKinds = ['navigation', 'branch', 'remoteBranch', 'tag', 'file', 'commit'] as const;

/** 结果的种类。 */
export type QuickKind = (typeof quickKinds)[number];

/** 一条结果：`id` 是回车时要去的视图、引用、路径或提交。 */
export interface QuickItem {
    kind: QuickKind;
    id: string;
    title: string;
    detail: string | null;
}

/** 演示窗口里能去的视图与它们的名字。 */
export type QuickView = 'working' | 'history' | 'stashes';

/** 按提交信息查找时最多列出的提交数。 */
const commitLimit = 100;

/** 词的分隔符：紧跟在它后面的位置算词首。 */
const separators = new Set([' ', '/', '-', '_', '.', ':', '@', '(', '[']);

/** 像提交哈希的输入：5 到 64 位十六进制。 */
const hashPattern = /^[0-9a-fA-F]{5,64}$/;

/**
 * 一个候选与输入的匹配分数，不匹配时为 `null`。
 *
 * 完全相同最高，其次是前缀、连续出现（从词首开始的高一档）、按顺序分散出现；输入为空时都算匹配。
 */
export function quickScore(candidate: string, query: string): number | null {
    const needle = [...fold(query)];

    if (needle.length === 0) {
        return 0;
    }

    const haystack = [...fold(candidate)];
    const extra = haystack.length - needle.length;

    if (extra < 0) {
        return null;
    }

    const hay = haystack.join('');
    const need = needle.join('');

    if (hay === need) {
        return 4000;
    }

    if (hay.startsWith(need)) {
        return 3000 - Math.min(extra, 499);
    }

    const found = hay.indexOf(need);

    if (found >= 0) {
        const offset = [...hay.slice(0, found)].length;
        const wordStart = separators.has(haystack[offset - 1] ?? '');

        return (wordStart ? 2500 : 2000) - Math.min(offset + extra, 499);
    }

    return scatteredScore(haystack, needle);
}

/** 文件先按文件名打分，文件名不匹配时按整个路径打分并降一档。 */
export function fileScore(path: string, query: string): number | null {
    const name = path.split('/').pop() ?? path;
    const byName = quickScore(name, query);

    if (byName !== null) {
        return byName;
    }

    const byPath = quickScore(path, query);

    return byPath === null ? null : Math.max(byPath - 2000, 1);
}

/**
 * 快捷操作框里的结果。
 *
 * 没有输入时只列视图与本地分支；有输入时再列远端分支、标签、文件与提交。
 * `paths` 是 HEAD 里的全部文件，还没取来时是 `null`；`viewTitles` 是三个视图的名字。
 */
export function quickResults(
    state: DemoState,
    data: RepoData,
    query: string,
    paths: readonly string[] | null,
    viewTitles: Record<QuickView, string>,
): QuickItem[] {
    const head = headBranch(state);
    const text = query.trim();

    const views: QuickItem[] = (['working', 'history', 'stashes'] as const).map((view) => ({
        kind: 'navigation',
        id: view,
        title: viewTitles[view],
        detail: null,
    }));

    // HEAD 所在的分支排在其它本地分支前面
    const locals = [head, ...state.branches.filter((branch) => branch.name !== head.name)].map((branch) =>
        reference('branch', `refs/heads/${branch.name}`, branch.name),
    );

    const remotes = state.remoteBranches.map((remote) =>
        reference('remoteBranch', `refs/remotes/${remote.name}`, remote.name, remote.name.split('/')[0] ?? null),
    );

    const tags = data.tags.map((tag) => reference('tag', `refs/tags/${tag.name}`, tag.name));
    const candidates = text === '' ? [...views, ...locals] : [...views, ...locals, ...remotes, ...tags];

    const ranked = candidates
        .map((item, index) => ({ item, index, score: quickScore(item.title, text) }))
        .filter((entry): entry is { item: QuickItem; index: number; score: number } => entry.score !== null)
        .sort((a, b) => {
            const kind = quickKinds.indexOf(a.item.kind) - quickKinds.indexOf(b.item.kind);

            return kind !== 0 ? kind : a.score !== b.score ? b.score - a.score : a.index - b.index;
        })
        .map((entry) => entry.item);

    if (text === '') {
        return ranked;
    }

    return [...ranked, ...fileResults(paths ?? [], text), ...commitResults(state, text)];
}

// MARK: - Private

/** 引用一类的结果。 */
function reference(kind: QuickKind, id: string, title: string, detail: string | null = null): QuickItem {
    return { kind, id, title, detail };
}

/** 匹配的文件：分数高的在前，同分按路径排序。 */
function fileResults(paths: readonly string[], query: string): QuickItem[] {
    return paths
        .map((path) => ({ path, score: fileScore(path, query) }))
        .filter((entry): entry is { path: string; score: number } => entry.score !== null)
        .sort((a, b) => b.score - a.score || a.path.localeCompare(b.path, 'en', { numeric: true }))
        .map(({ path }) => ({
            kind: 'file' as const,
            id: path,
            title: path.split('/').pop() ?? path,
            detail: path,
        }));
}

/**
 * 匹配的提交：像哈希的输入按哈希前缀找一个提交，其余按提交信息在 HEAD 能到达的提交里找。
 */
function commitResults(state: DemoState, query: string): QuickItem[] {
    const item = (commit: CommitData): QuickItem => ({
        kind: 'commit',
        id: commit.hash,
        title: commit.message.split('\n', 1)[0] ?? '',
        detail: commit.hash.slice(0, 8),
    });

    if (hashPattern.test(query)) {
        const found = state.commits.find((commit) => commit.hash.startsWith(query.toLowerCase()));

        return found ? [item(found)] : [];
    }

    const reachable = reachableFrom(state.commits, headBranch(state).hash);

    const needle = fold(query);

    return state.commits
        .filter((commit) => reachable.has(commit.hash) && fold(commit.message).includes(needle))
        .slice(0, commitLimit)
        .map(item);
}

/** 按顺序分散出现的匹配：相邻、词首的字符加分，跳过的字符扣分，分数落在 1000–1999。 */
function scatteredScore(haystack: readonly string[], needle: readonly string[]): number | null {
    let score = 1000;
    let position = 0;
    let previous: number | null = null;

    for (const character of needle) {
        const index = haystack.indexOf(character, position);

        if (index < 0) {
            return null;
        }

        if (previous !== null && index === previous + 1) {
            score += 15;
        } else if (index === 0 || separators.has(haystack[index - 1] ?? '')) {
            score += 10;
        }

        // 每段跳过的字符最多扣 10 分，长路径里的远距离命中不会一扣到底
        score -= Math.min(index - position, 10);
        previous = index;
        position = index + 1;
    }

    return Math.min(Math.max(score - Math.trunc((haystack.length - needle.length) / 4), 1000), 1999);
}

/** 不分大小写与变音符号。 */
function fold(text: string): string {
    return text.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
}
