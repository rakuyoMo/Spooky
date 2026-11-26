import type { DemoKey } from '../text.ts';
import type { RenderContext } from './context.ts';
import { locationMethods, settingsPages } from './context.ts';
import { button, esc, icon } from './format.ts';
import { formField, formOption, formSheet } from './forms.ts';

/** 仓库设置的页签与设置表格。 */
export function renderSettings(context: RenderContext): string {
    const { data, text, ui } = context;
    const tabs = settingsPages.map((page) => button({
        action: 'settings-page',
        arg: page,
        className: `sd-segment${ui.settingsPage === page ? ' is-on' : ''}`,
        content: esc(text.t(`repositorySettings.${page}`)),
        pressed: ui.settingsPage === page,
    })).join('');

    return (
        `<div class="sd-detail-head sd-settings-head">${icon('gear')}<span>${esc(data.repository)}</span>` +
        `<div class="sd-segments" aria-label="${esc(text.t('repositorySettings.title'))}">${tabs}</div></div>` +
        `<div class="sd-detail-scroll sd-settings-body" data-scroll="settings:${ui.settingsPage}">` +
        settingsContents(context) +
        `</div>`
    );
}

/** 本机位置表单：不同方法决定是否要给出文件夹，以及确认按钮的动作。 */
export function renderLocationForm(context: RenderContext): string {
    const { data, text, ui } = context;
    const method = ui.locationMethod;
    const options = locationMethods.map((option) =>
        formOption(option, text.t(`localLocation.method.${option}`), method === option),
    ).join('');
    const picker = formField(
        text.t('localLocation.method'),
        `<select name="method" data-form-field="method">${options}</select>`,
    );

    const showsFolder = method === 'sshfsMount' || method === 'chosenFolder';
    const currentFolder = method === ui.location.method ? ui.location.folder : '';
    const folder = showsFolder ? formField(
        text.t(method === 'sshfsMount' ? 'localLocation.mountAt' : 'localLocation.folder'),
        `<input name="folder" data-form-field="folder" placeholder="~/${esc(data.repository)}" ` +
        `value="${esc(currentFolder)}" required>`,
    ) : '';

    return formSheet(context, {
        action: 'location',
        title: text.t('localLocation.title'),
        message: text.t('localLocation.message', data.repository),
        fields: picker + folder,
        submit: method === 'smbMount' || method === 'sshfsMount' ? 'localLocation.mount' : 'localLocation.save',
    });
}

/** 常规页列出示例仓库的身份和挂载位置，其余页展示各自的规则。 */
function settingsContents({ data, text, ui }: RenderContext): string {
    const location = ui.location;
    const path = `/srv/git/${data.repository}`;

    switch (ui.settingsPage) {
        case 'general': {
            const change = button({
                action: 'show-form',
                arg: 'location',
                className: 'sd-button',
                content: esc(text.t('localLocation.change')),
            });
            const method = text.t(`localLocation.method.${location.method}`);
            const value = location.folder || text.t('localLocation.notMounted');

            return (
                group('repositorySettings.general') +
                row('repositorySettings.name', data.repository) +
                row('repositorySettings.path', `${data.host}:${path}`) +
                row('repositorySettings.localLocation', text.t('localLocation.value', method, value), change) +
                row('bookmarks.detail.identity', `${data.identity.name} <${data.identity.email}>`) +
                group('repositorySettings.signing') +
                row('repositorySettings.signCommits', text.t('bookmarks.detail.unset'))
            );
        }
        case 'lfs':
            return group('repositorySettings.lfs.patterns');
        case 'ignores':
            return group('repositorySettings.ignores') + '<code>node_modules/</code><code>dist/</code>';
        case 'excludes':
            return group('repositorySettings.excludes');
    }

    /** 设置分组的标题行。 */
    function group(key: DemoKey): string {
        return `<h3 class="sd-settings-group">${esc(text.t(key))}</h3>`;
    }

    /** 一项设置的名称、值与可选操作。 */
    function row(key: DemoKey, value: string, action = ''): string {
        return (
            `<div class="sd-settings-row"><span>${esc(text.t(key))}</span>` +
            `<span class="sd-settings-value">${esc(value)}</span>${action}</div>`
        );
    }
}
