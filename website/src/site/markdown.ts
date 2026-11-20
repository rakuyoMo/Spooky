import { isAbsolute, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { SatteriResolvedOptions } from '@astrojs/markdown-satteri';
import { appText, uiLabelClass, type AppStringTables } from './app-text.ts';
import { localeOfDocsPath, localizedUrl } from './locales.ts';
import { screenshotHtml, type ScreenshotManifest } from './screenshot.ts';

/** Sätteri 的 mdast 插件。 */
type MdastPluginEntry = SatteriResolvedOptions['mdastPlugins'][number];

/** 页面里引用界面叫法与截图时要用到的数据。 */
export interface SiteMarkdownData {
    /** 项目根目录，错误信息里的文件路径相对于它 */
    projectRoot: string;

    /** 手册页面所在的 `src/content/docs/` */
    docsDirectory: string;

    /** 8 种语言的 App 文案 */
    appStrings: AppStringTables;

    /** 全部截图的尺寸 */
    screenshots: ScreenshotManifest;

    /** 各语言里站点自己的文字 */
    siteTexts: Record<string, Record<string, string>>;
}

/**
 * 手册页面的 Markdown 扩展，`.md` 与 `.mdx` 都适用：
 *
 * - `:ui[资源键]`：界面叫法；`:ui[键 > 键]` 是菜单路径；`:ui[键]{1="参数" 2="参数"}` 代入占位符
 * - `::screenshot[替代文本]{name="名字" frame="window"}`：截图，可以再带 `caption="图注"`
 * - 以 `/` 开头的站内链接按页面的语言加上语言前缀，各语言的页面照抄英文页的链接
 */
export function siteMarkdownPlugin(data: SiteMarkdownData): MdastPluginEntry {
    return ({ fileURL, sourceFormat }) => {
        if (!fileURL) {
            return undefined;
        }

        const path = fileURLToPath(fileURL);
        const relativePath = relative(data.docsDirectory, path);

        // 只处理手册页面
        if (relativePath.startsWith('..') || isAbsolute(relativePath)) {
            return undefined;
        }

        const locale = localeOfDocsPath(relativePath.split(sep).join('/'));
        const file = relative(data.projectRoot, path);
        const texts = data.siteTexts[locale.code] ?? {};

        return {
            name: 'spooky-site',

            textDirective(node, context) {
                if (node.name !== 'ui') {
                    return undefined;
                }

                const keys = context
                    .textContent(node)
                    .split('>')
                    .map((key) => key.trim());

                const text = appText(data.appStrings, locale.code, {
                    keys: keys.filter((key) => key !== ''),
                    args: directiveArgs(node.attributes ?? {}, file),
                    where: file,
                });

                return {
                    type: 'strong',
                    data: { hProperties: { className: [uiLabelClass], translate: 'no' } },
                    children: [{ type: 'text', value: text }],
                };
            },

            leafDirective(node, context) {
                if (node.name !== 'screenshot') {
                    return undefined;
                }

                const { name, frame, caption, markers, ...rest } = node.attributes ?? {};
                const unknown = Object.keys(rest);

                if (unknown.length > 0) {
                    throw new Error(`${file}: 截图不认识的属性 ${unknown.join('、')}`);
                }

                const html = screenshotHtml(
                    data.screenshots,
                    locale.code,
                    {
                        name: name ?? '',
                        alt: context.textContent(node),
                        frame: frame ?? '',
                        caption: caption ?? undefined,
                        markers: markers ?? undefined,
                        where: file,
                    },
                    {
                        open: texts['screenshot.open'] ?? '',
                        close: texts['screenshot.close'] ?? '',
                    },
                );

                // MDX 里没有原样输出的 HTML 节点，交给 Astro 的 `Fragment` 输出
                if (sourceFormat === 'mdx') {
                    return {
                        type: 'mdxJsxFlowElement',
                        name: 'Fragment',
                        attributes: [{ type: 'mdxJsxAttribute', name: 'set:html', value: html }],
                        children: [],
                    };
                }

                return { type: 'html', value: html };
            },

            link(node, context) {
                const url = localizedUrl(node.url, locale);

                if (url !== node.url) {
                    context.setField(node, 'url', url);
                }

                return undefined;
            },

            definition(node, context) {
                const url = localizedUrl(node.url, locale);

                if (url !== node.url) {
                    context.setField(node, 'url', url);
                }

                return undefined;
            },
        };
    };
}

/**
 * 从指令的属性里取占位符的参数：属性名是从 1 起的序号，按序号排好。
 *
 * 序号不连续或有别的属性时抛出错误。
 */
function directiveArgs(attributes: Record<string, string | null | undefined>, where: string): string[] {
    const names = Object.keys(attributes);
    const args = names.map((_, index) => attributes[String(index + 1)]);

    if (args.some((value) => value === undefined || value === null)) {
        throw new Error(`${where}: 界面叫法的参数要写成 1="…" 2="…"，从 1 起连续编号；现在是 ${names.join('、')}`);
    }

    return args as string[];
}
