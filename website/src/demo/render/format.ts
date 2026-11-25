import { escapeHtml as esc } from '../highlight.ts';
import type { IconName } from '../icons.ts';
import { icons } from '../icons.ts';
import type { Person } from '../model.ts';

/**
 * 渲染共用的小工具：转义、图标、按钮、徽标、头像与日期。
 */

/** HTML 转义，渲染文件里用得多，写短一些。 */
export { esc };

/** 区域占位的标记：拼整窗时换成区域的内容。 */
export const regionMark = (name: string): string => `\u0000${name}\u0000`;

/**
 * 一个区域的容器：浏览器里按 `data-region` 找到它、只换它里面的内容。
 *
 * `attributes` 是容器上不随状态变化的属性。
 */
export function slot(name: string, tag: string, attributes = ''): string {
    return `<${tag} data-region="${name}"${attributes ? ` ${attributes}` : ''}>${regionMark(name)}</${tag}>`;
}

/** 图标。 */
export function icon(name: IconName, className = 'sd-icon'): string {
    return `<span class="${className}">${icons[name]}</span>`;
}

/**
 * 能点的按钮：`action` 是委托给控制器的动作，`arg` 是动作的参数。
 *
 * 只有图标的按钮必须给 `label`，作为它的名字与悬停提示；`tabIndex` 给一组只占一个 Tab 位置的按钮用。
 * `item` 是工具栏上一项的名字，`expanded` 给能打开菜单的按钮用。
 */
export function button(options: {
    action: string;
    arg?: string | undefined;
    className: string;
    content: string;
    label?: string | undefined;
    disabled?: boolean | undefined;
    pressed?: boolean | undefined;
    guide?: string | undefined;
    tabIndex?: number | undefined;
    item?: string | undefined;
    expanded?: boolean | undefined;
}): string {
    const attributes = [
        `type="button"`,
        `class="${options.className}"`,
        `data-action="${options.action}"`,
        options.arg === undefined ? '' : `data-arg="${esc(options.arg)}"`,
        options.label === undefined ? '' : `aria-label="${esc(options.label)}" title="${esc(options.label)}"`,
        options.disabled ? 'disabled' : '',
        options.pressed === undefined ? '' : `aria-pressed="${options.pressed}"`,
        options.guide === undefined ? '' : `data-guide="${options.guide}"`,
        options.tabIndex === undefined ? '' : `tabindex="${options.tabIndex}"`,
        options.item === undefined ? '' : `data-item="${options.item}"`,
        options.expanded === undefined ? '' : `aria-haspopup="menu" aria-expanded="${options.expanded}"`,
    ];

    return `<button ${attributes.filter(Boolean).join(' ')}>${options.content}</button>`;
}

/** 引用徽标：本地分支与 HEAD 蓝色、远端分支灰色、标签黄色、储藏红色；选中的提交行里一律用选中配色。 */
export function refBadge(name: string, kind: 'local' | 'remote' | 'tag' | 'head' | 'stash'): string {
    return `<span class="sd-ref sd-ref-${kind}">${esc(name)}</span>`;
}

/** 姓名的缩写：前两个词各取首字母并转成大写。 */
export function initials(name: string): string {
    return name
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((word) => (word[0] ?? '').toUpperCase())
        .join('');
}

/** 圆形头像：浅底上写姓名的缩写。 */
export function avatar(name: string, size: number): string {
    return `<span class="sd-avatar" style="--size:${size}px" aria-hidden="true">${esc(initials(name))}</span>`;
}

/** 提交日期的三种写法：列表里的短日期、详情里的长日期与时间、分组标题的月份。 */
export function formatDate(person: Person, style: 'short' | 'long' | 'month', lang: string): string {
    const date = new Date(person[2] * 1000);

    switch (style) {
        case 'short':
            return new Intl.DateTimeFormat(lang, { dateStyle: 'short' }).format(date);
        case 'long':
            return new Intl.DateTimeFormat(lang, { dateStyle: 'long', timeStyle: 'long' }).format(date);
        default:
            return new Intl.DateTimeFormat(lang, { month: 'long', year: 'numeric' })
                .format(date)
                .toLocaleUpperCase(lang);
    }
}

/** 提交信息的第一行。 */
export function subjectOf(message: string): string {
    return message.split('\n', 1)[0] ?? '';
}

/** 去掉第一行与之后的空行，剩下的正文。 */
export function bodyOf(message: string): string {
    return message.split('\n').slice(1).join('\n').replace(/^\n+/, '');
}

/** 引用的短名：去掉 `refs/heads/` 这类前缀。 */
export function shortRef(ref: string): string {
    return ref.replace(/^refs\/(heads|remotes|tags)\//, '');
}

/**
 * 估算一段系统字体文字的宽度。
 *
 * 构建时与浏览器里都要用同一个结果决定提交行放几个引用徽标，所以按字符类别估算，不量实际排版。
 */
export function textWidth(text: string, size: number): number {
    let width = 0;

    for (const character of text) {
        if (/[⺀-鿿가-힯＀-￯]/u.test(character)) {
            width += 1;
        } else if (/[A-Z0-9]/.test(character)) {
            width += 0.62;
        } else if (/[ilj.,:;'!|/]/.test(character)) {
            width += 0.3;
        } else {
            width += 0.53;
        }
    }

    return width * size;
}
