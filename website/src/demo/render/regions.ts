import type { RenderContext } from './context.ts';
import { renderWorkingDiff } from './diff.ts';
import { esc, slot } from './format.ts';
import { renderCommitDetail, renderHistoryBar, renderHistoryColumn, renderHistoryList } from './history.ts';
import { renderOverlay, renderQuickResults } from './overlays.ts';
import { renderCompactNav, renderSidebar } from './sidebar.ts';
import { renderStashColumn, renderStashDetail } from './stashes.ts';
import { renderActions, renderTitle } from './toolbar.ts';
import { renderBodyBar, renderCommitActions, renderCounter, renderFiles, renderWorkingColumn } from './working.ts';

/**
 * 把整个窗口拆成区域：每个区域的 HTML 里，子区域只留占位标记。
 *
 * 浏览器里只替换内容变了的区域；构建时把全部区域拼成整窗的 HTML。
 */

/** 各区域当前的 HTML，键是区域名；`window` 是整窗的骨架。 */
export type Regions = Map<string, string>;

/** 按当前状态输出全部区域；当前视图里不存在的区域不输出。 */
export function renderRegions(context: RenderContext): Regions {
    const { data, state, text, ui } = context;
    const regions: Regions = new Map();

    // 三个视图的列表上方都显示服务器连接状态
    const banner = `<p class="sd-banner">${esc(`${data.host}: ${text.t('connection.connected')}`)}</p>`;

    regions.set('window', windowFrame(context));
    regions.set('sidebar', renderSidebar(context));
    regions.set('nav', renderCompactNav(context));
    regions.set('title', renderTitle(context));
    regions.set('actions', renderActions(context));
    regions.set('overlay', renderOverlay(context));

    if (ui.overlay === 'quick') {
        regions.set('quick-results', renderQuickResults(context));
    }

    switch (state.view) {
        case 'working':
            regions.set('middle', banner + renderWorkingColumn(context));
            regions.set('counter', renderCounter(context));
            regions.set('body-bar', renderBodyBar(context));
            regions.set('commit-actions', renderCommitActions(context));
            regions.set('files', renderFiles(context));
            regions.set('detail', renderWorkingDiff(context));
            break;
        case 'history':
            regions.set('middle', banner + renderHistoryColumn(context));
            regions.set('history-bar', renderHistoryBar(context));
            regions.set('history-list', renderHistoryList(context));
            regions.set('detail', renderCommitDetail(context));
            break;
        default:
            regions.set('middle', banner + renderStashColumn(context));
            regions.set('detail', renderStashDetail(context));
    }

    return regions;
}

/** 把一个区域里的占位标记逐层换成子区域的内容。 */
export function compose(regions: Regions, name: string): string {
    const html = regions.get(name) ?? '';

    return html.replace(/\u0000([a-z-]+)\u0000/g, (_match, child: string) => compose(regions, child));
}

/** 每个区域的父区域：从占位标记里读出来，浏览器据此只替换最外层变了的区域。 */
export function parents(regions: Regions): Map<string, string> {
    const result = new Map<string, string>();

    for (const [name, html] of regions) {
        for (const match of html.matchAll(/\u0000([a-z-]+)\u0000/g)) {
            result.set(match[1] ?? '', name);
        }
    }

    return result;
}

/**
 * 窗口的骨架：红绿灯、侧边栏、工具栏、中间一栏、右边一栏与浮层。
 *
 * 极窄版式里多出视图导航，侧边栏盖在主视图上时垫一层遮罩，点遮罩收起侧边栏。
 */
function windowFrame({ text }: RenderContext): string {
    const light = (kind: string) =>
        `<button type="button" class="sd-light sd-light-${kind}" data-action="unavailable" ` +
        `tabindex="-1" aria-hidden="true"></button>`;

    return (
        `<span class="sd-lights">${light('close')}${light('minimize')}${light('zoom')}</span>` +
        `<button type="button" class="sd-drawer-scrim" data-action="toggle-sidebar" ` +
        `tabindex="-1" aria-hidden="true"></button>` +
        slot('sidebar', 'aside', `class="sd-sidebar" aria-label="${esc(text.t('workspace.group'))}"`) +
        `<div class="sd-toolbar">` +
        slot('title', 'div', 'class="sd-titlebar"') +
        slot('actions', 'div', 'class="sd-actions-bar"') +
        `</div>` +
        slot('nav', 'nav', `class="sd-compact-nav" aria-label="${esc(text.t('workspace.group'))}"`) +
        slot('middle', 'div', 'class="sd-middle"') +
        slot('detail', 'div', 'class="sd-detail"') +
        slot('overlay', 'div', 'class="sd-overlay"')
    );
}
