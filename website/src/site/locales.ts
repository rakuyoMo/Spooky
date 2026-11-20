/** 站点的一种语言：路径前缀、页面的 `lang`、语言选择里的名字，以及 App 里对应的文案目录。 */
export interface SiteLocale {
    /** 路径前缀与截图目录名；英文在根路径，没有前缀 */
    code: string;

    /** 写进 `<html lang>` 与 `hreflang` 的 BCP-47 语言标签 */
    lang: string;

    /** 语言选择里显示的名字，用这种语言自己的写法 */
    label: string;

    /** `Sources/Spooky/Resources/` 下的 `.lproj` 目录名 */
    appLocale: string;
}

/** 官网支持的全部语言，与 App 支持的语言一一对应；第一项是英文，也是匹配不到时的回退。 */
export const siteLocales: readonly SiteLocale[] = [
    { code: 'en', lang: 'en', label: 'English', appLocale: 'en' },
    { code: 'zh-cn', lang: 'zh-CN', label: '简体中文', appLocale: 'zh-Hans' },
    { code: 'zh-tw', lang: 'zh-TW', label: '繁體中文', appLocale: 'zh-Hant' },
    { code: 'ja', lang: 'ja', label: '日本語', appLocale: 'ja' },
    { code: 'ko', lang: 'ko', label: '한국어', appLocale: 'ko' },
    { code: 'de', lang: 'de', label: 'Deutsch', appLocale: 'de' },
    { code: 'fr', lang: 'fr', label: 'Français', appLocale: 'fr' },
    { code: 'es', lang: 'es', label: 'Español', appLocale: 'es' },
];

/** 英文：根路径上的语言。 */
export const defaultLocale = siteLocales[0]!;

/**
 * 按 `src/content/docs/` 下的相对路径判断页面的语言。
 *
 * 第一段是某种语言的前缀时就是那种语言，否则是根路径上的英文。
 */
export function localeOfDocsPath(relativePath: string): SiteLocale {
    const [firstSegment] = relativePath.split('/');

    return siteLocales.find(({ code }) => code !== defaultLocale.code && code === firstSegment) ?? defaultLocale;
}

/** 按 Starlight 路由里的语言目录取语言；根路径上的英文没有目录，传入 `undefined`。 */
export function localeOfRoute(routeLocale: string | undefined): SiteLocale {
    return siteLocales.find(({ code }) => code === routeLocale) ?? defaultLocale;
}

/**
 * 给以 `/` 开头的站内地址加上语言前缀，页面与组件里照抄英文页的地址就能用。
 *
 * 英文、站外地址、锚点与已经写了语言前缀的地址原样返回；写错了语言由链接检查报出来。
 */
export function localizedUrl(url: string, locale: SiteLocale): string {
    const [, firstSegment] = url.split('/');

    if (
        locale === defaultLocale ||
        !url.startsWith('/') ||
        url.startsWith('//') ||
        siteLocales.some(({ code }) => code === firstSegment)
    ) {
        return url;
    }

    return `/${locale.code}${url}`;
}
