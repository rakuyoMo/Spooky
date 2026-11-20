import { highlightLines, piecesHtml } from '../highlight.ts';
import type { IconName } from '../icons.ts';
import { fileIcon } from '../icons.ts';
import { inlineRanges } from '../inline.ts';
import type { ChangeData, DiffRow, Hunk, WorkFile } from '../model.ts';
import { changeCounts, contextLines, parsePatch, selectedFile, sideDiff } from '../model.ts';
import type { DemoText } from '../text.ts';
import type { RenderContext } from './context.ts';
import { button, esc, icon } from './format.ts';

/**
 * Diff：工作区右边一栏的文件 Diff，以及提交与储藏详情里各文件的改动。
 */

/** 工作区右边一栏：文件名与两侧的切换、可滚动的 Diff、底栏。 */
export function renderWorkingDiff(context: RenderContext): string {
    const { state, text } = context;
    const file = selectedFile(state);

    if (!file) {
        return `<div class="sd-diff-head"></div>${emptyState(text.t('detail.empty.title'), 'doc')}`;
    }

    const diff = sideDiff(file, state.side);
    const summary = diffSummary(text, diff.hunks.length, diff.insertions, diff.deletions);

    const hunks = diff.hunks
        .map((hunk, index) => {
            const head = hunkHeader(context, file, hunk, index);

            return `<div class="sd-hunk">${head}${rows(context, file, hunk, index)}</div>`;
        })
        .join('');

    return (
        `<div class="sd-diff-head">${sideHeader(context, file)}</div>` +
        `<div class="sd-diff-scroll" data-scroll="diff:${esc(file.path)}:${state.side}">` +
        `<p class="sd-diff-summary">${esc(summary)}</p>${hunks}</div>` +
        `<div class="sd-diff-foot">${footer(text, summary)}</div>`
    );
}

/**
 * 提交或储藏详情里各文件的改动：顶上是全部折叠 / 展开与改动统计，下面每个文件一段，能单独折叠。
 *
 * `scope` 区分是哪个提交，折叠状态按它记。
 */
export function renderChanges(context: RenderContext, changes: readonly ChangeData[], scope: string): string {
    const { text, ui } = context;
    const keys = changes.map((change) => `${scope}:${change.path}`);
    const allCollapsed = keys.length > 0 && keys.every((key) => ui.collapsed.includes(key));
    const totals = changes.map(changeCounts);
    const additions = totals.reduce((sum, item) => sum + item.insertions, 0);
    const deletions = totals.reduce((sum, item) => sum + item.deletions, 0);

    const summary = text.t(
        'history.summary',
        text.count('history.summary.files', changes.length),
        text.count('history.summary.additions', additions),
        text.count('history.summary.deletions', deletions),
    );

    const files = changes.map((change, index) => changeFile(context, change, keys[index] ?? '')).join('');

    return (
        `<div class="sd-changes-bar">` +
        button({
            action: allCollapsed ? 'expand-all' : 'collapse-all',
            arg: scope,
            className: 'sd-link',
            content: esc(text.t(allCollapsed ? 'history.expandAll' : 'history.collapseAll')),
        }) +
        `<span>${esc(summary)}</span></div>${files}`
    );
}

/** 没有选中时的空白页：一个大图标与一行灰字。 */
export function emptyState(title: string, image: IconName): string {
    return `<div class="sd-empty">${icon(image, 'sd-icon sd-empty-icon')}<p>${esc(title)}</p></div>`;
}

// MARK: - Working Copy

/** 文件名与已暂存 / 未暂存的分段控件；没有改动的一侧不能点，未跟踪的文件整组不能点。 */
function sideHeader({ state, text }: RenderContext, file: WorkFile): string {
    const has = (staged: boolean) => file.ops.some((op) => op.kind !== 'c' && op.staged === staged);
    const tracked = !file.isNew || has(true);
    const name = file.path.split('/').pop() ?? file.path;

    const segment = (side: 'staged' | 'unstaged', key: 'working.staged' | 'working.unstaged') =>
        button({
            action: 'side',
            arg: side,
            className: `sd-segment${state.side === side ? ' is-on' : ''}`,
            content: esc(text.t(key)),
            pressed: state.side === side,
            disabled: !tracked || !has(side === 'staged'),
        });

    return (
        `<span class="sd-file-icon">${fileIcon(file.path)}</span><b class="sd-diff-name">${esc(name)}</b>` +
        `<span class="sd-segments" role="group" aria-label="${esc(text.t('working.diffSide'))}">` +
        `${segment('staged', 'working.staged')}${segment('unstaged', 'working.unstaged')}</span>`
    );
}

/** 块头：`@@` 一行与按块或按所选行暂存的按钮。 */
function hunkHeader({ state, text }: RenderContext, file: WorkFile, hunk: Hunk, index: number): string {
    const picked = state.selection?.hunk === index ? state.selection.ops.length : 0;
    const unstaged = state.side === 'unstaged';

    // 没选行时按整块，选了一行或几行时按行
    const amount = (['Chunk', 'Line', 'Lines'] as const)[Math.min(picked, 2)] ?? 'Chunk';
    const stageKey = `working.${unstaged ? 'stage' : 'unstage'}${amount}` as const;
    const discardKey = `working.discard${amount}` as const;

    const discard = unstaged
        ? button({ action: 'unavailable', className: 'sd-small', content: esc(text.t(discardKey)) })
        : '';

    const stage = button({
        action: picked === 0 ? 'stage-hunk' : 'stage-lines',
        arg: String(index),
        className: 'sd-small',
        content: esc(text.t(stageKey)),
        guide: unstaged ? 'stage' : undefined,
    });

    return (
        `<div class="sd-hunk-head"><code>${esc(hunk.header)}</code>` +
        `<span class="sd-hunk-actions" data-file="${esc(file.path)}">${discard}${stage}</span></div>`
    );
}

/** 一个块的全部行；改动行的行号能点，选中的行号铺蓝底。 */
function rows({ state, text }: RenderContext, file: WorkFile, hunk: Hunk, index: number): string {
    const picked = new Set(state.selection?.hunk === index ? state.selection.ops : []);
    const pieces = highlightLines(hunk.rows.map((row) => row.text), file.path);
    const marks = inlineRanges(hunk.rows);

    return hunk.rows
        .map((row, position) => {
            const codeHtml = piecesHtml(pieces[position] ?? [], marks.get(position));
            const code = `<span class="sd-code">${codeHtml}</span>`;

            if (row.kind === 'c') {
                return `<div class="sd-line">${numbers(row)}${code}</div>`;
            }

            const selected = picked.has(row.op);
            const gutter =
                `<button type="button" class="sd-gutter" data-action="pick" data-arg="${index}:${row.op}" ` +
                `aria-pressed="${selected}" aria-label="${esc(text.t('working.selectLine', row.new ?? row.old ?? 0))}">` +
                `${numberCells(row)}</button>`;

            return `<div class="sd-line sd-${row.kind}${selected ? ' is-picked' : ''}">${gutter}${code}</div>`;
        })
        .join('');
}

/** 底栏：两个显示开关、块数与增删行数、上下文行数。 */
function footer(text: DemoText, summary: string): string {
    const context = text.t('diff.contextLines', contextLines);

    return (
        button({
            action: 'unavailable',
            className: 'sd-plain',
            content: icon('noEntry'),
            label: text.t('diff.ignoreWhitespace'),
        }) +
        button({
            action: 'unavailable',
            className: 'sd-plain',
            content: icon('lineNumbers'),
            label: text.t('diff.showEntireFile'),
        }) +
        `<span class="sd-foot-summary">${esc(summary)}</span>` +
        `<span class="sd-context">${esc(text.t('diff.context'))}` +
        button({
            action: 'unavailable',
            className: 'sd-popup',
            content: `${esc(context)}${icon('upDown', 'sd-icon sd-updown')}`,
        }) +
        `</span>`
    );
}

// MARK: - Commit Details

/** 详情里的一个文件：可折叠的标题行、统计与各块。 */
function changeFile(context: RenderContext, change: ChangeData, key: string): string {
    const { text, ui } = context;
    const open = !ui.collapsed.includes(key);
    const status = change.status === 'A' ? 'A' : 'M';
    const statusName = text.t(status === 'A' ? 'status.added' : 'status.modified');

    const head =
        `<button type="button" class="sd-change-head" data-action="toggle-file-changes" data-arg="${esc(key)}" ` +
        `aria-expanded="${open}">${icon(open ? 'chevronDown' : 'chevronRight', 'sd-icon sd-chevron')}` +
        `<b class="sd-st sd-st-${status}" title="${esc(statusName)}">` +
        `${status}</b><span>${esc(change.path)}</span></button>`;

    if (!open) {
        return `<section class="sd-change">${head}</section>`;
    }

    if (change.binary) {
        const binary = esc(text.t('diff.summary.binary'));

        return `<section class="sd-change">${head}<p class="sd-diff-summary">${binary}</p></section>`;
    }

    const hunks = parsePatch(change.patch);
    const counts = changeCounts(change);
    const summary = diffSummary(text, hunks.length, counts.insertions, counts.deletions);

    const body = hunks
        .map((hunk) => {
            const pieces = highlightLines(hunk.rows.map((row) => row.text), change.path);
            const marks = inlineRanges(hunk.rows);
            const lines = hunk.rows
                .map((row, position) => {
                    const code = piecesHtml(pieces[position] ?? [], marks.get(position));
                    const kind = row.kind === 'c' ? '' : ` sd-${row.kind}`;

                    return `<div class="sd-line${kind}">${numbers(row)}<span class="sd-code">${code}</span></div>`;
                })
                .join('');

            const header = `<div class="sd-hunk-head"><code>${esc(hunk.header)}</code></div>`;

            return `<div class="sd-hunk">${header}${lines}</div>`;
        })
        .join('');

    return `<section class="sd-change">${head}<p class="sd-diff-summary">${esc(summary)}</p>${body}</section>`;
}

// MARK: - Private

/** 块数、新增与删除行数，数量为 1 时用单数的写法。 */
function diffSummary(text: DemoText, chunks: number, insertions: number, deletions: number): string {
    return text.t(
        'working.diffSummary',
        text.count('diff.summary.chunks', chunks),
        text.count('diff.summary.insertions', insertions),
        text.count('diff.summary.deletions', deletions),
    );
}

/** 不能点的两栏行号。 */
function numbers(row: DiffRow): string {
    return `<span class="sd-gutter">${numberCells(row)}</span>`;
}

/** 两栏行号：上下文两边都写，删除只写旧行号并带 “−”，新增只写新行号并带 “+”。 */
function numberCells(row: DiffRow): string {
    const old = row.kind === 'c' ? String(row.old) : row.kind === 'd' ? `-${row.old}` : '';
    const next = row.kind === 'c' ? String(row.new) : row.kind === 'a' ? `+${row.new}` : '';

    return `<span>${old}</span><span>${next}</span>`;
}
