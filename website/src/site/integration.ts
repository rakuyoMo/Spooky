import { createReadStream } from 'node:fs';
import { cp, stat } from 'node:fs/promises';
import { join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isSatteriProcessor } from '@astrojs/markdown-satteri';
import type { AstroIntegration } from 'astro';
import type { Plugin } from 'vite';
import { type IconScript, readIconScripts } from '../art/kit.ts';
import type { AppStringTables } from './app-text.ts';
import { siteLocales } from './locales.ts';
import { siteMarkdownPlugin } from './markdown.ts';
import { screenshotUrlBase, type ScreenshotManifest } from './screenshot.ts';
import { loadAppStrings, loadScreenshotManifest, loadSiteTexts } from './site-data.ts';

/** 组件取站点数据用的虚拟模块。 */
const virtualModuleId = 'virtual:spooky/site-data';

/**
 * 官网的构建扩展：
 *
 * - 读取 App 的文案与截图的尺寸，交给 Markdown 扩展与组件
 * - 读取 App 应用图标的绘制脚本，交给组件画首页与 404 页上的画
 * - 截图原样发布在 `/screenshots/` 下：开发时由开发服务器直接读，构建后拷进产物
 * - 每页加载截图放大的脚本
 */
export function spookySite(): AstroIntegration {
    let screenshotsDirectory = '';

    return {
        name: 'spooky-site',
        hooks: {
            'astro:config:setup': async ({ config, addWatchFile, injectScript, updateConfig }) => {
                const projectRoot = fileURLToPath(config.root);
                const resourcesDirectory = join(projectRoot, '..', 'Sources', 'Spooky', 'Resources');
                screenshotsDirectory = join(projectRoot, 'src', 'assets', 'screenshots');

                const [appStrings, screenshots] = await Promise.all([
                    loadAppStrings(resourcesDirectory),
                    loadScreenshotManifest(screenshotsDirectory),
                ]);

                const i18nDirectory = join(projectRoot, 'src', 'content', 'i18n');
                const siteTexts = loadSiteTexts(i18nDirectory);

                const iconDirectory = join(projectRoot, '..', 'scripts', 'make-icon');
                const iconScripts = readIconScripts(iconDirectory);

                // App 的文案、绘制脚本与站点自己的文字改了，开发服务器重启后重新读取
                for (const { lang, appLocale } of siteLocales) {
                    addWatchFile(join(resourcesDirectory, `${appLocale}.lproj`, 'Localizable.strings'));
                    addWatchFile(join(i18nDirectory, `${lang}.json`));
                }

                for (const { name } of iconScripts) {
                    addWatchFile(join(iconDirectory, name));
                }

                const processor = config.markdown.processor;

                if (!isSatteriProcessor(processor)) {
                    throw new Error(`官网的 Markdown 扩展需要 Sätteri，现在是 ${processor.name}`);
                }

                // 标题可以写 `{#id}` 指定锚点，各语言的同一个标题用同一个锚点
                processor.options.features.attributes = true;

                processor.options.mdastPlugins.push(
                    siteMarkdownPlugin({
                        projectRoot,
                        docsDirectory: join(projectRoot, 'src', 'content', 'docs'),
                        appStrings,
                        screenshots,
                        siteTexts,
                    }),
                );

                injectScript('page', `import '/src/scripts/screenshot-zoom.ts';`);
                updateConfig({ vite: { plugins: [siteDataPlugin(appStrings, screenshots, iconScripts)] } });
            },

            'astro:server:setup': ({ server }) => {
                server.middlewares.use(screenshotUrlBase, (request, response, next) => {
                    const path = normalize(join(screenshotsDirectory, decodeURIComponent(request.url ?? '')));

                    // 只读截图目录里的 WebP
                    if (!path.startsWith(screenshotsDirectory + sep) || !path.endsWith('.webp')) {
                        next();

                        return;
                    }

                    stat(path).then(
                        () => {
                            response.setHeader('Content-Type', 'image/webp');
                            createReadStream(path).pipe(response);
                        },
                        () => next(),
                    );
                });
            },

            'astro:build:done': async ({ dir }) => {
                await cp(screenshotsDirectory, fileURLToPath(new URL(`.${screenshotUrlBase}`, dir)), {
                    recursive: true,
                });
            },
        },
    };
}

/** 提供 `virtual:spooky/site-data` 的 Vite 插件：导出 App 的文案、截图的尺寸与应用图标的绘制脚本。 */
function siteDataPlugin(
    appStrings: AppStringTables,
    screenshots: ScreenshotManifest,
    iconScripts: readonly IconScript[],
): Plugin {
    const resolvedId = `\0${virtualModuleId}`;

    return {
        name: 'spooky-site-data',

        resolveId(id) {
            return id === virtualModuleId ? resolvedId : undefined;
        },

        load(id) {
            if (id !== resolvedId) {
                return undefined;
            }

            return [
                `export const appStrings = ${JSON.stringify(appStrings)};`,
                `export const screenshots = ${JSON.stringify(screenshots)};`,
                `export const iconScripts = ${JSON.stringify(iconScripts)};`,
            ].join('\n');
        },
    };
}
