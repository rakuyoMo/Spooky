/* global paintRiseIcon */

import { APP_ICON, CARDS, COVER, SHOT_DIRECTORY, TEXTS, shown } from './plan.js';
import { DROP, SCENE } from './stickers.js';
import { span } from './timing.js';

/*
 * 舞台：把成片的画面搭成几层，每帧只改各层的内容与不透明度。
 *
 * 从后往前：满月、星星、贴纸、截图卡片与应用图标、文字。
 * 文字、卡片与应用图标建好之后位置和大小不再改变，也不加任何变换，每帧只设不透明度。
 * 另有一行只在封面图上的文字，成片的每一帧里它都不显示。
 */

/** 各层画的名字，从后往前：满月、星星、贴纸。 */
export const ART_LAYERS = ['sky', 'backdrop', 'back'];

/**
 * 搭好舞台。
 *
 * @param {HTMLElement} root 舞台的容器，大小就是成片的像素尺寸
 * @returns {Promise<{draw: Function, show: Function}>}
 *     draw 换上一帧的画；show 按时间设好文字、卡片与应用图标的不透明度，画封面图时再亮出封面上的那一行
 */
export async function buildStage(root) {
    const layers = Object.fromEntries(ART_LAYERS.map((name) => [name, artLayer()]));
    const cards = await Promise.all(CARDS.map(cardElement));
    const icon = await iconElement();
    const texts = TEXTS.map(textElement);
    const coverLine = textElement(COVER.line).element;

    root.append(
        layers.sky,
        layers.backdrop,
        layers.back,
        ...cards.map(({ element }) => element),
        icon,
        ...texts.map(({ element }) => element),
        coverLine,
    );

    return {
        draw(art) {
            for (const [name, layer] of Object.entries(layers)) {
                setMarkup(layer, art[name]);
            }
        },

        show(t, cover = false) {
            for (const { element, item } of [...cards, ...texts]) {
                setOpacity(element, shown(t, item));
            }

            setOpacity(icon, span(t, APP_ICON.enter, APP_ICON.enter + 0.35));
            setOpacity(coverLine, cover ? 1 : 0);
        },
    };
}

// MARK: - Private

/**
 * 一层画：铺满舞台的 SVG，坐标是图标坐标，图标的方格贴着舞台的底边。
 */
function artLayer() {
    const layer = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    layer.setAttribute('class', 'layer');
    layer.setAttribute('viewBox', `0 ${-DROP} ${SCENE.width} ${SCENE.height}`);
    layer.setAttribute('preserveAspectRatio', 'none');

    return layer;
}

/** 各层当前的内容；与上一帧相同时不重设，浏览器不必重画这一层。 */
const markups = new WeakMap();

/**
 * 换上一层的内容。
 */
function setMarkup(layer, markup) {
    if (markups.get(layer) === markup) {
        return;
    }

    markups.set(layer, markup);
    layer.innerHTML = markup;
}

/**
 * 设一个元素的不透明度；完全透明时整个不画。
 */
function setOpacity(element, opacity) {
    element.style.opacity = opacity.toFixed(4);
    element.style.visibility = opacity > 0 ? 'visible' : 'hidden';
}

/**
 * 一张截图卡片：按取景把截图的像素一比一画进画布，不缩放。
 */
async function cardElement(item) {
    const { file, crop, left, top, radius } = item;
    const [x, y, width, height] = crop;

    const image = new Image();
    image.src = `${SHOT_DIRECTORY}/${file}`;
    await image.decode();

    const element = document.createElement('canvas');
    element.width = width;
    element.height = height;
    element.className = 'card';
    element.style.left = `${left}px`;
    element.style.top = `${top}px`;
    element.style.borderRadius = `${radius}px`;
    element.getContext('2d').drawImage(image, x, y, width, height, 0, 0, width, height);

    return { element, item };
}

/**
 * 片尾的应用图标：App 默认的图标，即探身一组的默认图标，由 App 的绘制脚本画出。
 */
async function iconElement() {
    const { size, left, top } = APP_ICON;

    const element = document.createElement('canvas');
    element.width = size;
    element.height = size;
    element.className = 'app-icon';
    element.style.left = `${left}px`;
    element.style.top = `${top}px`;

    // 绘制脚本的坐标按 1024 网格给出，先把上下文缩放到导出尺寸。
    const scale = size / 1024;
    const context = element.getContext('2d');
    context.scale(scale, scale);
    await paintRiseIcon(context, scale, size, 'default', false);

    return element;
}

/**
 * 一块文字：每行一个元素，行与行不自动折行。
 *
 * 一行可以是一段文字，也可以由几段拼成：带 gloss 的一段在字的上面标一行小字。
 */
function textElement(item) {
    const element = document.createElement('div');
    element.className = `text ${item.kind}`;
    element.style.top = `${item.top}px`;

    for (const line of item.lines) {
        const row = document.createElement('div');
        row.className = 'line';

        const segments = [line].flat();

        segments.forEach((segment, index) => {
            row.append(...segmentNodes(segment, index === segments.length - 1));
        });

        element.append(row);
    }

    return { element, item };
}

/**
 * 一行里的一段：纯文字，或者头上标着小字的几个字。
 *
 * @param {string | {base: string, gloss: string}} segment 一段
 * @param {boolean} last 是不是这一行的最后一段
 * @returns {(string | HTMLElement)[]}
 */
function segmentNodes(segment, last) {
    if (typeof segment !== 'string') {
        const annotated = document.createElement('span');
        annotated.className = 'annotated';

        const gloss = document.createElement('span');
        gloss.className = 'gloss';
        gloss.textContent = segment.gloss;
        annotated.append(segment.base, gloss);

        return [annotated];
    }

    // 行末的全角标点右半边是空的，换成半宽的字形，整行看上去才居中。
    const tail = last && /[，。？！、；：]$/.test(segment) ? segment.slice(-1) : '';

    if (!tail) {
        return [segment];
    }

    const mark = document.createElement('span');
    mark.className = 'tail';
    mark.textContent = tail;

    return [segment.slice(0, -1), mark];
}
