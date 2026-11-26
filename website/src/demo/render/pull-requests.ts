import { changesOf } from '../model.ts';
import type { CommitData } from '../model.ts';
import type { PullRequest, RequestLabel } from '../pull-requests.ts';
import { availableSources, requestChanges, requestCommits, requestLabels, requestPages, visibleRequests } from '../pull-requests.ts';
import type { DemoForm, RenderContext } from './context.ts';
import { emptyState, renderChanges } from './diff.ts';
import { avatar, button, esc, formatDate, icon, subjectOf } from './format.ts';
import { formField, formOption, formSheet } from './forms.ts';

/** 远端、筛选与请求列表。 */
export function renderRequestList(context: RenderContext): string {
    const { text, ui } = context;
    const selected = ui.allRequests ? 'all' : 'open';
    const requests = visibleRequests(ui.requests, ui.allRequests);
    const create = button({
        action: 'show-form',
        arg: 'pr-create',
        className: 'sd-plain',
        content: icon('plus'),
        label: text.t('pr.create.menu'),
        disabled: availableSources(context.data, ui.requests).length === 0,
    });
    const filters = (['open', 'all'] as const).map((filter) => button({
        action: 'pr-filter',
        arg: filter,
        className: `sd-segment${selected === filter ? ' is-on' : ''}`,
        content: esc(text.t(`pullRequests.filter.${filter}`)),
        pressed: selected === filter,
    })).join('');

    const rows = requests.length === 0
        ? emptyState(text.t('pr.empty.title'), 'pullRequest')
        : requests.map((request) => requestRow(context, request)).join('');

    return (
        `<div class="sd-bar sd-request-bar">${icon('globe')}<span>origin</span>` +
        `<div class="sd-segments" role="group" aria-label="${esc(text.t('pr.stateFilter'))}">${filters}</div>` +
        `${create}</div><div class="sd-request-list" data-scroll="requests">${rows}</div>`
    );
}

/** 选中的请求及四个详情分段，底栏放检出、关闭和合并。 */
export function renderRequestDetail(context: RenderContext): string {
    const { text, ui } = context;
    const request = ui.requests.find(({ id }) => id === ui.requestId);

    if (!request) {
        return emptyState(text.t('pr.noSelection'), 'pullRequest');
    }

    const tabs = requestPages.map((page) => button({
        action: 'pr-page',
        arg: page,
        className: `sd-segment${ui.requestPage === page ? ' is-on' : ''}`,
        content: esc(text.t(`pullRequests.${page}`)),
        pressed: ui.requestPage === page,
    })).join('');
    const actions = (['checkout', 'close', 'merge'] as const).map((action) => button({
        action: 'show-form',
        arg: `pr-${action}`,
        className: 'sd-button',
        content: esc(text.t(`pullRequests.${action}`)),
        disabled: action !== 'checkout' && request.status !== 'open',
    })).join('');

    return (
        `<div class="sd-detail-head sd-request-head"><code>#${request.id}</code>` +
        `<div class="sd-segments" role="group" aria-label="${esc(text.t('pr.title'))}">${tabs}</div></div>` +
        `<div class="sd-detail-scroll sd-request-detail" data-scroll="pr:${request.id}:${ui.requestPage}">` +
        requestContents(context, request) +
        `</div><div class="sd-request-actions">${actions}</div>`
    );
}

/** 创建、编辑、评论、检出、关闭与合并的表单。 */
export function renderRequestForm(context: RenderContext, action: DemoForm): string {
    const { data, text, ui } = context;
    const service = 'GitHub';
    const request = ui.requests.find(({ id }) => id === ui.requestId);
    const reference = request ? `#${request.id}` : '';

    const titleField = formField(
        text.t('pullRequests.titleField'),
        `<input name="title" data-form-field="title" value="${esc(action === 'pr-edit' ? request?.title ?? '' : '')}" required>`,
    );
    const description = formField(
        text.t('pullRequests.description'),
        `<textarea name="description" data-form-field="description" rows="4">` +
        `${esc(action === 'pr-edit' ? request?.description ?? '' : '')}</textarea>`,
    );

    switch (action) {
        case 'pr-create': {
            const sources = availableSources(data, ui.requests).map((source) => formOption(source)).join('');
            const source = formField(
                text.t('pullRequests.source'),
                `<select name="source" data-form-field="source">${sources}</select>`,
            );
            const target = formField(text.t('pullRequests.target'), `<span>${esc(data.remoteHead)}</span>`);

            return formSheet(context, {
                action,
                title: text.t('pr.create.title', service),
                message: text.t('pr.create.message', service, data.repository),
                fields: source + target + titleField + description,
                submit: 'pr.create.submit',
            });
        }
        case 'pr-edit':
            return formSheet(context, {
                action,
                title: text.t('pr.edit.title', service, reference),
                message: text.t('pr.edit.message', reference, service, data.repository),
                fields: titleField + description,
                submit: 'pullRequests.save',
            });
        case 'pr-comment':
            return formSheet(context, {
                action,
                title: text.t('pr.comment.title', service),
                message: text.t('pr.comment.message', reference, service),
                fields: formField(
                    text.t('pullRequests.comment'),
                    '<textarea name="comment" data-form-field="comment" rows="4" required></textarea>',
                ),
                submit: 'pullRequests.addComment',
            });
        case 'pr-checkout':
            return formSheet(context, {
                action,
                title: text.t('pr.checkout.title'),
                message: text.t('pullRequests.checkout.message', request?.source ?? ''),
                fields: formField(
                    text.t('pullRequests.branchName'),
                    `<input name="branch" data-form-field="branch" value="${esc(request?.source ?? '')}" required>`,
                ),
                submit: 'pullRequests.checkout',
            });
        case 'pr-close':
            return formSheet(context, {
                action,
                title: text.t('pr.close.title', service),
                message: text.t('pr.close.message', reference, service),
                submit: 'pr.close.submit',
            });
        case 'pr-merge':
            return formSheet(context, {
                action,
                title: text.t('pr.accept.title', service),
                message: text.t('pr.accept.message', reference),
                submit: 'pr.accept.submit',
            });
        default:
            return '';
    }
}

/** 请求行的状态、作者、时间、源与目标。 */
function requestRow({ data, text, ui }: RenderContext, request: PullRequest): string {
    const selected = ui.requestId === request.id;
    const checks = esc(text.t('pullRequests.checks.status', text.t('pullRequests.checks.state.success')));

    return button({
        action: 'pr-select',
        arg: String(request.id),
        className: `sd-request-row${selected ? ' is-selected' : ''}`,
        content:
            `<strong>${requestStatus(request, text)}${esc(request.title)}` +
            `<span class="sd-pr-check" role="img" title="${checks}" aria-label="${checks}">${icon('check')}</span></strong>` +
            `<small>#${request.id} · ${esc(request.author)} · ${esc(requestDate(request.date, text.lang))}</small>` +
            `<small><bdi>${esc(request.source)} → ${esc(data.remoteHead.split('/').slice(1).join('/'))}</bdi></small>` +
            (request.labels.length > 0 ? `<span class="sd-pr-labels">${request.labels.map((label) => labelChip(label)).join('')}</span>` : ''),
        pressed: selected,
    });
}

/** 详情分段共用提交列表与 Diff，切换请求后仍能浏览它的实际示例补丁。 */
function requestContents(context: RenderContext, request: PullRequest): string {
    const { data, state, text, ui, changes } = context;
    const commits = requestCommits(data, request);

    switch (ui.requestPage) {
        case 'conversation':
            return renderConversation(context, request, commits);
        case 'commits': {
            const selected = commits.find(({ hash }) => hash === ui.requestCommit) ?? commits[0];
            const authors = [...new Set(commits.map((commit) => commit.author[0]))];
            const summary = `<div class="sd-pr-summary">${esc(text.count('pullRequests.contributors', authors.length))}` +
                `${authors.map((author) => avatar(author, 20)).join('')}` +
                `<span class="sd-spacer"></span>${esc(text.t('pullRequests.contributors.commits', commits.length))}</div>`;
            const rows = commits.map((commit) => commitRow(context, commit, commit.hash === selected?.hash)).join('');
            const files = selected && changes ? changesOf(state, changes, selected.hash) : null;

            return summary + `<div class="sd-pr-commits">${rows}</div>` +
                (files && selected ? `<div class="sd-changes">${renderChanges(context, files, selected.hash)}</div>` : '');
        }
        case 'changeset':
            return changes
                ? `<div class="sd-changes">${renderChanges(context, requestChanges(data, request, changes), `pr:${request.id}`)}</div>`
                : `<p class="sd-loading">${esc(text.t('history.loadingChanges'))}</p>`;
        case 'checks':
            return renderChecks(context);
    }
}

/** 讨论以说明开头，再按时间列出源分支的提交和评论。 */
function renderConversation(context: RenderContext, request: PullRequest, commits: CommitData[]): string {
    const { data, text } = context;
    const target = data.remoteHead.split('/').slice(1).join('/');
    const edit = button({
        action: 'show-form', arg: 'pr-edit', className: 'sd-button', content: esc(text.t('pullRequests.edit')),
    });
    const comment = button({
        action: 'show-form', arg: 'pr-comment', className: 'sd-button', content: esc(text.t('pullRequests.addComment')),
    });
    const author = text.t('pr.description.title', request.author, requestDate(request.date, text.lang));
    const timeline = [
        ...request.comments.map((item) => ({
            date: item.date,
            html: conversationRow(
                item.author,
                text.t('pullRequests.comment.commented', item.author, requestDate(item.date, text.lang)),
                item.body,
            ),
        })),
        ...commits.map((commit) => ({ date: commit.author[2], html: commitRow(context, commit) })),
    ].sort((a, b) => a.date - b.date);

    return (
        `<div class="sd-pr-conversation"><header><h3>${requestStatus(request, text)}${esc(request.title)}</h3>${edit}</header>` +
        `<p class="sd-pr-direction">${esc(text.t('pullRequests.header.info',
            request.author, text.count('pullRequests.header.commits', commits.length), target, request.source))}</p>` +
        renderLabels(context, request) +
        conversationRow(request.author, author, request.description || text.t('pullRequests.noDescription')) +
        timeline.map(({ html }) => html).join('') +
        `<div class="sd-pr-comment-action">${comment}</div></div>`
    );
}

/** 讨论顶部的标签以及同一项目内可以添加的标签。 */
function renderLabels({ text }: RenderContext, request: PullRequest): string {
    const remaining = (Object.keys(requestLabels) as RequestLabel[]).filter((label) => !request.labels.includes(label));
    const assigned = request.labels.map((label) => button({
        action: 'pr-label',
        arg: label,
        className: 'sd-pr-remove-label',
        content: labelChip(label, ' ×'),
        label: text.t('pullRequests.removeLabel.title', label),
    })).join('');
    const add = remaining.length > 0 ?
        `<details><summary>${esc(text.t('pullRequests.labels.add'))}</summary><div>` +
        remaining.map((label) => button({
            action: 'pr-label',
            arg: label,
            className: 'sd-button',
            content: esc(label),
            label: text.t('pullRequests.addLabel.title', label),
        })).join('') + `</div></details>` : '';

    return `<div class="sd-pr-labels"><span>${esc(text.t('pullRequests.header.labels'))}</span>${assigned}${add}</div>`;
}

/** 项目标签在列表与讨论里的颜色相同。 */
function labelChip(label: RequestLabel, suffix = ''): string {
    return `<span class="sd-pr-label" style="--sd-pr-label:${requestLabels[label]}">${esc(label + suffix)}</span>`;
}

/** 说明和评论共享头像、作者与正文的排版。 */
function conversationRow(author: string, heading: string, body: string): string {
    return `<article class="sd-pr-comment">${avatar(author, 24)}<div><b>${esc(heading)}</b><p>${esc(body)}</p></div></article>`;
}

/** 点提交可查看该提交的文件；讨论里也能从同一行跳到提交段。 */
function commitRow({ text }: RenderContext, commit: CommitData, selected?: boolean): string {
    return button({
        action: 'pr-commit',
        arg: commit.hash,
        className: `sd-pr-commit${selected ? ' is-selected' : ''}`,
        content: `${avatar(commit.author[0], 24)}<span><b>${esc(subjectOf(commit.message))}</b>` +
            `<small>${esc(commit.author[0])} · ${esc(formatDate(commit.author, 'short', text.lang))}</small></span>` +
            `<code>${commit.hash.slice(0, 8)}</code>`,
        pressed: selected,
    });
}

/** CI/CD 的整体结果与逐项日志，保留构建系统输出的原文。 */
function renderChecks({ text }: RenderContext): string {
    const status = text.t('pullRequests.checks.state.success');
    const jobs = [
        ['Build', 'npm run build\nBuild complete.'],
        ['Tests', 'npm test\nAll tests passed.'],
    ];

    return (
        `<div class="sd-pr-checks"><p>${icon('check')}${esc(text.t('pullRequests.checks.status', status))}</p>` +
        jobs.map(([job, log]) =>
            `<details><summary>${esc(job ?? '')}<span>${esc(status)}</span></summary><pre>${esc(log ?? '')}</pre></details>`,
        ).join('') + `</div>`
    );
}

/** 请求状态图标与辅助技术可读的状态名。 */
function requestStatus(request: PullRequest, text: RenderContext['text']): string {
    const label = esc(text.t(`pullRequests.state.${request.status}`));
    const image = request.status === 'merged' ? 'merge' : 'pullRequest';

    return `<span class="sd-pr-state sd-pr-${request.status}" role="img" aria-label="${label}" title="${label}">${icon(image)}</span>`;
}

/** 托管视图里的日期依页面语言显示。 */
function requestDate(date: number, lang: string): string {
    return new Intl.DateTimeFormat(lang, { dateStyle: 'medium' }).format(new Date(date * 1000));
}
