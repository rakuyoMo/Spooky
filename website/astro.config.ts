import { fileURLToPath } from 'node:url';
import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';
import starlightLinksValidator from 'starlight-links-validator';
import { spookySite } from './src/site/integration.ts';
import { localeScript } from './src/site/locale-script.ts';
import { defaultLocale, siteLocales } from './src/site/locales.ts';
import { sidebar } from './src/site/sidebar.ts';

/** 英文在根路径，其余语言在各自的前缀下。 */
const locales = Object.fromEntries(
    siteLocales.map(({ code, lang, label }) => [code === defaultLocale.code ? 'root' : code, { label, lang }]),
);

export default defineConfig({
    site: 'https://spooky.rakuyo.dev',
    trailingSlash: 'always',

    integrations: [
        spookySite(),

        starlight({
            title: 'Spooky',
            favicon: '/favicon.png',
            social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/rakuyoMo/Spooky' }],
            disable404Route: true,
            defaultLocale: 'root',
            locales,
            sidebar: sidebar(fileURLToPath(new URL('./src/content/i18n/', import.meta.url))),
            customCss: ['./src/styles/theme.css', './src/styles/content.css', './src/styles/screenshot.css'],

            // 首页与 404 的主视觉、页脚，还有外观的切换按钮，换成站点自己的；搜索框只留在手册页面
            components: {
                Hero: './src/components/Hero.astro',
                Footer: './src/components/Footer.astro',
                Search: './src/components/Search.astro',
                ThemeSelect: './src/components/ThemeSelect.astro',
            },

            head: [{ tag: 'script', content: localeScript() }],
            plugins: [starlightLinksValidator({ errorOnInconsistentLocale: true })],
        }),
    ],
});
