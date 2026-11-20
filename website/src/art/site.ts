import { iconScripts } from 'virtual:spooky/site-data';
import { createIconKit } from './kit.ts';
import { createSiteArt } from './scenes.ts';
import { createTrailArt } from './trail.ts';

/** App 应用图标的绘制脚本，构建时只运行一次。 */
const kit = createIconKit(iconScripts);

/** 首页与 404 页上的几幅画，构建时由 App 应用图标的绘制脚本画出。 */
export const siteArt = createSiteArt(kit);

/** 首页跟着滚动的小幽灵用到的画，写成 JSON 由页面的脚本另取。 */
export const trailArt = createTrailArt(kit);
