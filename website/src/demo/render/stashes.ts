import type { RenderContext } from './context.ts';
import { emptyState } from './diff.ts';
import { esc, formatDate, refBadge, subjectOf } from './format.ts';
import { commitDetail } from './history.ts';

/**
 * 储藏：中间一栏是储藏列表，右边一栏是选中储藏的详情。
 */

/** 储藏提交信息里 Git 自动加上的 `On 分支: ` 前缀。 */
const stashPrefix = /^On ([^:]+): (.*)$/;

/** 中间一栏：标题栏与只有一份储藏的列表。 */
export function renderStashColumn(context: RenderContext): string {
    const { data, text, ui } = context;
    const subject = subjectOf(data.stash.message);
    const match = stashPrefix.exec(subject);
    const branch = match?.[1] ?? null;
    const title = match?.[2] || subject;

    return (
        `<div class="sd-bar sd-stash-bar"><span>${esc(text.t('stash.title'))}</span></div>` +
        `<div class="sd-stash-list" role="listbox" aria-label="${esc(text.t('stash.title'))}">` +
        `<div class="sd-stash${ui.stashSelected ? ' is-selected' : ''}" role="option" tabindex="0" ` +
        `aria-selected="${ui.stashSelected}" data-action="stash">` +
        `<span class="sd-stash-top"><span class="sd-stash-based">${esc(text.t('stash.basedOn'))}</span>` +
        `<span class="sd-badges">${branch ? refBadge(branch, 'remote') : ''}</span>` +
        `<span class="sd-date">${esc(formatDate(data.stash.committer, 'short', text.lang))}</span></span>` +
        `<span class="sd-stash-title">${esc(title)}</span></div></div>`
    );
}

/** 右边一栏：选中储藏的详情，引用一行是储藏徽标；没有选中时是空白页。 */
export function renderStashDetail(context: RenderContext): string {
    const { data, text, ui } = context;

    if (!ui.stashSelected) {
        return `<div class="sd-detail-head"></div>${emptyState(text.t('stash.noSelection'), 'tray')}`;
    }

    return commitDetail(context, data.stash, {
        refs: refBadge('stash', 'stash'),
        actions: ['stash.applyButton', 'stash.deleteButton', 'history.diffTool'],
    });
}
