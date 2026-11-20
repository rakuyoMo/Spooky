import { minifySync } from 'vite';
import { defaultLocale, siteLocales } from './locales.ts';

/** 跟随浏览器语言的脚本用到的参数。 */
interface LocaleScriptOptions {
    /** 带路径前缀的语言代号 */
    prefixes: string[];

    /** 根路径上的语言代号 */
    defaultCode: string;

    /** 记住手动选择的语言用的 `localStorage` 键 */
    storageKey: string;
}

/**
 * 跟随浏览器语言的内联脚本，放进每页的 `<head>`，在页面显示之前执行。
 *
 * 脚本由 `followBrowserLanguage` 的源码与参数拼成，不依赖任何模块；压缩之后再写进页面，源码里的注释不会发布出去。
 */
export function localeScript(): string {
    const options: LocaleScriptOptions = {
        prefixes: siteLocales.map(({ code }) => code).filter((code) => code !== defaultLocale.code),
        defaultCode: defaultLocale.code,
        storageKey: 'spooky-locale',
    };

    const source = `(${followBrowserLanguage.toString()})(${JSON.stringify(options)});`;
    const { code, errors } = minifySync('locale-script.js', source);

    if (errors.length > 0) {
        throw new Error(`跟随浏览器语言的脚本压缩失败：${errors.map(({ message }) => message).join('；')}`);
    }

    return code.trim();
}

/**
 * 访问没有语言前缀的地址时，跳到同一页的另一种语言。
 *
 * - 页头的语言选择里手动选过时按记住的语言走，记住的是英文就不跳
 * - 没选过时按 `navigator.languages` 的顺序找第一个支持的语言，都不支持就留在英文页
 * - 跳转保留查询串与锚点，用 `location.replace`，浏览历史里不留下英文页
 */
function followBrowserLanguage({ prefixes, defaultCode, storageKey }: LocaleScriptOptions) {
    const firstSegment = (path: string) => path.split('/')[1] ?? '';

    // 在页头的语言选择里手动选了语言，记下来；Starlight 随后跳到所选语言的页面
    document.addEventListener('change', (event) => {
        const select = event.target;

        if (!(select instanceof HTMLSelectElement) || !select.closest('starlight-lang-select')) {
            return;
        }

        const code = firstSegment(select.value);

        try {
            localStorage.setItem(storageKey, prefixes.includes(code) ? code : defaultCode);
        } catch {
            // 浏览器不让存网站数据时不记，之后照旧跟随浏览器的语言
        }
    });

    // 带语言前缀的地址是明确的选择，不跳转
    if (prefixes.includes(firstSegment(location.pathname))) {
        return;
    }

    let target: string | null = null;

    try {
        target = localStorage.getItem(storageKey);
    } catch {
        // 读不到网站数据时当作没有选过
    }

    // 繁体中文的地区与 `zh-Hant` 对应繁体，其余中文对应简体，别的语言按主语言匹配
    for (const language of target === null ? navigator.languages : []) {
        const tag = language.toLowerCase();
        const primary = tag.split('-')[0] ?? '';

        if (primary === 'zh') {
            target = /^zh-(tw|hk|mo|hant)(-|$)/.test(tag) ? 'zh-tw' : 'zh-cn';
            break;
        }

        if (primary === defaultCode || prefixes.includes(primary)) {
            target = primary;
            break;
        }
    }

    if (target === null || !prefixes.includes(target)) {
        return;
    }

    // 跳转前先把页面藏起来，英文页不会闪一下
    document.documentElement.style.visibility = 'hidden';
    location.replace(`/${target}${location.pathname}${location.search}${location.hash}`);
}
