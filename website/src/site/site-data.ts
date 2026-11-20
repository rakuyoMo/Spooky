import { readFileSync } from 'node:fs';
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { imageMetadata } from 'astro/assets/utils';
import { parseStrings, type AppStringTables } from './app-text.ts';
import { defaultLocale, siteLocales } from './locales.ts';
import { appearances, type ScreenshotManifest } from './screenshot.ts';

/**
 * 读取 8 种语言的 `Localizable.strings`，以站点的语言代号为键。
 *
 * `resourcesDirectory` 是 App 的 `Sources/Spooky/Resources/`。
 */
export async function loadAppStrings(resourcesDirectory: string): Promise<AppStringTables> {
    const entries = await Promise.all(
        siteLocales.map(async ({ code, appLocale }) => {
            const file = join(resourcesDirectory, `${appLocale}.lproj`, 'Localizable.strings');

            return [code, parseStrings(await readFile(file, 'utf8'), file)] as const;
        }),
    );

    return Object.fromEntries(entries);
}

/**
 * 读取全部截图的尺寸。
 *
 * 只认 `<语言>/<外观>/<名字>.webp`；文件读不出尺寸时抛出错误，如 Git LFS 的对象还没取下来、文件仍是指针。
 */
export async function loadScreenshotManifest(screenshotsDirectory: string): Promise<ScreenshotManifest> {
    const manifest: ScreenshotManifest = {};

    for (const { code } of siteLocales) {
        for (const appearance of appearances) {
            const directory = join(screenshotsDirectory, code, appearance);
            const files = await readdir(directory).catch(() => []);
            const names = files.filter((file) => file.endsWith('.webp'));

            for (const file of names) {
                const path = join(directory, file);
                const { width, height, format } = await imageMetadata(await readFile(path), path);

                if (format !== 'webp') {
                    throw new Error(`${path} 不是 WebP 图片`);
                }

                manifest[`${code}/${appearance}/${file.slice(0, -'.webp'.length)}`] = { width, height };
            }
        }
    }

    return manifest;
}

/**
 * 读取 `src/content/i18n/` 下各语言里站点自己的文字，以站点的语言代号为键。
 *
 * 某种语言缺的键用英文补上，与 Starlight 自带文字的回退一致。
 */
export function loadSiteTexts(i18nDirectory: string): Record<string, Record<string, string>> {
    const english = readSiteTexts(i18nDirectory, defaultLocale.lang);

    return Object.fromEntries(
        siteLocales.map(({ code, lang }) => [code, { ...english, ...readSiteTexts(i18nDirectory, lang) }]),
    );
}

/** 读一种语言的 `src/content/i18n/<lang>.json`；还没有这个文件时当作空的。 */
export function readSiteTexts(i18nDirectory: string, lang: string): Record<string, string> {
    try {
        return JSON.parse(readFileSync(join(i18nDirectory, `${lang}.json`), 'utf8')) as Record<string, string>;
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
            return {};
        }

        throw error;
    }
}
