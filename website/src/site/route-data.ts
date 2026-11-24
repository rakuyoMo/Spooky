import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

/*
 * Starlight 的路由数据中间件：标签页标题先写站名、再写页面标题。
 */

/** 每页的标签页标题写成 “站名 | 标题”；Starlight 默认是 “标题 | 站名”。 */
export const onRequest = defineRouteMiddleware(({ locals }) => {
    const { entry, head, siteTitle } = locals.starlightRoute;

    const title = head.find(({ tag }) => tag === 'title');

    if (title) {
        title.content = `${siteTitle} | ${entry.data.title}`;
    }
});
