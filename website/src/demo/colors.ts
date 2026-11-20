import themes from '../../../Sources/Spooky/Resources/BuiltinThemes.json';
import namedColors from '../../../Sources/Spooky/Resources/NamedColors.json';

/**
 * 演示窗口取自 App 资源的颜色：文本区用内置主题 `default` 与 `default-dark`，徽标、提交图与状态标记用 `NamedColors.json`。
 *
 * 只在构建时运行，生成一段 CSS 变量内联进页面；系统控件的颜色写在 `demo.css` 里。
 */

/** 资源里的一个颜色。 */
interface ColorValue {
    hex: string;
    alpha: number;
}

/** 演示窗口用到的命名颜色。 */
const namedKeys = [
    'general_info_background_color',
    'sidebarBadgeBackgroundColor',
    'blue_badge_background_color',
    'blue_badge_text_color',
    'gray_badge_background_color',
    'gray_badge_text_color',
    'yellow_badge_background_color',
    'yellow_badge_text_color',
    'red_badge_background_color',
    'red_badge_text_color',
    'selected_badge_background_color',
    'selected_badge_text_color',
    'general_border_color',
    'green_file_status_background_color',
    'blue_file_status_background_color',
    'gray_file_status_background_color',
    'gray_history_graph_line_color',
    'blue_history_graph_line_color',
    'pink_history_graph_line_color',
    'green_history_graph_line_color',
    'yellow_history_graph_line_color',
    'orange_history_graph_line_color',
    'indigo_history_graph_line_color',
    'red_history_graph_line_color',
    'teal_history_graph_line_color',
    'purple_history_graph_line_color',
    'repository_history_commit_bubble_bg_color',
    'repository_history_commit_bubble_border_color',
    'avatar_background_color',
] as const;

/** 主题里演示窗口用到的颜色：Diff 的底色与各类记号。 */
const themeKeys = [
    'text',
    'background',
    'selection',
    'added',
    'deleted',
    'keyword',
    'identifier',
    'function',
    'number',
    'string',
    'symbol',
    'comment',
    'preprocessor',
    'attributeName',
    'cssSelector',
    'heading',
    'emphasized',
    'stronglyEmphasized',
    'codeBlock',
    'url',
] as const;

/** 生成演示窗口的颜色变量：默认是深色，网站切到浅色时换成浅色的一组。 */
export function demoColorsCss(): string {
    const dark = declarations('dark', 'default-dark');
    const light = declarations('light', 'default');

    return `.sd{${dark}}:root[data-theme='light'] .sd{${light}}`;
}

// MARK: - Private

/** 一种外观的全部变量声明。 */
function declarations(appearance: 'light' | 'dark', themeIdentifier: string): string {
    const theme = themes.find((candidate) => candidate.identifier === themeIdentifier);

    if (!theme) {
        throw new Error(`BuiltinThemes.json 里没有主题 ${themeIdentifier}`);
    }

    const colors: Record<string, ColorValue> = theme.colors;
    const named: Record<string, Record<'light' | 'dark', ColorValue>> = namedColors;

    const fromTheme = themeKeys.map((key) => `--sd-t-${key}:${css(required(colors[key], key))}`);
    const fromNamed = namedKeys.map((key) => `--sd-${key}:${css(required(named[key]?.[appearance], key))}`);

    return [...fromTheme, ...fromNamed].join(';');
}

/** 资源里一定要有的颜色；缺了就让构建失败。 */
function required(value: ColorValue | undefined, key: string): ColorValue {
    if (!value) {
        throw new Error(`App 的颜色资源里没有 ${key}`);
    }

    return value;
}

/** 转成 CSS 颜色：不透明时用十六进制，否则用 `rgb(r g b / a)`。 */
function css({ hex, alpha }: ColorValue): string {
    if (alpha === 1) {
        return hex.toLowerCase();
    }

    const value = Number.parseInt(hex.slice(1), 16);

    return `rgb(${value >> 16} ${(value >> 8) & 255} ${value & 255}/${alpha})`;
}
