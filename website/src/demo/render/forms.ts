import type { DemoKey } from '../text.ts';
import type { DemoForm, RenderContext } from './context.ts';
import { button, esc } from './format.ts';

/** 对话框的内容与确认按钮，表单由窗口统一提交。 */
interface Sheet {
    action: DemoForm;
    title: string;
    message: string;
    fields?: string;
    submit: DemoKey;
}

/** 应用式表单共用的标题、图标与按钮行。 */
export function formSheet({ appIcon, text }: RenderContext, sheet: Sheet): string {
    return (
        `<button type="button" class="sd-scrim" data-action="close" tabindex="-1" aria-hidden="true"></button>` +
        `<form class="sd-sheet sd-demo-form" data-demo-form="${sheet.action}" role="dialog" aria-modal="true" ` +
        `aria-labelledby="sd-form-title" aria-describedby="sd-form-message">` +
        `<img class="sd-sheet-icon" src="${esc(appIcon)}" alt="">` +
        `<div class="sd-sheet-text"><h3 id="sd-form-title">${esc(sheet.title)}</h3>` +
        `<p id="sd-form-message">${esc(sheet.message)}</p></div>` +
        `<div class="sd-form-fields">${sheet.fields ?? ''}</div>` +
        `<div class="sd-sheet-buttons">` +
        button({ action: 'close', className: 'sd-button', content: esc(text.t('action.cancel')) }) +
        `<button class="sd-button sd-default" type="submit">${esc(text.t(sheet.submit))}</button></div></form>`
    );
}

/** 一个表单控件的名字在标签内，用于描述选项或文本框。 */
export function formField(label: string, input: string): string {
    return `<label class="sd-form-field"><span>${esc(label)}</span>${input}</label>`;
}

/** 本机位置、分支等表单里的原生选项。 */
export function formOption(value: string, label = value, selected = false): string {
    return `<option value="${esc(value)}"${selected ? ' selected' : ''}>${esc(label)}</option>`;
}
