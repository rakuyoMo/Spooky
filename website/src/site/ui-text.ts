import type { AstroGlobal } from 'astro';
import { appStrings } from 'virtual:spooky/site-data';
import { appText } from './app-text.ts';
import { localeOfRoute } from './locales.ts';

/**
 * 在 `.astro` 组件里按当前页面的语言取界面叫法，规则与 Markdown 里的 `:ui[…]` 相同。
 *
 * `keys` 是一个资源键，或菜单路径的几个键；出错时错误信息里是当前页面的文件路径。
 */
export function uiText(
    astro: AstroGlobal,
    keys: string | readonly string[],
    args: readonly string[] = [],
): string {
    const route = astro.locals.starlightRoute;

    return appText(appStrings, localeOfRoute(route.locale).code, {
        keys: typeof keys === 'string' ? [keys] : keys,
        args,
        where: route.entry.filePath ?? astro.url.pathname,
    });
}
