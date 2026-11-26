import type { IconName } from '../icons.ts';
import { headBranch } from '../model.ts';
import type { RenderContext } from './context.ts';
import { button, esc, icon } from './format.ts';

/**
 * 侧边栏：工作空间的几个视图、分支、标签与远端；点视图切换主区域，点分支、标签与远端分支看它的历史。
 * 极窄版式里换成一行视图导航，侧边栏由导航开头的按钮显示或收起。
 */

/** 侧边栏里的一行。 */
interface Row {
    icon: IconName;
    label: string;
    action: string;
    arg?: string | undefined;
    selected: boolean;
    depth?: number | undefined;
    badge?: string | undefined;
    trailing?: string | undefined;
}

/** 侧边栏的全部内容。 */
export function renderSidebar(context: RenderContext): string {
    const { text } = context;

    return (
        `<div class="sd-side-top">` +
        button({
            action: 'unavailable',
            className: 'sd-glass sd-round sd-bookmarks',
            content: icon('drive'),
            label: text.t('toolbar.bookmarks'),
            item: 'bookmarks',
        }) +
        `</div>` +
        `<nav class="sd-side-list" data-scroll="sidebar" aria-label="${esc(text.t('workspace.group'))}">` +
        sideList(context) +
        `</nav>` +
        `<div class="sd-side-bottom">` +
        button({
            action: 'unavailable',
            className: 'sd-plain',
            content: icon('activity'),
            label: text.t('activity.title'),
        }) +
        `<span class="sd-spacer"></span>` +
        button({
            action: 'unavailable',
            className: 'sd-plain',
            content: icon('plus'),
            label: text.t('reference.addMenu'),
        }) +
        button({
            action: 'unavailable',
            className: 'sd-plain',
            content: icon('sliders'),
            label: text.t('sidebar.viewSettings'),
        }) +
        `</div>`
    );
}

/**
 * 极窄版式顶部的视图导航：开头的按钮显示或收起侧边栏，后面是工作区、历史与储藏。
 *
 * 看某个引用的历史时，历史一项同样算所在的视图。
 */
export function renderCompactNav({ state, text, ui }: RenderContext): string {
    const entry = (view: string, image: IconName, label: string, badge = '') =>
        button({
            action: 'view',
            arg: view,
            className: `sd-compact-entry${state.view === view ? ' is-selected' : ''}`,
            content: `${icon(image)}<span class="sd-row-label">${esc(label)}</span>${badge}`,
            pressed: state.view === view,
        });

    const count = state.files.length > 0 ? `<span class="sd-badge">${state.files.length}</span>` : '';

    return (
        button({
            action: 'toggle-sidebar',
            className: 'sd-compact-toggle',
            content: icon('sidebar'),
            label: text.t('sidebar.menu'),
            pressed: ui.sidebarOpen,
        }) +
        entry('working', 'folder', text.t('workspace.title'), count) +
        entry('history', 'clock', text.t('history.title')) +
        entry('stashes', 'tray', text.t('stash.title'))
    );
}

// MARK: - Groups

/**
 * 侧边栏的各组。
 *
 * 整个列表只占一个 Tab 位置，落在选中的行上，行间用方向键移动；选中的行收在折叠的文件夹里时落在第一行。
 */
function sideList(context: RenderContext): string {
    const rows =
        workspace(context) +
        branches(context) +
        `<p class="sd-side-head">${esc(context.text.t('sidebar.archived'))}</p>` +
        tags(context) +
        remotes(context);

    return rows.includes('tabindex="0"') ? rows : rows.replace('tabindex="-1"', 'tabindex="0"');
}

/** 工作空间：工作区、历史、储藏，以及请求、分支整理与仓库设置。 */
function workspace({ state, text }: RenderContext): string {
    const viewing = (view: string) => state.view === view && (view !== 'history' || state.historyRef === null);

    const rows: Row[] = [
        {
            icon: 'folder',
            label: text.t('workspace.title'),
            action: 'view',
            arg: 'working',
            selected: viewing('working'),
            badge: state.files.length > 0 ? String(state.files.length) : undefined,
        },
        { icon: 'clock', label: text.t('history.title'), action: 'view', arg: 'history', selected: viewing('history') },
        { icon: 'tray', label: text.t('stash.title'), action: 'view', arg: 'stashes', selected: viewing('stashes') },
        { icon: 'pullRequest', label: text.t('pr.title'), action: 'view', arg: 'requests', selected: viewing('requests') },
        { icon: 'review', label: text.t('review.title'), action: 'unavailable', selected: false },
        {
            icon: 'gear',
            label: text.t('repositorySettings.title'),
            action: 'view',
            arg: 'settings',
            selected: viewing('settings'),
        },
    ];

    return group(text.t('workspace.group'), rows.map(row));
}

/** 分支：HEAD 所在的分支带 HEAD 与领先数，`feature/` 下的分支收在一个文件夹里。 */
function branches(context: RenderContext): string {
    const { state, text } = context;
    const head = headBranch(state);
    const ahead =
        head.ahead > 0
            ? `<i></i><span aria-label="${esc(text.t('branch.ahead', head.ahead))}">↑${head.ahead}</span>`
            : '';

    const top = state.branches.filter((branch) => !branch.name.startsWith('feature/'));
    const grouped = state.branches.filter((branch) => branch.name.startsWith('feature/'));

    const rows = top.map((branch) =>
        row({
            icon: 'branch',
            label: branch.name,
            action: 'ref',
            arg: `refs/heads/${branch.name}`,
            selected: isRef(context, `refs/heads/${branch.name}`),
            trailing:
                branch.name === head.name
                    ? `<span class="sd-badge sd-badge-split">HEAD${ahead}</span>`
                    : undefined,
        }),
    );

    const folder = disclosure(context, 'feature', 'feature', 'folder', 0);
    const children = grouped.map((branch) =>
        row({
            icon: 'branch',
            label: branch.name.slice('feature/'.length),
            action: 'ref',
            arg: `refs/heads/${branch.name}`,
            selected: isRef(context, `refs/heads/${branch.name}`),
            depth: 1,
        }),
    );

    return group(text.t('branch.group'), [...rows, folder, ...(isOpen(context, 'feature') ? children : [])]);
}

/** 标签。 */
function tags(context: RenderContext): string {
    const rows = context.data.tags.map((tag) =>
        row({
            icon: 'tag',
            label: tag.name,
            action: 'ref',
            arg: `refs/tags/${tag.name}`,
            selected: isRef(context, `refs/tags/${tag.name}`),
        }),
    );

    return group(context.text.t('sidebar.tags'), rows);
}

/** 远端：`origin` 下是它的分支，远端的 HEAD 指着的分支后面画一座房子。 */
function remotes(context: RenderContext): string {
    const { state, data, text } = context;
    const remote = data.remoteHead.split('/')[0] ?? 'origin';
    const names = state.remoteBranches.map((branch) => branch.name.slice(remote.length + 1));

    const leaf = (name: string, depth: number, label: string) =>
        row({
            icon: 'branch',
            label,
            action: 'ref',
            arg: `refs/remotes/${remote}/${name}`,
            selected: isRef(context, `refs/remotes/${remote}/${name}`),
            depth,
            trailing:
                `${remote}/${name}` === data.remoteHead
                    ? `<span class="sd-trailing-icon" title="${esc(text.t('branch.default'))}">${icon('house')}</span>`
                    : undefined,
        });

    const rows = [disclosure(context, remote, remote, 'globe', 0)];

    if (isOpen(context, remote)) {
        rows.push(...names.filter((name) => !name.includes('/')).map((name) => leaf(name, 1, name)));
        rows.push(disclosure(context, `${remote}/feature`, 'feature', 'folder', 1));

        if (isOpen(context, `${remote}/feature`)) {
            const nested = names.filter((name) => name.startsWith('feature/'));

            rows.push(...nested.map((name) => leaf(name, 2, name.slice('feature/'.length))));
        }
    }

    return group(text.t('remote.group'), rows);
}

// MARK: - Private

/** 一组：灰色小标题与下面的行。 */
function group(title: string, rows: string[]): string {
    return `<p class="sd-side-head">${esc(title)}</p><ul role="list">${rows.join('')}</ul>`;
}

/** 一行：图标、名字与右侧的徽标或图标。 */
function row(item: Row): string {
    const badge = item.badge ? `<span class="sd-badge">${esc(item.badge)}</span>` : '';
    const content =
        `${icon(item.icon)}<span class="sd-row-label">${esc(item.label)}</span>${badge}${item.trailing ?? ''}`;

    return (
        `<li style="--depth:${item.depth ?? 0}">` +
        button({
            action: item.action,
            arg: item.arg,
            className: `sd-row${item.selected ? ' is-selected' : ''}`,
            content,
            pressed: item.action === 'unavailable' ? undefined : item.selected,
            tabIndex: item.selected ? 0 : -1,
        }) +
        `</li>`
    );
}

/** 能展开、收起的文件夹或远端。 */
function disclosure(context: RenderContext, key: string, label: string, image: IconName, depth: number): string {
    const open = isOpen(context, key);

    return (
        `<li style="--depth:${depth}">` +
        `<button type="button" class="sd-row sd-folder" data-action="toggle-group" data-arg="${esc(key)}" ` +
        `aria-expanded="${open}" tabindex="-1">` +
        `${icon(open ? 'chevronDown' : 'chevronRight', 'sd-icon sd-chevron')}${icon(image)}` +
        `<span class="sd-row-label">${esc(label)}</span></button></li>`
    );
}

/** 文件夹是否展开着。 */
function isOpen(context: RenderContext, key: string): boolean {
    return !context.ui.closedGroups.includes(key);
}

/** 历史正只看这个引用。 */
function isRef(context: RenderContext, ref: string): boolean {
    return context.state.view === 'history' && context.state.historyRef === ref;
}
