/** 官网的构建扩展提供的站点数据，见 `src/site/integration.ts`。 */
declare module 'virtual:spooky/site-data' {
    /** 8 种语言的 App 文案，以站点的语言代号为键 */
    export const appStrings: import('./site/app-text.ts').AppStringTables;

    /** 全部截图的尺寸，以 `<语言>/<外观>/<名字>` 为键 */
    export const screenshots: import('./site/screenshot.ts').ScreenshotManifest;

    /** App 应用图标的绘制脚本，按执行的先后排好 */
    export const iconScripts: readonly import('./art/kit.ts').IconScript[];
}
