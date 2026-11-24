import type { IconName } from '../icons.ts';
import { headBranch, historyCommits } from '../model.ts';
import type { DemoKey } from '../text.ts';
import type { RenderContext } from './context.ts';
import { button, esc, icon, shortRef } from './format.ts';

/**
 * 工具栏：中间一栏上方是后退、前进与窗口标题，右边一栏上方是 Finder、终端、获取、拉取、推送等按钮。
 */

/** 后退、前进与标题、副标题。 */
export function renderTitle(context: RenderContext): string {
    const { data, text, ui } = context;

    return (
        `<div class="sd-glass sd-capsule sd-nav">` +
        button({
            action: 'back',
            className: 'sd-tool',
            content: icon('back'),
            label: text.t('navigation.back'),
            disabled: ui.back.length === 0,
        }) +
        button({
            action: 'forward',
            className: 'sd-tool',
            content: icon('forward'),
            label: text.t('navigation.forward'),
            disabled: ui.forward.length === 0,
        }) +
        `</div>` +
        `<div class="sd-heading">` +
        `<p class="sd-title" translate="no">${esc(`${data.host}:${data.repository}`)}</p>` +
        `<p class="sd-subtitle">${esc(subtitle(context))}</p>` +
        `</div>`
    );
}

/** 右边一栏上方的按钮；窄一些时靠后的几组先藏起来。 */
export function renderActions(context: RenderContext): string {
    const { data, text, ui } = context;

    const tool = (action: string, image: IconName, key: DemoKey, guide?: string) =>
        button({ action, className: 'sd-tool', content: icon(image), label: text.t(key), guide });

    const fetch = button({
        action: 'fetch',
        className: `sd-tool${ui.fetching ? ' is-busy' : ''}`,
        content: ui.fetching ? `<span class="sd-spinner" aria-hidden="true"></span>` : icon('fetch'),
        label: text.t('sync.fetch'),
        disabled: ui.fetching,
    });

    return (
        `<div class="sd-glass sd-cluster">${tool('unavailable', 'folderOpen', 'toolbar.finder')}` +
        `${tool('unavailable', 'terminal', 'toolbar.terminal')}</div>` +
        `<span class="sd-host" data-tier="3" translate="no">${esc(data.host)}:</span>` +
        `<div class="sd-glass sd-capsule">${fetch}${tool('unavailable', 'pull', 'sync.pull')}` +
        `${tool('push', 'push', 'sync.push', 'push')}</div>` +
        `<div class="sd-glass sd-round" data-tier="3">${tool('unavailable', 'forcePush', 'toolbar.forcePush')}</div>` +
        `<div class="sd-glass sd-capsule" data-tier="2">${tool('unavailable', 'trayDown', 'toolbar.applyStash')}` +
        `${tool('unavailable', 'trayUp', 'toolbar.saveStash')}</div>` +
        `<div class="sd-glass sd-cluster" data-tier="1">` +
        `${tool('unavailable', 'createBranch', 'toolbar.createBranch')}` +
        `${tool('unavailable', 'refresh', 'action.refresh')}</div>` +
        `<div class="sd-glass sd-round" data-tier="1">${tool('unavailable', 'search', 'action.search')}</div>`
    );
}

// MARK: - Private

/** 副标题：工作区写当前分支与改动的文件数，历史写所看的范围与提交数，储藏写储藏数。 */
function subtitle(context: RenderContext): string {
    const { state, data, text } = context;

    switch (state.view) {
        case 'working':
            return text.t('working.subtitle.branch', headBranch(state, data).name, state.files.length);
        case 'history': {
            const scope = state.historyRef === null ? text.t('history.title') : shortRef(state.historyRef);

            return text.t('history.subtitle', scope, historyCommits(state, data).length);
        }
        default:
            return text.t('stash.subtitle', 1);
    }
}
