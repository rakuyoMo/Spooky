import type { Regions } from './render/regions.ts';
import { compose, parents } from './render/regions.ts';

/**
 * 把新一轮的区域写进页面：只替换内容变了的最外层区域，替换前后保住焦点与各列表的滚动位置。
 */

/** 滚动位置的记忆，键是 `data-scroll`；切走再切回来时接着上次的位置。 */
export type ScrollMemory = Map<string, [top: number, left: number]>;

/**
 * 替换变了的区域。
 *
 * `frame` 是整窗骨架所在的元素，对应 `window` 区域；其余区域按 `data-region` 找。
 */
export function patch(frame: HTMLElement, previous: Regions, next: Regions, scrolls: ScrollMemory): void {
    const changed = new Set([...next.keys()].filter((name) => previous.get(name) !== next.get(name)));

    if (changed.size === 0) {
        return;
    }

    const parentOf = parents(next);

    // 祖先区域也变了的，随祖先一起换掉
    const outermost = [...changed].filter((name) => {
        for (let parent = parentOf.get(name); parent; parent = parentOf.get(parent)) {
            if (changed.has(parent)) {
                return false;
            }
        }

        return true;
    });

    const focus = focusKey(frame);

    for (const name of outermost) {
        const element = name === 'window' ? frame : frame.querySelector<HTMLElement>(`[data-region="${name}"]`);

        if (!element) {
            continue;
        }

        remember(element, scrolls);
        element.innerHTML = compose(next, name);
        restore(element, scrolls);
    }

    if (focus && !frame.contains(document.activeElement)) {
        refocus(frame, focus);
    }
}

// MARK: - Private

/** 焦点所在的控件：按动作与参数，或按输入框的名字认出替换后的同一个控件。 */
function focusKey(frame: HTMLElement): string | null {
    const active = document.activeElement;

    if (!(active instanceof HTMLElement) || !frame.contains(active)) {
        return null;
    }

    if (active.dataset.input) {
        return `[data-input="${active.dataset.input}"]`;
    }

    if (active.dataset.action) {
        const arg = active.dataset.arg;
        const argSelector = arg === undefined ? '' : `[data-arg="${CSS.escape(arg)}"]`;

        return `[data-action="${active.dataset.action}"]${argSelector}`;
    }

    return null;
}

/** 替换后把焦点放回同一个控件；它已经不在或不能用时，焦点留在窗口上，键盘用户不会被甩回页面开头。 */
function refocus(frame: HTMLElement, selector: string): void {
    const target = frame.querySelector<HTMLElement>(selector);

    if (target && !target.matches(':disabled')) {
        target.focus({ preventScroll: true });
        return;
    }

    frame.focus({ preventScroll: true });
}

/** 新内容里有同名列表的，滚回记下的位置。 */
function restore(element: HTMLElement, scrolls: ScrollMemory): void {
    for (const target of element.querySelectorAll<HTMLElement>('[data-scroll]')) {
        const saved = scrolls.get(target.dataset.scroll ?? '');

        if (saved) {
            target.scrollTop = saved[0];
            target.scrollLeft = saved[1];
        }
    }
}

/** 记下区域里各列表的滚动位置。 */
function remember(element: HTMLElement, scrolls: ScrollMemory): void {
    const targets = [element, ...element.querySelectorAll<HTMLElement>('[data-scroll]')];

    for (const target of targets) {
        const key = target.dataset.scroll;

        if (key) {
            scrolls.set(key, [target.scrollTop, target.scrollLeft]);
        }
    }
}
