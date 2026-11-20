/** 一种语言的 App 文案：资源键到文案。 */
export type AppStringTable = Record<string, string>;

/** 全部语言的 App 文案，以站点的语言代号为键。 */
export type AppStringTables = Record<string, AppStringTable>;

/**
 * 解析 `Localizable.strings`。
 *
 * 支持 `/* … *\/` 与 `//` 注释，以及 `\"`、`\\`、`\n`、`\t`、`\r`、`\0` 与 `\Uxxxx` 转义；
 * 遇到不认识的写法或重复的键时抛出错误，错误信息带上文件与行号。
 */
export function parseStrings(source: string, file: string): AppStringTable {
    const table: AppStringTable = {};
    let index = 0;

    const fail = (message: string): never => {
        const line = source.slice(0, index).split('\n').length;

        throw new Error(`${file}:${line}: ${message}`);
    };

    // 跳过空白与注释，停在下一个有意义的字符上
    const skipTrivia = () => {
        while (index < source.length) {
            if (/\s/.test(source[index]!)) {
                index += 1;
            } else if (source.startsWith('/*', index)) {
                const end = source.indexOf('*/', index + 2);

                if (end < 0) {
                    fail('注释没有结束');
                }

                index = end + 2;
            } else if (source.startsWith('//', index)) {
                const end = source.indexOf('\n', index);
                index = end < 0 ? source.length : end + 1;
            } else {
                return;
            }
        }
    };

    const expect = (character: string) => {
        skipTrivia();

        if (source[index] !== character) {
            fail(`这里应该是 “${character}”`);
        }

        index += 1;
    };

    // 读一个带引号的字符串，并展开其中的转义
    const readQuoted = (): string => {
        expect('"');
        let value = '';

        while (index < source.length) {
            const character = source[index]!;

            if (character === '"') {
                index += 1;

                return value;
            }

            if (character !== '\\') {
                value += character;
                index += 1;
                continue;
            }

            const escaped = source[index + 1];
            index += 2;

            switch (escaped) {
                case '"':
                case '\\':
                case "'":
                    value += escaped;
                    break;

                case 'n':
                    value += '\n';
                    break;

                case 't':
                    value += '\t';
                    break;

                case 'r':
                    value += '\r';
                    break;

                case '0':
                    value += '\0';
                    break;

                case 'U':
                case 'u': {
                    const hex = source.slice(index, index + 4);

                    if (!/^[0-9a-fA-F]{4}$/.test(hex)) {
                        fail(`\\${escaped} 后面应该是 4 位十六进制数`);
                    }

                    value += String.fromCharCode(Number.parseInt(hex, 16));
                    index += 4;
                    break;
                }

                default:
                    fail(`不认识的转义 \\${escaped ?? ''}`);
            }
        }

        return fail('字符串没有结束');
    };

    // 逐条读取 "键" = "值";
    for (skipTrivia(); index < source.length; skipTrivia()) {
        const key = readQuoted();
        expect('=');
        const value = readQuoted();
        expect(';');

        if (key in table) {
            fail(`键 “${key}” 重复`);
        }

        table[key] = value;
    }

    return table;
}

/** 一处引用界面叫法的参数：资源键、占位符的参数，以及出错时指出位置的说明。 */
export interface AppTextRequest {
    /** 一个或几个资源键；几个时是菜单路径 */
    keys: readonly string[];

    /** 按顺序代入占位符的参数；只能与单个资源键一起用 */
    args?: readonly string[];

    /** 出错时写进错误信息的位置，如页面的文件路径 */
    where: string;
}

/** 菜单路径各级之间的分隔，两侧各一个空格。 */
export const menuPathSeparator = ' › ';

/** 界面叫法在页面里的样式类名，Markdown 与组件输出的粗体都带它。 */
export const uiLabelClass = 'ui-label';

/**
 * 按语言取界面叫法：代入参数、去掉末尾的冒号，菜单路径用 ` › ` 连起来。
 *
 * 任何一种语言缺这个键都抛出错误：页面现在取的是一种语言，翻译之后其余语言同样会用到它。
 */
export function appText(tables: AppStringTables, localeCode: string, request: AppTextRequest): string {
    const { keys, args = [], where } = request;

    if (keys.length === 0) {
        throw new Error(`${where}: 界面叫法没有写资源键`);
    }

    if (args.length > 0 && keys.length > 1) {
        throw new Error(`${where}: 菜单路径 “${keys.join(' ')}” 不能带参数`);
    }

    for (const key of keys) {
        const missing = Object.keys(tables).filter((code) => !(key in tables[code]!));

        if (missing.length > 0) {
            throw new Error(`${where}: 资源键 “${key}” 在 ${missing.join('、')} 的文案里不存在`);
        }
    }

    const table = tables[localeCode];

    if (!table) {
        throw new Error(`${where}: 没有 ${localeCode} 的文案`);
    }

    return keys
        .map((key) => stripTrailingColon(substitute(table[key]!, args, `${where}: 资源键 “${key}”`)))
        .join(menuPathSeparator);
}

/**
 * 按格式说明符代入参数：`%@`、`%d`、`%ld` 等按出现顺序取参数，`%1$@` 这类按序号取，`%%` 是百分号本身。
 *
 * 参数缺了或多了都抛出错误。
 */
function substitute(template: string, args: readonly string[], where: string): string {
    const specifier = /%(?:(\d+)\$)?(?:hh|h|ll|l|q|z|t|j)?([@dDiuUxXoOfFeEgGcCsSpaA%])/g;
    let nextIndex = 0;
    const used = new Set<number>();

    const result = template.replace(
        specifier,
        (_match, position: string | undefined, conversion: string) => {
            if (conversion === '%') {
                return '%';
            }

            const argIndex = position ? Number(position) - 1 : nextIndex++;

            if (argIndex >= args.length) {
                throw new Error(`${where} 的文案 “${template}” 需要第 ${argIndex + 1} 个参数`);
            }

            used.add(argIndex);

            return args[argIndex]!;
        },
    );

    if (used.size < args.length) {
        throw new Error(`${where} 的文案 “${template}” 只用到 ${used.size} 个参数，却给了 ${args.length} 个`);
    }

    return result;
}

/** 去掉末尾的冒号，连同法文冒号前的空格（普通空格、不换行空格或窄不换行空格）；省略号保留。 */
function stripTrailingColon(text: string): string {
    return text.replace(/[ \u00A0\u202F]*[:：]$/u, '');
}
