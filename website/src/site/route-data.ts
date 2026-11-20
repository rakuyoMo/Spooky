import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

/*
 * Starlight 的路由数据中间件：首页的标签页标题先写站名、再写标语。
 */

/** 首页的标签页标题写成 “站名 | 标语”；404 页与手册页面仍是 “标题 | 站名”。 */
export const onRequest = defineRouteMiddleware(({ locals }) => {
    const { entry, head, siteTitle } = locals.starlightRoute;

    // 带主视觉的页面只有首页与 404 页
    if (!entry.data.hero || entry.id === '404') {
        return;
    }

    const title = head.find(({ tag }) => tag === 'title');

    if (title) {
        title.content = `${siteTitle} | ${entry.data.title}`;
    }
});
