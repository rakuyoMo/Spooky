import type { APIRoute } from 'astro';

import { trailArt } from '../art/site.ts';

/*
 * 首页跟着滚动的小幽灵用到的画，构建时写成 `trail.json`。
 *
 * 这些画不放进首页的 HTML：首屏只有静止的画，页面的脚本启动后再取这份文件。
 */

/** 输出整份画的 JSON。 */
export const GET: APIRoute = () =>
    new Response(JSON.stringify(trailArt), { headers: { 'Content-Type': 'application/json' } });
