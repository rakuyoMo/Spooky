import type { GraphRow } from '../graph.ts';
import { columnCount, graphRows } from '../graph.ts';
import type { CommitData, Decoration } from '../model.ts';
import { changesOf, decorations, headBranch, historyCommits, unpushedCommits } from '../model.ts';
import type { DemoKey } from '../text.ts';
import type { RenderContext } from './context.ts';
import { emptyState, renderChanges } from './diff.ts';
import {
    avatar,
    button,
    esc,
    formatDate,
    icon,
    refBadge,
    shortRef,
    slot,
    subjectOf,
    textWidth,
} from './format.ts';

/**
 * 历史：中间一栏是带提交图的提交列表，右边一栏是选中提交的详情。
 */

/** 提交行的高度与圆点中心距行顶的距离。 */
const rowHeight = 46;
const dotCenter = 25;

/** 日期分组标题行的高度。 */
const groupHeight = 30;

/** 一行引用徽标最多占的宽度。 */
const badgeLimit = 300;

/** 历史一栏在宽版式里的宽度，估算徽标放得下几个时用。 */
const columnWidth = 440;

/** 中间一栏：连接横幅、所看范围与显示选项、提交列表。 */
export function renderHistoryColumn(context: RenderContext): string {
    const { data, text } = context;

    return (
        `<p class="sd-banner">${esc(`${data.host}: ${text.t('connection.connected')}`)}</p>` +
        slot('history-bar', 'div', 'class="sd-bar sd-history-bar"') +
        slot(
            'history-list',
            'div',
            `class="sd-history-list" data-scroll="history" role="listbox" aria-label="${esc(text.t('history.title'))}"`,
        )
    );
}

/** 所看的范围与显示选项按钮。 */
export function renderHistoryBar({ state, text }: RenderContext): string {
    const title = state.historyRef === null ? text.t('history.all') : shortRef(state.historyRef);

    return (
        `<span class="sd-history-scope">${esc(title)}</span>` +
        button({
            action: 'unavailable',
            className: 'sd-plain sd-bar-end',
            content: icon('sliders'),
            label: text.t('history.viewOptions'),
        })
    );
}

/** 提交列表：按月分组，每组一个标题行；选中的行能用方向键移动。 */
export function renderHistoryList(context: RenderContext): string {
    const { state, data, text } = context;
    const commits = historyCommits(state, data);
    const graph = graphRows(commits);
    const unpushed = unpushedCommits(state, data);
    const hasSelection = commits.some((item) => item.hash === state.selectedCommit);
    const focusable = hasSelection ? state.selectedCommit : commits[0]?.hash;

    // 相邻且同月的提交归入一组
    const groups: { title: string; start: number; end: number }[] = [];

    commits.forEach((item, index) => {
        const title = formatDate(item.committer, 'month', text.lang);
        const last = groups.at(-1);

        if (last && last.title === title) {
            last.end = index + 1;
        } else {
            groups.push({ title, start: index, end: index + 1 });
        }
    });

    return groups
        .map((group) => {
            const rows = commits.slice(group.start, group.end).map((item, offset) => {
                const index = group.start + offset;

                return commitRow(context, item, graph[index], {
                    unpushed: unpushed.has(item.hash),
                    focusable: item.hash === focusable,
                });
            });

            return (
                `<div role="group" aria-label="${esc(group.title)}">` +
                `<div class="sd-group" aria-hidden="true">` +
                `${passingGraph(graph[group.start])}<span>${esc(group.title)}</span>` +
                `</div>` +
                `${rows.join('')}</div>`
            );
        })
        .join('');
}

/** 右边一栏：选中提交的头部与详情；没有选中时是空白页。 */
export function renderCommitDetail(context: RenderContext): string {
    const { state, data, text } = context;
    const commit = state.commits.find((item) => item.hash === state.selectedCommit);

    if (!commit) {
        return `<div class="sd-detail-head"></div>${emptyState(text.t('history.noSelection'), 'doc')}`;
    }

    const isHead = headBranch(state, data).hash === commit.hash;
    const refs = refBadges(isHead, decorations(state, data, commit.hash));

    return commitDetail(context, commit, {
        refs,
        actions: ['history.rollback', 'rewrite.revert.button', 'history.diffTool'],
    });
}

/**
 * 提交或储藏的详情：头部的短标识与内容切换，下面依次是元信息、悬停时出现的操作、提交信息与各文件的改动。
 *
 * `refs` 是引用一行的徽标，空字符串时不显示这一行。
 */
export function commitDetail(
    context: RenderContext,
    commit: CommitData,
    options: { refs: string; actions: DemoKey[] },
): string {
    const { text } = context;
    const changes = context.changes === null ? null : changesOf(context.state, context.changes, commit.hash);

    const modes =
        `<span class="sd-segments sd-detail-modes" role="group" aria-label="${esc(text.t('history.detailMode'))}">` +
        button({
            action: 'none',
            className: 'sd-segment is-on',
            content: esc(text.t('history.changeset')),
            pressed: true,
        }) +
        button({
            action: 'unavailable',
            className: 'sd-segment',
            content: esc(text.t('history.tree')),
            pressed: false,
        }) +
        `</span>`;

    const actions = options.actions
        .map((key) => button({ action: 'unavailable', className: 'sd-action', content: esc(text.t(key)) }))
        .join('');

    const files =
        changes === null
            ? `<p class="sd-loading"><span class="sd-spinner" aria-hidden="true"></span>` +
              `${esc(text.t('history.loadingChanges'))}</p>`
            : renderChanges(context, changes, commit.hash);

    return (
        `<div class="sd-detail-head"><code translate="no">${esc(commit.hash.slice(0, 8))}</code>${modes}</div>` +
        `<div class="sd-detail-scroll" data-scroll="detail:${commit.hash}">` +
        metadata(context, commit, options.refs) +
        `<div class="sd-action-line"><span class="sd-actions">${actions}</span></div>` +
        `<p class="sd-message">${esc(commit.message)}</p>` +
        `<div class="sd-changes">${files}</div></div>`
    );
}

// MARK: - Commit Row

/** 一个提交行：提交图、头像，上一行是作者、引用与日期，下一行是短标识与标题。 */
function commitRow(
    context: RenderContext,
    commit: CommitData,
    graph: GraphRow | undefined,
    flags: { unpushed: boolean; focusable: boolean },
): string {
    const { state, data, text } = context;
    const selected = state.selectedCommit === commit.hash;
    const isHead = headBranch(state, data).hash === commit.hash;
    const graphWidth = graph ? columnCount(graph) * 10 + 7 : 0;
    const author = commit.author[0];
    const date = formatDate(commit.committer, 'short', text.lang);

    // 作者、日期与两侧间距之外剩下的宽度留给徽标
    const available = columnWidth - 98 - graphWidth - textWidth(author, 12) - textWidth(date, 12) - 16;

    const arrow = flags.unpushed
        ? `<span class="sd-arrow" role="img" aria-label="${esc(text.t('history.unpushed'))}">↑</span>`
        : `<span class="sd-arrow"></span>`;

    return (
        `<div class="sd-row${selected ? ' is-selected' : ''}" role="option" aria-selected="${selected}" ` +
        `tabindex="${flags.focusable ? 0 : -1}" data-action="select-commit" data-arg="${commit.hash}" ` +
        `style="--g:${graphWidth}px">` +
        `${graph ? commitGraph(graph) : ''}${avatar(author, 32)}` +
        `<span class="sd-row-text"><span class="sd-row-top"><span class="sd-author">${esc(author)}</span>` +
        `${fittedBadges(isHead, decorations(state, data, commit.hash), Math.min(badgeLimit, available))}` +
        `<span class="sd-date">${esc(date)}</span>${arrow}</span>` +
        `<span class="sd-row-bottom"><code class="sd-hash" translate="no">${esc(commit.hash.slice(0, 8))}</code>` +
        `<span class="sd-subject">${esc(subjectOf(commit.message))}</span></span></span></div>`
    );
}

/**
 * 提交行里的徽标：从全部显示起每次少显示一个、末尾补 “…”，取第一种放得下的。
 */
function fittedBadges(isHead: boolean, decorated: readonly Decoration[], limit: number): string {
    const items: { name: string; kind: Decoration['kind'] | 'head' }[] = [
        ...(isHead ? [{ name: 'HEAD', kind: 'head' as const }] : []),
        ...decorated,
    ];

    if (items.length === 0) {
        return '';
    }

    const widthOf = (name: string) => textWidth(name, 11) + 8;
    const total = (shown: number) =>
        items.slice(0, shown).reduce((sum, item) => sum + widthOf(item.name) + 4, 0);
    let shown = items.length;

    while (shown > 0 && total(shown) + (shown < items.length ? widthOf('…') : 0) > limit) {
        shown -= 1;
    }

    const badges = items.slice(0, shown).map((item) => refBadge(item.name, item.kind));
    const more = shown < items.length ? refBadge('…', 'remote') : '';

    return `<span class="sd-badges">${badges.join('')}${more}</span>`;
}

/** 详情里引用一行的全部徽标。 */
function refBadges(isHead: boolean, decorated: readonly Decoration[]): string {
    const badges = decorated.map((item) => refBadge(item.name, item.kind));

    return [...(isHead ? [refBadge('HEAD', 'head')] : []), ...badges].join('');
}

// MARK: - Graph

/** 提交行的图：先画线段，圆点最后盖在线上。 */
function commitGraph(row: GraphRow): string {
    const width = columnCount(row) * 10 + 7;

    const paths = row.segments.map((segment) => {
        const x0 = segment.start * 10 + 7;
        const x1 = segment.end * 10 + 7;
        const y0 = segment.startsAtCommit ? dotCenter : 0;
        const y1 = segment.endsAtCommit ? dotCenter : rowHeight;

        return `<path class="l${segment.line % 10}" d="${curve(x0, y0, x1, y1)}"/>`;
    });

    const dot = `<circle class="sd-dot" cx="${row.column * 10 + 7}" cy="${dotCenter}" r="4.25"/>`;

    return (
        `<svg class="sd-graph" width="${width}" height="${rowHeight}" viewBox="0 0 ${width} ${rowHeight}" aria-hidden="true">` +
        `${paths.join('')}${dot}</svg>`
    );
}

/** 分组标题行的图：下一行从上沿进来的线竖直穿过标题行。 */
function passingGraph(next: GraphRow | undefined): string {
    const passing = next?.segments.filter((segment) => !segment.startsAtCommit) ?? [];
    const columns = Math.max(1, ...passing.map((segment) => segment.start + 1));
    const width = columns * 10 + 7;

    const paths = passing.map((segment) => {
        const x = segment.start * 10 + 7;

        return `<path class="l${segment.line % 10}" d="M${x} 0V${groupHeight}"/>`;
    });

    return (
        `<svg class="sd-graph" width="${width}" height="${groupHeight}" viewBox="0 0 ${width} ${groupHeight}">` +
        `${paths.join('')}</svg>`
    );
}

/** 线段换列时，中间三分之一用贝塞尔曲线过渡，两头竖直。 */
function curve(x0: number, y0: number, x1: number, y1: number): string {
    if (x0 === x1) {
        return `M${x0} ${y0}V${y1}`;
    }

    const distance = (y1 - y0) / 3;

    return (
        `M${x0} ${y0}V${y0 + distance}` +
        `C${x0} ${y0 + distance * 1.5} ${x1} ${y1 - distance * 1.5} ${x1} ${y1 - distance}V${y1}`
    );
}

// MARK: - Metadata

/** 元信息：标签右对齐、值用次要色，右边是作者的大头像；右上角的三角收起或展开提交者与各个哈希。 */
function metadata(context: RenderContext, commit: CommitData, refs: string): string {
    const { text, ui } = context;
    const expanded = !ui.metadataCollapsed;
    const date = (person: CommitData['author']) => formatDate(person, 'long', text.lang);
    const person = (value: CommitData['author']) => `${value[0]} <${value[1]}>`;

    const row = (key: DemoKey, value: string) =>
        `<dt>${esc(text.t(key))}</dt><dd translate="no">${esc(value)}</dd>`;

    const author = row('history.author', person(commit.author)) + row('history.authorDate', date(commit.author));
    const refsRow = refs ? `<dt>${esc(text.t('history.refs'))}</dt><dd class="sd-meta-refs">${refs}</dd>` : '';

    const rest = expanded
        ? row('history.committer', person(commit.committer)) +
          row('history.commitDate', date(commit.committer)) +
          refsRow +
          row('history.hash', commit.hash) +
          commit.parents.map((parent) => row('history.parentHash', parent)).join('') +
          row('history.treeHash', commit.tree)
        : refsRow;

    // 提交者与作者不是同一个人时，提交者的头像排在作者前面
    const avatars =
        commit.committer[1].toLowerCase() === commit.author[1].toLowerCase()
            ? avatar(commit.author[0], 80)
            : `${avatar(commit.committer[0], 80)}${avatar(commit.author[0], 80)}`;

    const toggle = button({
        action: 'toggle-metadata',
        className: 'sd-plain sd-meta-toggle',
        content: icon(expanded ? 'chevronDown' : 'chevronRight', 'sd-icon sd-chevron'),
        label: text.t('history.metadata'),
        pressed: expanded,
    });

    return (
        `<div class="sd-meta">` +
        `<dl>${author}${rest}</dl>` +
        `<span class="sd-meta-avatars">${avatars}</span>` +
        toggle +
        `</div>`
    );
}
