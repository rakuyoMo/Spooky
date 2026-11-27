import type { IconName } from '../icons.ts';
import { icons } from '../icons.ts';
import { headBranch, historyCommits } from '../model.ts';
import type { DemoKey } from '../text.ts';
import type { RenderContext } from './context.ts';
import { button, esc, icon, shortRef } from './format.ts';

/**
 * 工具栏：后退、前进与窗口标题排在中间一栏上方，后面接 Finder、终端、获取、拉取、推送等按钮；
 * 极窄版式里书签按钮排在后退前面。
 *
 * 标题后面的按钮排不下时按 App 的顺序收进末尾的 »：`data-regular` 是一项在常规版式里留在工具栏上的最小窗口宽度，
 * `data-narrow` 是它在极窄版式里的最小窗口宽度，`none` 表示极窄版式里一直收着。这些宽度量自 App。
 */

/** 能收进 » 的项：`data-item` 的名字、图标、标签与点按时的动作，顺序与 App 的溢出菜单相同。 */
const overflowable: { item: string; icon: IconName; label: DemoKey; action: string }[] = [
    { item: 'finder', icon: 'finder', label: 'toolbar.finder', action: 'unavailable' },
    { item: 'terminal', icon: 'terminal', label: 'toolbar.terminal', action: 'unavailable' },
    { item: 'fetch', icon: 'fetch', label: 'sync.fetch', action: 'fetch' },
    { item: 'pull', icon: 'pull', label: 'sync.pull', action: 'unavailable' },
    { item: 'push', icon: 'push', label: 'sync.push', action: 'push' },
    { item: 'forcePush', icon: 'forcePush', label: 'toolbar.forcePush', action: 'unavailable' },
    { item: 'applyStash', icon: 'trayDown', label: 'toolbar.applyStash', action: 'unavailable' },
    { item: 'saveStash', icon: 'trayUp', label: 'toolbar.saveStash', action: 'unavailable' },
    { item: 'createBranch', icon: 'createBranch', label: 'toolbar.createBranch', action: 'unavailable' },
    { item: 'refresh', icon: 'refresh', label: 'action.refresh', action: 'unavailable' },
];

/** 极窄版式里的书签按钮，后退、前进与标题、副标题。 */
export function renderTitle(context: RenderContext): string {
    const { data, text, ui } = context;

    return (
        `<div class="sd-glass sd-round sd-only-narrow">` +
        button({
            action: 'unavailable',
            className: 'sd-tool',
            content: icon('drive'),
            label: text.t('toolbar.bookmarks'),
            item: 'bookmarks',
        }) +
        `</div>` +
        `<div class="sd-glass sd-capsule sd-nav">` +
        button({
            action: 'back',
            className: 'sd-tool',
            content: icon('back'),
            label: text.t('navigation.back'),
            disabled: ui.back.length === 0,
            item: 'back',
        }) +
        button({
            action: 'forward',
            className: 'sd-tool',
            content: icon('forward'),
            label: text.t('navigation.forward'),
            disabled: ui.forward.length === 0,
            item: 'forward',
        }) +
        `</div>` +
        `<div class="sd-heading">` +
        `<p class="sd-title" translate="no">${esc(data.repository)}</p>` +
        `<p class="sd-subtitle">${esc(subtitle(context))}</p>` +
        `</div>`
    );
}

/**
 * 标题后面的按钮。
 *
 * `sd-spread` 标出 App 的工具栏里前面有一段伸缩空白的项：按钮都排得下时，各组之间平分余下的宽度。
 * 常规版式里中间的几组收起后，安全强推与新建分支挨在一起，`sd-join-end` 与 `sd-join-start` 让两块底连成一块。
 */
export function renderActions(context: RenderContext): string {
    const { state, text, ui } = context;

    const tool = (item: string, action: string, image: IconName, key: DemoKey, guide?: string) =>
        button({ action, className: 'sd-tool', content: icon(image), label: text.t(key), guide, item });

    const fetch = button({
        action: 'fetch',
        className: `sd-tool${ui.fetching ? ' is-busy' : ''}`,
        content: ui.fetching ? `<span class="sd-spinner" aria-hidden="true"></span>` : icon('fetch'),
        label: text.t('sync.fetch'),
        disabled: ui.fetching,
        item: 'fetch',
    });

    const more = button({
        action: 'more',
        className: 'sd-tool',
        content: icon('more'),
        label: context.overflowLabel,
        guide: 'push-overflow',
        expanded: ui.overlay === 'more',
    });

    // 搜索项在右端，空间充足时展开当前视图的搜索提示
    const searchHint = state.view === 'history' ? text.t('history.search.forMessage') :
        state.view === 'stashes' ? text.t('stash.search') : '';

    const search = button({
        action: 'unavailable',
        className: 'sd-tool sd-search-tool',
        content:
            icon('search') +
            (searchHint ? `<span class="sd-search-hint" aria-hidden="true">${esc(searchHint)}</span>` : ''),
        label: text.t('action.search'),
        item: 'search',
    });

    return (
        `<div class="sd-glass sd-cluster sd-spread" data-narrow="645">` +
        `${tool('finder', 'unavailable', 'finder', 'toolbar.finder')}` +
        `<span class="sd-tool-slot" data-narrow="688">` +
        `${tool('terminal', 'unavailable', 'terminal', 'toolbar.terminal')}</span></div>` +
        `<div class="sd-glass sd-capsule" data-regular="980" data-narrow="585">${fetch}` +
        `${tool('pull', 'unavailable', 'pull', 'sync.pull')}${tool('push', 'push', 'push', 'sync.push', 'push')}</div>` +
        `<div class="sd-glass sd-round sd-join-end" data-narrow="735">` +
        `${tool('forcePush', 'unavailable', 'forcePush', 'toolbar.forcePush')}</div>` +
        `<div class="sd-glass sd-capsule sd-spread" data-regular="1070" data-narrow="none">` +
        `${tool('applyStash', 'unavailable', 'trayDown', 'toolbar.applyStash')}` +
        `${tool('saveStash', 'unavailable', 'trayUp', 'toolbar.saveStash')}</div>` +
        `<div class="sd-glass sd-cluster sd-spread sd-join-start" data-narrow="none">` +
        `${tool('createBranch', 'unavailable', 'createBranch', 'toolbar.createBranch')}` +
        `<span class="sd-tool-slot" data-regular="1080">` +
        `${tool('refresh', 'unavailable', 'refresh', 'action.refresh')}</span></div>` +
        `<div class="sd-glass sd-round sd-more">${more}</div>` +
        `<div class="sd-glass sd-round sd-spread sd-search">${search}</div>`
    );
}

/**
 * » 的菜单：列出收起来的项，每行是图标与标签。
 *
 * `hidden` 是打开菜单时工具栏上看不到的项的名字。
 */
export function renderOverflowMenu({ text, ui }: RenderContext, hidden: readonly string[]): string {
    const rows = overflowable
        .filter(({ item }) => hidden.includes(item))
        .map(({ item, icon: image, label, action }) => {
            const disabled = item === 'fetch' && ui.fetching;

            // 带掩膜的图标在工具栏上还有一份，菜单里的这份换一个掩膜的名字：藏起来的那份里的掩膜引用不到
            const drawing = icons[image].replaceAll('sd-mask-', 'sd-menu-mask-');

            return (
                `<li role="none">` +
                `<button type="button" class="sd-menu-item" role="menuitem" data-action="${action}"` +
                `${disabled ? ' disabled' : ''}>` +
                `<span class="sd-icon">${drawing}</span>` +
                `<span>${esc(text.t(label))}</span></button></li>`
            );
        });

    return (
        `<button type="button" class="sd-scrim sd-menu-scrim" data-action="close" tabindex="-1" aria-hidden="true">` +
        `</button><ul class="sd-menu" role="menu">${rows.join('')}</ul>`
    );
}

// MARK: - Private

/** 副标题：工作区写当前分支与改动的文件数，历史写所看的范围与提交数，储藏写储藏数。 */
function subtitle(context: RenderContext): string {
    const { state, data, text } = context;

    switch (state.view) {
        case 'working':
            return text.t('working.subtitle.branch', headBranch(state).name, state.files.length);
        case 'history': {
            const scope = state.historyRef === null ? text.t('history.title') : shortRef(state.historyRef);

            return text.t('history.subtitle', scope, historyCommits(state, data).length);
        }
        case 'stashes':
            return text.count('stash.subtitle', 1);
        case 'requests':
            return text.t('pr.title');
        case 'settings':
            return text.t('repositorySettings.title');
    }
}
