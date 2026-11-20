/**
 * 示例仓库里几种文件的语法着色：TypeScript、CSS、JSON 与 Markdown。
 *
 * 记号分类与 App 的主题一一对应，样式类名见 `demo.css` 里的 `.sd-code` 一节；
 * 逐行处理，跨行的块注释、模板字符串与 Markdown 的代码块由传入的状态接着上一行。
 * 每行切成带类别的片段，渲染时还要在片段上叠加行内改动的高亮。
 */

/** 记号类别对应的样式类名。 */
type Token = 'k' | 'i' | 'f' | 'n' | 's' | 'c' | 'a' | 'sel' | 'h' | 'em' | 'st' | 'cb' | 'u' | 'y' | 'p';

/** 跨行的状态。 */
interface LineState {
    comment: boolean;
    template: boolean;
    braces: number;
    fence: boolean;
}

/** 一行里的一段文字与它的类别；`null` 是不着色的文字。 */
export type Piece = [token: Token | null, text: string];

/** 支持的语言。 */
type Language = 'ts' | 'css' | 'json' | 'md' | 'plain';

/** 着成关键字颜色的词：TypeScript 的关键字、内置类型名与字面量。 */
const keywords = new Set(
    (
        'break case catch class const continue debugger default delete do else export extends finally for function ' +
        'if import in instanceof new return switch throw try typeof var void while with yield let static enum await ' +
        'async of implements interface package private protected public type declare namespace module abstract ' +
        'readonly as from keyof infer is satisfies string number boolean any unknown never object symbol bigint ' +
        'true false null undefined NaN Infinity'
    ).split(' '),
);

/** CSS 花括号外的一个记号：at 规则、选择器与标签名。 */
const cssSelectorToken = /^(?:@[\w-]+|[.#:]{1,2}[\w-]+|[a-z][\w-]*)/;

/** CSS 花括号里的一个记号：自定义属性、属性名、颜色、数值、函数名与字符串。 */
const cssValueToken =
    /^(?:--[\w-]+(?=\s*:)|[a-z-]+(?=\s*:)|#[\da-fA-F]{3,8}\b|-?\d*\.?\d+(?:%|[a-z]+)?|[\w-]+(?=\()|"[^"]*"|'[^']*')/;

/** JSON 的记号：字符串（后面跟冒号的是键）、数字与字面量。 */
const jsonToken = /("(?:\\.|[^"\\])*")(?=(\s*:)?)|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|\b(true|false|null)\b/g;

/** 按文件名取语言。 */
export function languageOf(path: string): Language {
    const extension = /\.([a-z]+)$/.exec(path)?.[1] ?? '';

    if (['ts', 'tsx', 'js', 'jsx', 'mjs'].includes(extension)) {
        return 'ts';
    }

    if (extension === 'css' || extension === 'json' || extension === 'md') {
        return extension;
    }

    return 'plain';
}

/** 把一组连续的行着色，返回每行的片段。 */
export function highlightLines(lines: readonly string[], path: string): Piece[][] {
    const language = languageOf(path);
    const state: LineState = { comment: false, template: false, braces: 0, fence: false };

    return lines.map((text) => {
        switch (language) {
            case 'ts':
                return script(text, state);
            case 'css':
                return css(text, state);
            case 'json':
                return json(text);
            case 'md':
                return markdown(text, state);
            default:
                return [[null, text]];
        }
    });
}

/** 转义 HTML 的特殊字符。 */
export function escapeHtml(text: string): string {
    const entities: Record<string, string> = { '&': 'amp', '<': 'lt', '>': 'gt', '"': 'quot' };

    return text.replace(/[&<>"]/g, (character) => `&${entities[character]};`);
}

// MARK: - Rendering

/**
 * 把一行的片段写成 HTML；`marks` 是这一行改动部分的范围（按 UTF-16 偏移），落在其中的文字套上 `<mark>`。
 */
export function piecesHtml(pieces: readonly Piece[], marks: readonly [number, number][] = []): string {
    let html = '';
    let offset = 0;

    for (const [token, text] of pieces) {
        let start = 0;

        // 按改动范围的边界把一段切开
        while (start < text.length) {
            const position = offset + start;
            const inside = marks.find(([from, to]) => position >= from && position < to);
            const next = marks.flatMap(([from, to]) => [from, to]).filter((edge) => edge > position);
            const end = Math.min(text.length, (next.length > 0 ? Math.min(...next) : Infinity) - offset);
            const part = escapeHtml(text.slice(start, end));
            const colored = token === null ? part : `<span class="${token}">${part}</span>`;

            html += inside ? `<mark>${colored}</mark>` : colored;
            start = end;
        }

        offset += text.length;
    }

    return html;
}

// MARK: - Languages

/** TypeScript 与 JavaScript。 */
function script(text: string, state: LineState): Piece[] {
    const pieces: Piece[] = [];
    let index = 0;

    // 接着上一行没有结束的块注释或模板字符串
    if (state.comment || state.template) {
        const close = state.comment ? text.indexOf('*/') : findTemplateEnd(text, 0);
        const end = close < 0 ? text.length : close + (state.comment ? 2 : 1);

        pieces.push(span(state.comment ? 'c' : 's', text.slice(0, end)));
        index = end;

        if (close >= 0) {
            state.comment = false;
            state.template = false;
        }
    }

    while (index < text.length) {
        const rest = text.slice(index);
        const character = text[index] ?? '';

        if (rest.startsWith('//')) {
            pieces.push(span('c', rest));
            break;
        }

        if (rest.startsWith('/*')) {
            const close = text.indexOf('*/', index + 2);
            const end = close < 0 ? text.length : close + 2;

            pieces.push(span('c', text.slice(index, end)));
            state.comment = close < 0;
            index = end;
            continue;
        }

        if (character === '`') {
            const close = findTemplateEnd(text, index + 1);
            const end = close < 0 ? text.length : close + 1;

            pieces.push(span('s', text.slice(index, end)));
            state.template = close < 0;
            index = end;
            continue;
        }

        if (character === '"' || character === "'") {
            const end = quotedEnd(text, index);

            pieces.push(span('s', text.slice(index, end)));
            index = end;
            continue;
        }

        const number = /^(?:0x[\da-fA-F]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?n?)/.exec(rest);

        if (number && !/[\w$]/.test(text[index - 1] ?? '')) {
            pieces.push(span('n', number[0]));
            index += number[0].length;
            continue;
        }

        const word = /^[A-Za-z_$][\w$]*/.exec(rest);

        if (word) {
            pieces.push(wordToken(word[0], text.slice(index + word[0].length)));
            index += word[0].length;
            continue;
        }

        pieces.push([null, character]);
        index += 1;
    }

    return pieces;
}

/** CSS：大括号外是选择器，里面是属性与值。 */
function css(text: string, state: LineState): Piece[] {
    const pieces: Piece[] = [];
    let index = 0;

    if (state.comment) {
        const close = text.indexOf('*/');
        const end = close < 0 ? text.length : close + 2;

        pieces.push(span('c', text.slice(0, end)));
        index = end;
        state.comment = close < 0;
    }

    while (index < text.length) {
        const rest = text.slice(index);
        const character = text[index] ?? '';

        if (rest.startsWith('/*')) {
            const close = text.indexOf('*/', index + 2);
            const end = close < 0 ? text.length : close + 2;

            pieces.push(span('c', text.slice(index, end)));
            state.comment = close < 0;
            index = end;
            continue;
        }

        if (character === '{' || character === '}') {
            state.braces = Math.max(0, state.braces + (character === '{' ? 1 : -1));
            pieces.push([null, character]);
            index += 1;
            continue;
        }

        const match = (state.braces === 0 ? cssSelectorToken : cssValueToken).exec(rest);

        if (!match) {
            pieces.push([null, character]);
            index += 1;
            continue;
        }

        const value = match[0];
        const token: Token = state.braces === 0
            ? value.startsWith('@') ? 'k' : 'sel'
            : /^(?:--|[a-z-]+$)/.test(value) && /^\s*:/.test(text.slice(index + value.length))
                ? 'a'
                : /^["']/.test(value)
                    ? 's'
                    : /^[\w-]+$/.test(value) && text[index + value.length] === '('
                        ? 'k'
                        : 'n';

        pieces.push(span(token, value));
        index += value.length;
    }

    return pieces;
}

/** JSON：键、字符串、数字与字面量。 */
function json(text: string): Piece[] {
    return tokenize(text, jsonToken, (match) => {
        if (match[1] !== undefined) {
            return [span(match[2] === undefined ? 's' : 'a', match[1])];
        }

        return [span(match[3] === undefined ? 'k' : 'n', match[0])];
    });
}

/** Markdown：标题、列表记号、强调、行内代码、代码块与链接。 */
function markdown(text: string, state: LineState): Piece[] {
    if (/^\s*```/.test(text)) {
        state.fence = !state.fence;

        return [span('cb', text)];
    }

    if (state.fence) {
        return [span('cb', text)];
    }

    if (/^#{1,6}\s/.test(text)) {
        return [span('h', text)];
    }

    const bullet = /^(\s*)([-*+]|\d+\.)(\s+)/.exec(text);
    const head: Piece[] = bullet
        ? [[null, bullet[1] ?? ''], span('y', bullet[2] ?? ''), [null, bullet[3] ?? '']]
        : [];
    const body = bullet ? text.slice(bullet[0].length) : text;

    const inline = tokenize(
        body,
        /(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*\s][^*]*\*|_[^_\s][^_]*_)|\[([^\]]+)\]\(([^)]+)\)/g,
        (match): Piece[] => {
            if (match[1] !== undefined) {
                return [span('cb', match[1])];
            }

            if (match[2] !== undefined) {
                return [span('st', match[2])];
            }

            if (match[3] !== undefined) {
                return [span('em', match[3])];
            }

            return [
                [null, '['],
                span('s', match[4] ?? ''),
                [null, ']('],
                span('u', match[5] ?? ''),
                [null, ')'],
            ];
        },
    );

    return [...head, ...inline];
}

// MARK: - Private

/** 一个单词的记号：关键字、函数调用、属性名或首字母大写的类型名。 */
function wordToken(word: string, after: string): Piece {
    if (keywords.has(word)) {
        return span('k', word);
    }

    if (/^\s*\(/.test(after)) {
        return span('f', word);
    }

    if (/^\??:(?!:)/.test(after)) {
        return span('a', word);
    }

    if (/^[A-Z][a-z]/.test(word) || word === 'this' || word === 'super') {
        return span('i', word);
    }

    return [null, word];
}

/** 用一个全局正则切一行：匹配到的部分交给 `pick` 着色，其余是不着色的文字。 */
function tokenize(text: string, pattern: RegExp, pick: (match: RegExpExecArray) => Piece[]): Piece[] {
    const pieces: Piece[] = [];
    let last = 0;

    for (const match of text.matchAll(pattern)) {
        pieces.push([null, text.slice(last, match.index)], ...pick(match));
        last = match.index + match[0].length;
    }

    pieces.push([null, text.slice(last)]);

    return pieces.filter(([, part]) => part !== '');
}

/** 引号字符串的结束位置（不含）；没有结束时到行尾。 */
function quotedEnd(text: string, start: number): number {
    const quote = text[start];

    for (let index = start + 1; index < text.length; index += 1) {
        if (text[index] === '\\') {
            index += 1;
        } else if (text[index] === quote) {
            return index + 1;
        }
    }

    return text.length;
}

/** 模板字符串结束的反引号位置；没有时返回 −1。 */
function findTemplateEnd(text: string, start: number): number {
    for (let index = start; index < text.length; index += 1) {
        if (text[index] === '\\') {
            index += 1;
        } else if (text[index] === '`') {
            return index;
        }
    }

    return -1;
}

/** 一段带类别的文字。 */
function span(token: Token, text: string): Piece {
    return [token, text];
}
