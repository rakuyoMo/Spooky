/**
 * 演示窗口的数据与规则：工作区的暂存、提交、推送与历史，都是不碰 DOM 的纯函数。
 *
 * 构建时与浏览器里共用；`demo.test.ts` 用 Node 直接运行它们。
 */

/** 一行改动：`c` 上下文、`d` 删除、`a` 新增；第二项是这一行是否已经暂存。 */
export type OpData = [kind: 'c' | 'd' | 'a', staged: 0 | 1, text: string];

/** 提交的作者或提交者：名字、邮箱、Unix 时间与 `±hhmm` 时区。 */
export type Person = [name: string, email: string, time: number, zone: string];

/** 导出的工作区文件。 */
export interface FileData {
    path: string;
    isNew: boolean;
    untracked: boolean;
    ops: OpData[];
}

/** 导出的提交或储藏。 */
export interface CommitData {
    hash: string;
    parents: string[];
    tree: string;
    author: Person;
    committer: Person;
    message: string;
}

/** 一个提交里的一个文件：补丁只留块，与 `git diff -U7` 的块原文相同。 */
export interface ChangeData {
    path: string;
    status: string;
    oldPath?: string;
    binary?: boolean;
    patch: string;
}

/** 本地分支，`upstream` 是跟踪的远端分支。 */
export interface BranchData {
    name: string;
    hash: string;
    upstream: string | null;
    ahead: number;
    behind: number;
}

/** 远端分支或标签。 */
export interface RefData {
    name: string;
    hash: string;
}

/** 从示例仓库导出的全部数据。 */
export interface RepoData {
    host: string;
    repository: string;

    /** 提交标题框里保存着的草稿。 */
    draft: string;

    identity: { name: string; email: string };
    head: string;
    branches: BranchData[];
    remoteBranches: RefData[];
    remoteHead: string;
    tags: RefData[];
    files: FileData[];
    commits: CommitData[];
    stash: CommitData;
}

/** 工作区的一行改动。 */
export interface Op {
    kind: 'c' | 'd' | 'a';
    staged: boolean;
    text: string;
}

/** 工作区的一个文件：`isNew` 表示 HEAD 里还没有它。 */
export interface WorkFile {
    path: string;
    isNew: boolean;
    ops: Op[];
}

/** Diff 的两侧：已暂存是 HEAD → 索引，未暂存是索引 → 工作区。 */
export type Side = 'staged' | 'unstaged';

/** 主视图。 */
export type View = 'working' | 'history' | 'stashes';

/** 引导的三步。 */
export type Step = 'stage' | 'commit' | 'push';

/** 演示窗口的全部状态。 */
export interface DemoState {
    view: View;
    files: WorkFile[];
    selectedPath: string | null;
    side: Side;

    /** 行号选区：所在的块与选中的改动行（文件里的操作序号）。 */
    selection: { hunk: number; ops: number[]; anchor: number } | null;

    subject: string;
    body: string;
    commits: CommitData[];

    /** 演示里新建的提交的变更集。 */
    addedChanges: Record<string, ChangeData[]>;

    branches: BranchData[];
    remoteBranches: RefData[];

    /** 历史里选中的提交与只看的引用（`null` 是全部分支、远端与标签）。 */
    selectedCommit: string | null;
    historyRef: string | null;

    done: Record<Step, boolean>;
}

/** Diff 里显示的一行，`op` 是它在文件里的操作序号。 */
export interface DiffRow {
    kind: 'c' | 'd' | 'a';
    old: number | null;
    new: number | null;
    text: string;
    op: number;
}

/** 一个块。 */
export interface Hunk {
    header: string;
    rows: DiffRow[];
}

/** 一侧的 Diff：块与增删行数。 */
export interface SideDiff {
    hunks: Hunk[];
    insertions: number;
    deletions: number;
}

/** 勾选框的三种状态。 */
export type Check = 'off' | 'mixed' | 'on';

/** 块的上下文行数。 */
export const contextLines = 7;

/** 提交标题的建议长度。 */
export const subjectLimit = 50;

// MARK: - Initial State

/** 按导出的数据建出初始状态：选中 `src/readings.ts` 的未暂存一侧，标题框里是保存着的草稿。 */
export function createState(data: RepoData): DemoState {
    const files = sortFiles(
        data.files.map((file) => ({
            path: file.path,
            isNew: file.isNew,
            ops: file.ops.map(([kind, staged, text]) => ({ kind, staged: staged === 1, text })),
        })),
    );

    return {
        view: 'working',
        files,
        selectedPath: files.some((file) => file.path === 'src/readings.ts') ? 'src/readings.ts' : null,
        side: 'unstaged',
        selection: null,
        subject: data.draft,
        body: '',
        commits: data.commits,
        addedChanges: {},
        branches: data.branches.map((branch) => ({ ...branch })),
        remoteBranches: data.remoteBranches.map((branch) => ({ ...branch })),
        selectedCommit: null,
        historyRef: null,
        done: { stage: false, commit: false, push: false },
    };
}

/** 文件列表按文件名排序，不分大小写。 */
export function sortFiles(files: WorkFile[]): WorkFile[] {
    return [...files].sort((a, b) => a.path.localeCompare(b.path, 'en', { sensitivity: 'base', numeric: true }));
}

// MARK: - Status

/** 文件的勾选框：没有暂存、部分暂存或全部暂存。 */
export function fileCheck(file: WorkFile): Check {
    const changes = file.ops.filter((op) => op.kind !== 'c');
    const staged = changes.filter((op) => op.staged).length;

    if (staged === 0) {
        return 'off';
    }

    return staged === changes.length ? 'on' : 'mixed';
}

/** 状态列的两个标记：左边是已暂存一侧，右边是未暂存一侧。 */
export function fileBadges(file: WorkFile): { staged: 'A' | 'M' | null; unstaged: 'M' | '?' | null } {
    const hasStaged = file.ops.some((op) => op.kind !== 'c' && op.staged);
    const hasUnstaged = file.ops.some((op) => op.kind !== 'c' && !op.staged);

    // 新文件没有任何暂存时还是未跟踪的文件
    const untracked = file.isNew && !hasStaged;

    return {
        staged: hasStaged ? (file.isNew ? 'A' : 'M') : null,
        unstaged: hasUnstaged ? (untracked ? '?' : 'M') : null,
    };
}

/** 有没有已暂存的改动。 */
export function hasStagedChanges(state: DemoState): boolean {
    return state.files.some((file) => file.ops.some((op) => op.kind !== 'c' && op.staged));
}

/** 有没有未暂存的改动。 */
export function hasUnstagedChanges(state: DemoState): boolean {
    return state.files.some((file) => file.ops.some((op) => op.kind !== 'c' && !op.staged));
}

/** 当前分支。 */
export function headBranch(state: DemoState, data: RepoData): BranchData {
    const branch = state.branches.find((candidate) => candidate.name === data.head);

    if (!branch) {
        throw new Error(`没有分支 ${data.head}`);
    }

    return branch;
}

/**
 * 选中一个文件：有未暂存的改动时看未暂存一侧，否则看已暂存一侧。
 */
export function selectFile(state: DemoState, path: string): DemoState {
    const file = state.files.find((candidate) => candidate.path === path);

    if (!file) {
        return state;
    }

    const side = file.ops.some((op) => op.kind !== 'c' && !op.staged) ? 'unstaged' : 'staged';

    return { ...state, selectedPath: path, side, selection: null };
}

/** 切换已暂存与未暂存两侧；没有改动的一侧不能切过去。 */
export function selectSide(state: DemoState, side: Side): DemoState {
    const file = selectedFile(state);

    if (!file || !file.ops.some((op) => op.kind !== 'c' && op.staged === (side === 'staged'))) {
        return state;
    }

    return { ...state, side, selection: null };
}

/** 选中的文件。 */
export function selectedFile(state: DemoState): WorkFile | null {
    return state.files.find((file) => file.path === state.selectedPath) ?? null;
}

// MARK: - Diff

/**
 * 一侧显示的全部行：已暂存一侧把未暂存的删除当作上下文、略去未暂存的新增；
 * 未暂存一侧把已暂存的新增当作上下文、略去已暂存的删除。
 */
export function sideRows(file: WorkFile, side: Side): DiffRow[] {
    const rows: DiffRow[] = [];
    let old = 0;
    let current = 0;

    file.ops.forEach((op, index) => {
        const kind = rowKind(op, side);

        if (kind === null) {
            return;
        }

        if (kind !== 'a') {
            old += 1;
        }

        if (kind !== 'd') {
            current += 1;
        }

        rows.push({
            kind,
            old: kind === 'a' ? null : old,
            new: kind === 'd' ? null : current,
            text: op.text,
            op: index,
        });
    });

    return rows;
}

/** 一侧的块与增删行数；块按 Git 的做法带 7 行上下文，相隔不超过 14 行的改动并成一块。 */
export function sideDiff(file: WorkFile, side: Side): SideDiff {
    const rows = sideRows(file, side);
    const changed = rows.flatMap((row, index) => (row.kind === 'c' ? [] : [index]));
    const ranges: [number, number][] = [];

    for (const index of changed) {
        const last = ranges.at(-1);

        if (last && index - last[1] - 1 <= contextLines * 2) {
            last[1] = index;
        } else {
            ranges.push([index, index]);
        }
    }

    const oldLines = rows.filter((row) => row.kind !== 'a').map((row) => row.text);

    const hunks = ranges.map(([first, last]) => {
        const start = Math.max(0, first - contextLines);
        const end = Math.min(rows.length - 1, last + contextLines);

        return makeHunk(rows, start, end, oldLines);
    });

    return {
        hunks,
        insertions: changed.filter((index) => rows[index]?.kind === 'a').length,
        deletions: changed.filter((index) => rows[index]?.kind === 'd').length,
    };
}

/** 把一侧的块写成补丁原文，格式与导出的 `ChangeData.patch` 相同。 */
export function patchText(diff: SideDiff): string {
    return diff.hunks
        .map((hunk) => [hunk.header, ...hunk.rows.map((row) => prefixOf(row.kind) + row.text)].join('\n'))
        .join('\n');
}

/** 解析补丁原文里的块，供历史与储藏的详情显示。 */
export function parsePatch(patch: string): Hunk[] {
    const hunks: Hunk[] = [];
    let old = 0;
    let current = 0;

    for (const line of patch.split('\n')) {
        const header = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line);

        if (header) {
            old = Number(header[1]) - 1;
            current = Number(header[2]) - 1;
            hunks.push({ header: line, rows: [] });
            continue;
        }

        const hunk = hunks.at(-1);

        if (!hunk || line.startsWith('\\')) {
            continue;
        }

        const kind = line.startsWith('+') ? 'a' : line.startsWith('-') ? 'd' : 'c';

        if (kind !== 'a') {
            old += 1;
        }

        if (kind !== 'd') {
            current += 1;
        }

        hunk.rows.push({
            kind,
            old: kind === 'a' ? null : old,
            new: kind === 'd' ? null : current,
            text: line.slice(1),
            op: hunk.rows.length,
        });
    }

    return hunks;
}

// MARK: - Staging

/** 勾选框：没有全部暂存时暂存整个文件，全部暂存时取消暂存。 */
export function toggleFile(state: DemoState, path: string): DemoState {
    const file = state.files.find((candidate) => candidate.path === path);

    if (!file) {
        return state;
    }

    const staged = fileCheck(file) !== 'on';

    return updateFile(state, path, (ops) => ops.map((op) => ({ ...op, staged })));
}

/** Stage All 与 Unstage All：每个文件的全部改动。 */
export function stageAll(state: DemoState, staged: boolean): DemoState {
    return settle(state, {
        ...state,
        selection: null,
        files: state.files.map((file) => ({ ...file, ops: file.ops.map((op) => ({ ...op, staged })) })),
    });
}

/** 暂存或取消暂存一个块里的全部改动行。 */
export function stageHunk(state: DemoState, hunkIndex: number): DemoState {
    const file = selectedFile(state);
    const hunk = file ? sideDiff(file, state.side).hunks[hunkIndex] : undefined;

    if (!file || !hunk) {
        return state;
    }

    const ops = hunk.rows.filter((row) => row.kind !== 'c').map((row) => row.op);

    return stageOps(state, file.path, ops);
}

/** 暂存或取消暂存行号选中的改动行。 */
export function stageSelection(state: DemoState): DemoState {
    const file = selectedFile(state);

    if (!file || !state.selection) {
        return state;
    }

    return stageOps(state, file.path, state.selection.ops);
}

/**
 * 点击一个改动行的行号：未选的加入选区并记作起点，已选的移出；按着 ⇧ 时从起点起把一段改动行都加入。
 *
 * 选区不跨块；点到别的块时从那一块重新开始。上下文行不能选。
 */
export function selectLine(state: DemoState, hunkIndex: number, op: number, extend: boolean): DemoState {
    const file = selectedFile(state);
    const hunk = file ? sideDiff(file, state.side).hunks[hunkIndex] : undefined;
    const row = hunk?.rows.find((candidate) => candidate.op === op);

    if (!hunk || !row || row.kind === 'c') {
        return state;
    }

    const current = state.selection?.hunk === hunkIndex ? state.selection : null;

    if (extend && current) {
        const changeOps = hunk.rows
            .filter((candidate) => candidate.kind !== 'c')
            .map((candidate) => candidate.op);
        const low = Math.min(current.anchor, op);
        const high = Math.max(current.anchor, op);
        const range = changeOps.filter((candidate) => candidate >= low && candidate <= high);

        return { ...state, selection: { ...current, ops: unique([...current.ops, ...range]) } };
    }

    if (current?.ops.includes(op)) {
        const ops = current.ops.filter((candidate) => candidate !== op);

        return { ...state, selection: ops.length > 0 ? { ...current, ops } : null };
    }

    return {
        ...state,
        selection: { hunk: hunkIndex, ops: unique([...(current?.ops ?? []), op]), anchor: op },
    };
}

// MARK: - Commit

/** 标题剩余的字数：标题与正文都空时没有计数；按 UTF-16 计，去掉首尾空白。 */
export function remainingCharacters(subject: string, body: string): number | null {
    if (subject === '' && body === '') {
        return null;
    }

    return subjectLimit - subject.trim().length;
}

/** 各种换行：CRLF、LF、CR、垂直制表、换页、NEL 与 Unicode 的行分隔符、段分隔符。 */
export const newline = /\r\n|[\n\v\f\r\u0085\u2028\u2029]/;

/**
 * 粘贴进标题的多行文字分到标题与正文：开头的空行之后第一行留给标题，其余去掉首尾空行后接到已有正文后面，
 * 已有正文时另起一行；接上去的内容里换行一律写成 `\n`。
 */
export function multilineParts(text: string, body: string): { subject: string; body: string } {
    const lines = text.split(newline);

    // 跳过开头的空行，第一个不空的行是标题；全是空行时标题为空
    const start = lines.findIndex((line) => line !== '');
    const [subject = '', ...rest] = start === -1 ? [] : lines.slice(start);

    // 其余的行统一用 `\n` 接起来，再去掉首尾的空行
    const added = rest.join('\n').replace(/^\n+|\n+$/g, '');

    // 没有可接的内容时正文不变；已有正文时另起一行接在后面
    if (added === '') {
        return { subject, body };
    }

    return { subject, body: body === '' ? added : `${body}\n${added}` };
}

/** Commit 按钮能不能按：有标题，且有已暂存的改动。 */
export function canCommit(state: DemoState): boolean {
    return state.subject.trim() !== '' && hasStagedChanges(state);
}

/**
 * 提交：已暂存的改动离开工作区，当前分支前进一个提交并多领先远端一个。
 *
 * 已暂存的删除去掉、已暂存的新增变成上下文；没有剩下改动的文件从列表里消失。
 */
export function commit(state: DemoState, data: RepoData, now: Date): DemoState {
    if (!canCommit(state)) {
        return state;
    }

    const branch = headBranch(state, data);
    const message =
        state.body.trim() === ''
            ? state.subject.trim()
            : `${state.subject.trim()}\n\n${state.body.trimEnd()}`;

    const time = Math.floor(now.getTime() / 1000);
    const person: Person = [data.identity.name, data.identity.email, time, zoneOf(now)];
    const hash = fakeHash(`${branch.hash}\n${message}\n${time}`);

    const changes = state.files.flatMap((file) => {
        const diff = sideDiff(file, 'staged');

        if (diff.hunks.length === 0) {
            return [];
        }

        return [{ path: file.path, status: file.isNew ? 'A' : 'M', patch: patchText(diff) }];
    });

    const files = state.files
        .map((file) => {
            const committed = file.ops.some((op) => op.kind !== 'c' && op.staged);
            const ops = file.ops
                .filter((op) => !(op.kind === 'd' && op.staged))
                .map((op) =>
                    op.kind === 'a' && op.staged
                        ? { kind: 'c' as const, staged: false, text: op.text }
                        : op,
                );

            return { ...file, isNew: file.isNew && !committed, ops };
        })
        .filter((file) => file.ops.some((op) => op.kind !== 'c'));

    const selectedPath = files.some((file) => file.path === state.selectedPath) ? state.selectedPath : null;

    return {
        ...state,
        files,
        selectedPath,

        // 提交之后暂存区是空的，只剩未暂存一侧有内容
        side: 'unstaged',
        selection: null,
        subject: '',
        body: '',
        commits: [
            {
                hash,
                parents: [branch.hash],
                tree: fakeHash(`tree\n${hash}`),
                author: person,
                committer: person,
                message,
            },
            ...state.commits,
        ],
        addedChanges: { ...state.addedChanges, [hash]: changes },
        branches: state.branches.map((candidate) =>
            candidate.name === branch.name ? { ...candidate, hash, ahead: candidate.ahead + 1 } : candidate,
        ),
        selectedCommit: hash,
        done: { ...state.done, commit: true },
    };
}

// MARK: - Push

/** 推送当前分支：远端分支指向本地的最新提交，领先数清零。 */
export function push(state: DemoState, data: RepoData): DemoState {
    const branch = headBranch(state, data);
    const upstream = branch.upstream;

    if (!upstream) {
        return state;
    }

    return {
        ...state,
        branches: state.branches.map((candidate) =>
            candidate.name === branch.name ? { ...candidate, ahead: 0 } : candidate,
        ),
        remoteBranches: state.remoteBranches.map((remote) =>
            remote.name === upstream ? { ...remote, hash: branch.hash } : remote,
        ),
        done: { ...state.done, push: true },
    };
}

// MARK: - History

/** 一个引用：本地分支、远端分支或标签。 */
export interface Decoration {
    name: string;
    kind: 'local' | 'remote' | 'tag';
    ref: string;
}

/** 指向一个提交的引用：HEAD 所在分支在前，其余按完整引用名倒序。 */
export function decorations(state: DemoState, data: RepoData, hash: string): Decoration[] {
    const all: Decoration[] = [
        ...state.branches
            .filter((branch) => branch.hash === hash)
            .map((branch) => ({ name: branch.name, kind: 'local' as const, ref: `refs/heads/${branch.name}` })),
        ...state.remoteBranches
            .filter((remote) => remote.hash === hash)
            .map((remote) => ({ name: remote.name, kind: 'remote' as const, ref: `refs/remotes/${remote.name}` })),
        ...data.tags
            .filter((tag) => tag.hash === hash)
            .map((tag) => ({ name: tag.name, kind: 'tag' as const, ref: `refs/tags/${tag.name}` })),
    ];

    // 远端的 HEAD 跟着它指向的远端分支
    const remoteHead = state.remoteBranches.find((remote) => remote.name === data.remoteHead);

    if (remoteHead?.hash === hash) {
        const name = `${data.remoteHead.split('/')[0]}/HEAD`;

        all.push({ name, kind: 'remote', ref: `refs/remotes/${name}` });
    }

    const headRef = `refs/heads/${data.head}`;

    return all.sort((a, b) => {
        if (a.ref === headRef || b.ref === headRef) {
            return a.ref === headRef ? -1 : 1;
        }

        return a.ref < b.ref ? 1 : a.ref > b.ref ? -1 : 0;
    });
}

/** 一个引用指向的提交。 */
export function refTarget(state: DemoState, data: RepoData, ref: string): string | null {
    return (
        state.branches.find((branch) => `refs/heads/${branch.name}` === ref)?.hash ??
        state.remoteBranches.find((remote) => `refs/remotes/${remote.name}` === ref)?.hash ??
        data.tags.find((tag) => `refs/tags/${tag.name}` === ref)?.hash ??
        null
    );
}

/** 历史列表里的提交：全部引用，或只看一个引用能到达的提交；顺序不变。 */
export function historyCommits(state: DemoState, data: RepoData): CommitData[] {
    const target = state.historyRef === null ? null : refTarget(state, data, state.historyRef);

    if (target === null) {
        return state.commits;
    }

    const reachable = reachableFrom(state.commits, target);

    return state.commits.filter((item) => reachable.has(item.hash));
}

/** 还没推送的提交：当前分支能到达、它的上游到达不了的提交。 */
export function unpushedCommits(state: DemoState, data: RepoData): Set<string> {
    const branch = headBranch(state, data);
    const upstream = state.remoteBranches.find((remote) => remote.name === branch.upstream);
    const local = reachableFrom(state.commits, branch.hash);

    if (!upstream) {
        return local;
    }

    const pushed = reachableFrom(state.commits, upstream.hash);

    return new Set([...local].filter((hash) => !pushed.has(hash)));
}

/** 从一个提交沿父提交能到达的全部提交，包括它自己。 */
export function reachableFrom(commits: readonly CommitData[], start: string): Set<string> {
    const byHash = new Map(commits.map((item) => [item.hash, item]));
    const reachable = new Set<string>();
    const pending = [start];

    while (pending.length > 0) {
        const hash = pending.pop() ?? '';

        if (reachable.has(hash) || !byHash.has(hash)) {
            continue;
        }

        reachable.add(hash);
        pending.push(...(byHash.get(hash)?.parents ?? []));
    }

    return reachable;
}

/**
 * 切换视图。
 *
 * 第一次打开历史时选中列表里的第一个提交，详情里马上有内容。
 */
export function selectView(state: DemoState, data: RepoData, view: View): DemoState {
    if (view !== 'history') {
        return { ...state, view };
    }

    const next = { ...state, view };
    const visible = historyCommits(next, data);

    if (visible.some((item) => item.hash === state.selectedCommit)) {
        return next;
    }

    return { ...next, selectedCommit: visible[0]?.hash ?? null };
}

/** 在侧边栏点一个引用：历史只看它能到达的提交，并选中它指向的提交。 */
export function selectRef(state: DemoState, data: RepoData, ref: string): DemoState {
    const target = refTarget(state, data, ref);

    if (target === null) {
        return state;
    }

    return { ...state, view: 'history', historyRef: ref, selectedCommit: target };
}

/** 选中历史里的一个提交。 */
export function selectCommit(state: DemoState, hash: string): DemoState {
    return state.commits.some((item) => item.hash === hash) ? { ...state, selectedCommit: hash } : state;
}

/** 提交的变更集：导出的数据或演示里新建的提交。 */
export function changesOf(state: DemoState, all: Record<string, ChangeData[]>, hash: string): ChangeData[] | null {
    return state.addedChanges[hash] ?? all[hash] ?? null;
}

/** 变更集的增删行数。 */
export function changeCounts(change: ChangeData): { insertions: number; deletions: number } {
    let insertions = 0;
    let deletions = 0;

    for (const line of change.patch.split('\n')) {
        if (line.startsWith('+')) {
            insertions += 1;
        } else if (line.startsWith('-')) {
            deletions += 1;
        }
    }

    return { insertions, deletions };
}

/** 一个时刻在本机时区的 `±hhmm`。 */
export function zoneOf(date: Date): string {
    const offset = -date.getTimezoneOffset();
    const absolute = Math.abs(offset);
    const hours = String(Math.floor(absolute / 60)).padStart(2, '0');
    const minutes = String(absolute % 60).padStart(2, '0');

    return `${offset < 0 ? '-' : '+'}${hours}${minutes}`;
}

// MARK: - Private

/** 一行操作在一侧的样子：上下文、删除、新增，或不显示。 */
function rowKind(op: Op, side: Side): DiffRow['kind'] | null {
    if (op.kind === 'c') {
        return 'c';
    }

    if (side === 'staged') {
        if (op.kind === 'd') {
            return op.staged ? 'd' : 'c';
        }

        return op.staged ? 'a' : null;
    }

    if (op.kind === 'd') {
        return op.staged ? null : 'd';
    }

    return op.staged ? 'c' : 'a';
}

/** 按 Git 的写法生成块头：`@@ -a,b +c,d @@` 加上块前最近一行以字母、`_` 或 `$` 开头的旧文件内容。 */
function makeHunk(rows: DiffRow[], start: number, end: number, oldLines: string[]): Hunk {
    const slice = rows.slice(start, end + 1);
    const before = rows.slice(0, start);
    const oldBefore = before.filter((row) => row.kind !== 'a').length;
    const newBefore = before.filter((row) => row.kind !== 'd').length;
    const oldCount = slice.filter((row) => row.kind !== 'a').length;
    const newCount = slice.filter((row) => row.kind !== 'd').length;

    const range = (before: number, count: number) => {
        const first = count === 0 ? before : before + 1;

        return count === 1 ? `${first}` : `${first},${count}`;
    };

    let header = `@@ -${range(oldBefore, oldCount)} +${range(newBefore, newCount)} @@`;

    for (let index = oldBefore - 1; index >= 0; index -= 1) {
        const line = oldLines[index] ?? '';

        if (/^[A-Za-z_$]/.test(line)) {
            header += ` ${line.slice(0, 80).trimEnd()}`;
            break;
        }
    }

    return { header, rows: slice };
}

/** 补丁里一行的前缀。 */
function prefixOf(kind: DiffRow['kind']): string {
    return kind === 'a' ? '+' : kind === 'd' ? '-' : ' ';
}

/** 把一组操作切换到当前一侧的反面：未暂存一侧暂存，已暂存一侧取消暂存。 */
function stageOps(state: DemoState, path: string, targets: number[]): DemoState {
    const staged = state.side === 'unstaged';
    const set = new Set(targets);

    return updateFile({ ...state, selection: null }, path, (ops) =>
        ops.map((op, index) => (set.has(index) && op.kind !== 'c' ? { ...op, staged } : op)),
    );
}

/** 改一个文件的操作。 */
function updateFile(state: DemoState, path: string, change: (ops: Op[]) => Op[]): DemoState {
    return settle(state, {
        ...state,
        files: state.files.map((file) => (file.path === path ? { ...file, ops: change(file.ops) } : file)),
    });
}

/**
 * 暂存或取消暂存之后：有改动行新进了暂存区就记下引导的第一步；选中的文件在当前一侧没有改动时换到另一侧。
 */
function settle(previous: DemoState, next: DemoState): DemoState {
    const before = new Map(previous.files.map((file) => [file.path, file.ops]));

    const added = next.files.some((file) =>
        file.ops.some(
            (op, index) =>
                op.kind !== 'c' &&
                op.staged &&
                before.get(file.path)?.[index]?.staged === false,
        ),
    );

    const file = selectedFile(next);
    const showsStaged = next.side === 'staged';
    const empty = file !== null && !file.ops.some((op) => op.kind !== 'c' && op.staged === showsStaged);

    return {
        ...next,
        side: empty ? (next.side === 'staged' ? 'unstaged' : 'staged') : next.side,
        done: added ? { ...next.done, stage: true } : next.done,
    };
}

/** 去掉重复的序号并排序。 */
function unique(values: number[]): number[] {
    return [...new Set(values)].sort((a, b) => a - b);
}

/** 由内容算出 40 位十六进制的提交标识；只用于演示里新建的提交。 */
function fakeHash(seed: string): string {
    let result = '';
    let h1 = 0x811c9dc5;
    let h2 = 0x01000193;

    for (let round = 0; result.length < 40; round += 1) {
        for (const character of `${seed}#${round}`) {
            h1 = Math.imul(h1 ^ character.charCodeAt(0), 0x01000193) >>> 0;
            h2 = Math.imul(h2 + character.charCodeAt(0), 0x5bd1e995) >>> 0;
        }

        result += ((h1 ^ h2) >>> 0).toString(16).padStart(8, '0');
    }

    return result.slice(0, 40);
}
