import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

/*
 * Starlight 的路由数据中间件：首页与手册页面的标签页标题先写站名、再写页面标题。
 */

/** 首页与手册页面的标签页标题写成 “站名 | 标题”；404 页保持 Starlight 默认的 “标题 | 站名”。 */
export const onRequest = defineRouteMiddleware(({ locals }) => {
    const { entry, head, siteTitle } = locals.starlightRoute;

    if (entry.id === '404') {
        return;
    }

    const title = head.find(({ tag }) => tag === 'title');

    if (title) {
        title.content = `${siteTitle} | ${entry.data.title}`;
    }
});
