import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';
import { docsLoader, i18nLoader } from '@astrojs/starlight/loaders';
import { docsSchema, i18nSchema } from '@astrojs/starlight/schema';

/** 站点自己的文字：侧边栏的分组名、截图组件里给读屏软件的文字、页脚、404 页、外观的切换按钮与首页的演示窗口；每种语言的文件都要写全。 */
const siteTexts = z.object({
    'sidebar.start': z.string(),
    'sidebar.repositories': z.string(),
    'sidebar.server': z.string(),
    'sidebar.work': z.string(),
    'sidebar.history': z.string(),
    'sidebar.branches': z.string(),
    'sidebar.hosting': z.string(),
    'sidebar.advanced': z.string(),
    'sidebar.settings': z.string(),
    'sidebar.reference': z.string(),
    'screenshot.open': z.string(),
    'screenshot.close': z.string(),
    'footer.guide': z.string(),
    'footer.releaseNotes': z.string(),
    'footer.issues': z.string(),
    'footer.license': z.string(),
    'notFound.home': z.string(),
    'themeToggle.label': z.string(),
    'demo.skip': z.string(),
    'demo.label': z.string(),
    'demo.try': z.string(),
    'demo.step.stage': z.string(),
    'demo.step.commit': z.string(),
    'demo.step.push': z.string(),
    'demo.reset': z.string(),
    'demo.note': z.string(),
    'demo.unavailable': z.string(),
    'demo.upToDate': z.string(),
    'demo.done': z.string(),
});

/** 手册页面与各语言的界面文字。 */
export const collections = {
    docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }),
    i18n: defineCollection({ loader: i18nLoader(), schema: i18nSchema({ extend: siteTexts }) }),
};
