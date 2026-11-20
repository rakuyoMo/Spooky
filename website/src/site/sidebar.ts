import type { StarlightUserConfig } from '@astrojs/starlight/types';
import { defaultLocale, siteLocales } from './locales.ts';
import { readSiteTexts } from './site-data.ts';

/** Starlight 的侧边栏配置。 */
type Sidebar = NonNullable<StarlightUserConfig['sidebar']>;

/**
 * 手册的分组与各组的页面，按侧边栏里的顺序排列。
 *
 * 分组名写在 `src/content/i18n/<语言>.json` 的 `sidebar.<分组>` 里；页面的名字取各页的 `title`。
 */
const groups = [
    {
        id: 'start',
        items: ['guide/start/install', 'guide/start/tour', 'guide/start/first-repository'],
    },
    {
        id: 'repositories',
        items: ['guide/repositories/manager', 'guide/repositories/navigation'],
    },
    {
        id: 'server',
        items: [
            'guide/server/overview',
            'guide/server/prepare-ssh',
            'guide/server/add',
            'guide/server/connection',
            'guide/server/local-location',
        ],
    },
    {
        id: 'work',
        items: [
            'guide/work/working-copy',
            'guide/work/diff',
            'guide/work/commit',
            'guide/work/stash',
            'guide/work/conflicts',
            'guide/work/undo',
        ],
    },
    {
        id: 'history',
        items: [
            'guide/history/browse',
            'guide/history/commit-details',
            'guide/history/file-views',
            'guide/history/rewrite',
        ],
    },
    {
        id: 'branches',
        items: [
            'guide/branches/branches',
            'guide/branches/tags-remotes',
            'guide/branches/sync',
            'guide/branches/merge-rebase',
            'guide/branches/review',
        ],
    },
    {
        id: 'hosting',
        items: ['guide/hosting/accounts', 'guide/hosting/pull-requests'],
    },
    {
        id: 'advanced',
        items: [
            'guide/advanced/submodules',
            'guide/advanced/worktrees',
            'guide/advanced/lfs',
            'guide/advanced/queue-activity',
        ],
    },
    {
        id: 'settings',
        items: [
            'guide/settings/general',
            'guide/settings/appearance',
            'guide/settings/identity',
            'guide/settings/integration',
        ],
    },
    {
        id: 'reference',
        items: [
            'reference/shortcuts',
            'reference/requirements',
            'reference/data-privacy',
            'reference/troubleshooting',
        ],
    },
];

/**
 * 生成侧边栏：最上面是手册首页，下面按分组列出各页。
 *
 * 英文的分组名缺了时抛出错误；其余语言缺了时显示英文。
 */
export function sidebar(i18nDirectory: string): Sidebar {
    const texts = new Map(siteLocales.map((locale) => [locale, readSiteTexts(i18nDirectory, locale.lang)]));

    return [
        'guide',
        ...groups.map(({ id, items }) => {
            const key = `sidebar.${id}`;
            const label = texts.get(defaultLocale)?.[key];

            if (!label) {
                throw new Error(`src/content/i18n/${defaultLocale.lang}.json 缺少 “${key}”`);
            }

            const translations = Object.fromEntries(
                siteLocales.flatMap((locale) => {
                    const translation = texts.get(locale)?.[key];

                    return locale !== defaultLocale && translation ? [[locale.lang, translation]] : [];
                }),
            );

            return { label, translations, items };
        }),
    ];
}
