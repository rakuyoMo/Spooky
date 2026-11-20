import { fileIcon } from '../icons.ts';
import type { WorkFile } from '../model.ts';
import {
    canCommit,
    fileBadges,
    fileCheck,
    hasStagedChanges,
    hasUnstagedChanges,
    headBranch,
    remainingCharacters,
} from '../model.ts';
import type { RenderContext } from './context.ts';
import { avatar, button, esc, icon, slot } from './format.ts';

/**
 * 工作区的中间一栏：连接横幅、分支栏、提交区与文件列表。
 *
 * 提交区里的两个输入框只随视图一起输出；剩余字数、正文框底下的按钮、提交按钮与文件列表是各自的区域，
 * 打字或点这些按钮时不重绘输入框。
 */

/** 中间一栏的骨架，里面的几个区域单独输出。 */
export function renderWorkingColumn(context: RenderContext): string {
    const { data, text } = context;

    const banner = `<p class="sd-banner">${esc(`${data.host}: ${text.t('connection.connected')}`)}</p>`;

    const filesHead =
        `<div class="sd-files-head" role="presentation">` +
        `<span>${esc(text.t('status.column'))}</span>` +
        `<span>${esc(text.t('status.filename'))}</span>` +
        icon('chevronUp', 'sd-icon sd-sort') +
        `</div>`;

    return (
        banner +
        branchBar(context) +
        commitForm(context) +
        `<div class="sd-files">` +
        filesHead +
        slot('files', 'ul', 'class="sd-file-list" role="list" data-scroll="files"') +
        `</div>`
    );
}

/** 标题框右端的剩余字数；标题与正文都空时不显示。 */
export function renderCounter({ state, text }: RenderContext): string {
    const remaining = remainingCharacters(state.subject, state.body);

    if (remaining === null) {
        return '';
    }

    return `<span aria-label="${esc(text.t('commit.remaining', remaining))}">${remaining}</span>`;
}

/** 正文框底下的一排按钮：固定展开、自动换行与拖动把手。 */
export function renderBodyBar({ ui, text }: RenderContext): string {
    return (
        button({
            action: 'pin',
            className: 'sd-plain',
            content: icon('pin'),
            label: text.t('commit.pin'),
            pressed: ui.pinned,
        }) +
        `<i class="sd-divider"></i>` +
        button({
            action: 'unavailable',
            className: 'sd-plain',
            content: icon('returnKey'),
            label: text.t('editor.wrapping'),
        }) +
        `<span class="sd-grip" aria-hidden="true">${icon('grip')}</span>`
    );
}

/** 全部暂存（全部暂存之后是全部取消暂存）与提交两个按钮。 */
export function renderCommitActions(context: RenderContext): string {
    const { state, text } = context;
    const unstageAll = hasStagedChanges(state) && !hasUnstagedChanges(state);

    return (
        button({
            action: unstageAll ? 'unstage-all' : 'stage-all',
            className: 'sd-button',
            content: esc(text.t(unstageAll ? 'working.unstageAll' : 'working.stageAll')),
            disabled: state.files.length === 0,
            guide: unstageAll ? undefined : 'stage',
        }) +
        button({
            action: 'commit',
            className: 'sd-button',
            content: esc(text.t('working.commit')),
            disabled: !canCommit(state),
            guide: 'commit',
        })
    );
}

/** 文件列表：勾选框、两枚状态徽标、文件图标与路径。 */
export function renderFiles(context: RenderContext): string {
    return context.state.files.map((file) => fileRow(context, file)).join('');
}

// MARK: - Private

/** 分支栏：当前分支、它的上游与右端的视图选项。 */
function branchBar(context: RenderContext): string {
    const { state, data, text } = context;
    const branch = headBranch(state, data);

    return (
        `<div class="sd-bar sd-branchbar">` +
        `<span class="sd-branch-name">${esc(branch.name)}</span>` +
        icon('chevronRight', 'sd-icon sd-branch-chevron') +
        `<span class="sd-branch-upstream">${esc(branch.upstream ?? '')}</span>` +
        button({
            action: 'unavailable',
            className: 'sd-plain sd-bar-end',
            content: icon('sliders'),
            label: text.t('working.viewMode'),
        }) +
        `</div>`
    );
}

/** 提交区：标题框，展开后的正文框、提交选项与身份，以及底下的一排按钮。 */
function commitForm({ data, text }: RenderContext): string {
    const subjectLabel = esc(text.t('working.subject'));
    const placeholder = `${text.t('working.body')}\n\n${text.t('commit.quickAmendHint')}`;

    const subject =
        `<label class="sd-field sd-subject">` +
        `<input data-input="subject" type="text" autocomplete="off" spellcheck="false" ` +
        `placeholder="${subjectLabel}" aria-label="${subjectLabel}" ` +
        `value="${esc(data.draft)}" data-guide="commit">` +
        slot('counter', 'span', 'class="sd-counter"') +
        `</label>`;

    const body =
        `<div class="sd-field sd-body">` +
        `<textarea data-input="body" spellcheck="false" ` +
        `placeholder="${esc(placeholder)}" aria-label="${esc(text.t('working.body'))}"></textarea>` +
        slot('body-bar', 'div', 'class="sd-body-bar"') +
        `</div>`;

    const identity =
        `<div class="sd-identity">` +
        `<p>${esc(data.identity.name)}<br>${esc(data.identity.email)}</p>` +
        avatar(data.identity.name, 44) +
        `</div>`;

    const options =
        `<div class="sd-options">` +
        `<div class="sd-checks">` +
        checkOption(text.t('working.amend')) +
        checkOption(text.t('commit.signOff')) +
        `</div>` +
        identity +
        `</div>`;

    return (
        `<form class="sd-commit" data-commit>` +
        subject +
        `<div class="sd-details">${body}${options}</div>` +
        slot('commit-actions', 'div', 'class="sd-commit-actions"') +
        `</form>`
    );
}

/** 一个文件行：勾选框管暂存，点其余地方选中文件。 */
function fileRow({ state, text }: RenderContext, file: WorkFile): string {
    const check = fileCheck(file);
    const badges = fileBadges(file);
    const selected = state.selectedPath === file.path;
    const path = esc(file.path);

    // 两枚标记共用一条说明：上一行是已暂存一侧，下一行是未暂存一侧；未跟踪的文件两行都写未跟踪
    const name = (letter: string | null) => {
        if (badges.unstaged === '?' && !badges.staged) {
            return text.t('status.untracked');
        }

        switch (letter) {
            case 'A':
                return text.t('status.added');
            case 'M':
                return text.t('status.modified');
            case '?':
                return text.t('status.untracked');
            default:
                return text.t('status.unchanged');
        }
    };

    const description = text.t('status.description', name(badges.staged), name(badges.unstaged));

    // 没有改动的一侧也输出一格，两枚徽标总在同一列
    const badge = (letter: string | null) => {
        if (!letter) {
            return '<b class="sd-st"></b>';
        }

        return `<b class="sd-st sd-st-${letter === '?' ? 'U' : letter}">${letter}</b>`;
    };

    const box =
        `<button type="button" role="checkbox" class="sd-check" ` +
        `data-action="toggle-file" data-arg="${path}" data-guide="stage" ` +
        `aria-checked="${check === 'mixed' ? 'mixed' : check === 'on'}" aria-label="${path}">` +
        checkMark(check) +
        `</button>`;

    const status =
        `<span class="sd-status" title="${esc(description)}">` +
        badge(badges.staged) +
        badge(badges.unstaged) +
        `</span>`;

    const label =
        `<button type="button" class="sd-file-name" ` +
        `data-action="select-file" data-arg="${path}" aria-current="${selected}">` +
        `<span class="sd-file-icon">${fileIcon(file.path)}</span>` +
        `<span>${path}</span>` +
        `</button>`;

    return (
        `<li class="sd-file${selected ? ' is-selected' : ''}" data-action="select-file" data-arg="${path}">` +
        box +
        status +
        label +
        `</li>`
    );
}

/** 勾选框里的记号：全选打勾，半选一道横线。 */
function checkMark(check: 'off' | 'mixed' | 'on'): string {
    if (check === 'off') {
        return '';
    }

    return icon(check === 'on' ? 'check' : 'dash', 'sd-icon sd-check-mark');
}

/** 提交选项的勾选框；演示里没有这两项，点了给提示。 */
function checkOption(label: string): string {
    return (
        `<button type="button" role="checkbox" aria-checked="false" ` +
        `class="sd-check-option" data-action="unavailable">` +
        `<span class="sd-check" aria-hidden="true"></span>` +
        esc(label) +
        `</button>`
    );
}
