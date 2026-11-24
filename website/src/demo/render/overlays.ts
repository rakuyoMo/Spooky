import type { IconName } from '../icons.ts';
import { changesOf, headBranch, reachableFrom } from '../model.ts';
import type { QuickItem } from '../quick.ts';
import { quickResults } from '../quick.ts';
import type { DemoKey } from '../text.ts';
import type { RenderContext } from './context.ts';
import { button, esc, icon, slot } from './format.ts';

/**
 * 浮在窗口上的两种面板：推送对话框与快捷操作。
 */

/** 每种结果的类型名、图标与回车时的动作名。 */
const kinds: Record<QuickItem['kind'], { type: DemoKey; icon: IconName; action: DemoKey }> = {
    navigation: {
        type: 'quickActions.type.navigation',
        icon: 'folder',
        action: 'quickActions.showInApp',
    },
    branch: {
        type: 'quickActions.type.branch',
        icon: 'branch',
        action: 'quickActions.showBranchHistory',
    },
    remoteBranch: {
        type: 'quickActions.type.remoteBranch',
        icon: 'branch',
        action: 'quickActions.showRemoteBranchHistory',
    },
    tag: {
        type: 'quickActions.type.tag',
        icon: 'tag',
        action: 'quickActions.showTagHistory',
    },
    file: {
        type: 'quickActions.type.file',
        icon: 'doc',
        action: 'quickActions.showFile',
    },
    commit: {
        type: 'quickActions.type.commit',
        icon: 'commit',
        action: 'quickActions.revealInHistory',
    },
};

/** 三个视图的图标。 */
const viewIcons: Record<string, IconName> = { working: 'folder', history: 'clock', stashes: 'tray' };

/** 打开着的面板；没有时是空的。 */
export function renderOverlay(context: RenderContext): string {
    switch (context.ui.overlay) {
        case 'push':
            return pushSheet(context);
        case 'quick':
            return quickPanel(context);
        default:
            return '';
    }
}

/** 快捷操作的结果列表：选中的一行右边写回车时的动作。 */
export function renderQuickResults(context: RenderContext): string {
    const { text, ui } = context;
    const items = quickItems(context);

    if (items.length === 0) {
        return `<li class="sd-quick-empty" role="presentation">${esc(text.t('quickActions.noResults'))}</li>`;
    }

    return items
        .map((item, index) => {
            const kind = kinds[item.kind];
            const selected = index === ui.quickIndex;
            const type = text.t(kind.type);
            const detail = item.detail === null ? type : text.t('quickActions.detail', type, item.detail);
            const image = item.kind === 'navigation' ? (viewIcons[item.id] ?? kind.icon) : kind.icon;

            // 提示只取第一行的 “动作 ↩︎”：演示里没有更多动作
            const hintText = text.t('quickActions.objectHint', text.t(kind.action)).split('\n')[0] ?? '';
            const hint = selected ? `<span class="sd-quick-hint">${esc(hintText)}</span>` : '';

            return (
                `<li id="sd-quick-${index}" class="sd-quick-item${selected ? ' is-selected' : ''}" role="option" ` +
                `aria-selected="${selected}" data-action="quick-pick" data-arg="${index}">` +
                `${icon(image, 'sd-icon sd-quick-icon')}<span class="sd-quick-text"><b>${esc(item.title)}</b>` +
                `<small>${esc(detail)}</small></span>${hint}</li>`
            );
        })
        .join('');
}

/** 快捷操作当前的结果，控制器回车时按序号取用。 */
export function quickItems(context: RenderContext): QuickItem[] {
    const { state, data, text, ui } = context;

    const titles = {
        working: text.t('workspace.title'),
        history: text.t('history.title'),
        stashes: text.t('stash.title'),
    };

    return quickResults(state, data, ui.query, headPaths(context), titles);
}

// MARK: - Private

/** 推送对话框：应用图标、标题与说明、目标分支、选项，底下是帮助按钮与两个按钮。 */
function pushSheet(context: RenderContext): string {
    const { state, data, text } = context;
    const branch = headBranch(state, data);

    return (
        `<div class="sd-scrim"></div>` +
        `<div class="sd-sheet" role="dialog" aria-modal="true" ` +
        `aria-labelledby="sd-push-title" aria-describedby="sd-push-help">` +
        `<img class="sd-sheet-icon" src="${esc(context.appIcon)}" alt="" width="64" height="64">` +
        `<div class="sd-sheet-text"><h3 id="sd-push-title">${esc(text.t('sync.pushHead'))}</h3>` +
        `<p id="sd-push-help">${esc(text.t('sync.pushHead.help', branch.name))}</p></div>` +
        `<div class="sd-sheet-field"><span>${esc(text.t('sync.destination'))}</span>` +
        button({
            action: 'unavailable',
            className: 'sd-popup sd-sheet-popup',
            content:
                `<span translate="no">${esc(branch.upstream ?? '')}</span>` +
                icon('upDown', 'sd-icon sd-updown'),
        }) +
        `</div>` +
        `<button type="button" class="sd-disclosure" data-action="unavailable" aria-expanded="false">` +
        `${icon('chevronRight', 'sd-icon sd-chevron')}${esc(text.t('dialog.options'))}</button>` +
        `<div class="sd-sheet-buttons">` +
        button({ action: 'unavailable', className: 'sd-help', content: '?', label: text.t('help.help') }) +
        button({ action: 'close', className: 'sd-button', content: esc(text.t('action.cancel')) }) +
        button({
            action: 'confirm-push',
            className: 'sd-button sd-default',
            content: esc(text.t('sync.pushHead')),
            guide: 'push',
        }) +
        `</div></div>`
    );
}

/** 快捷操作：顶上的大输入框与下面的结果列表。 */
function quickPanel({ text }: RenderContext): string {
    const placeholder = esc(text.t('quickActions.placeholder'));

    return (
        `<div class="sd-quick" role="dialog" aria-modal="true" aria-label="${placeholder}">` +
        `<input class="sd-quick-input" data-input="query" type="text" role="combobox" aria-expanded="true" ` +
        `aria-controls="sd-quick-list" aria-autocomplete="list" autocomplete="off" spellcheck="false" ` +
        `placeholder="${placeholder}" aria-label="${placeholder}">` +
        slot('quick-results', 'ul', 'id="sd-quick-list" class="sd-quick-list" role="listbox"') +
        `</div>`
    );
}

/** HEAD 里的全部文件：HEAD 能到达的提交里出现过的路径；变更集还没取来时是 `null`。 */
function headPaths({ state, data, changes }: RenderContext): string[] | null {
    if (changes === null) {
        return null;
    }

    const paths = new Set<string>();

    for (const hash of reachableFrom(state.commits, headBranch(state, data).hash)) {
        for (const change of changesOf(state, changes, hash) ?? []) {
            paths.add(change.path);
        }
    }

    return [...paths];
}
