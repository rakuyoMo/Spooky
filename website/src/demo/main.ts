import { startDemo } from './controller.ts';
import data from './data/repo.json';
import type { RepoData } from './model.ts';
import type { DemoStrings } from './text.ts';

/**
 * 演示窗口在浏览器里的入口：窗口进入视口附近时由页面加载，读出页面上写好的文案与设置，启动控制器。
 */

/** 启动一个演示窗口；文案、语言、应用图标与网站自己的提示都由构建时写在 `root` 上。 */
export function mount(root: HTMLElement): void {
    const strings = root.querySelector('script[data-demo-strings]')?.textContent;
    const { lang, appIcon, unavailable, upToDate, overflowLabel } = root.dataset;

    if (
        !strings ||
        !lang ||
        !appIcon ||
        unavailable === undefined ||
        upToDate === undefined ||
        overflowLabel === undefined
    ) {
        return;
    }

    startDemo({
        root,
        data: data as RepoData,
        strings: JSON.parse(strings) as DemoStrings,
        lang,
        appIcon,
        notices: { unavailable, upToDate },
        overflowLabel,
        loadChanges: () => import('./data/changes.json').then((module) => module.default),
    });
}
