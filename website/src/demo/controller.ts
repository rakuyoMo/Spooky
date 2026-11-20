import { patch } from './dom.ts';
import type { ScrollMemory } from './dom.ts';
import type { ChangeData, DemoState, RepoData, Step } from './model.ts';
import {
    commit,
    createState,
    push,
    selectCommit,
    selectFile,
    selectLine,
    selectRef,
    selectSide,
    selectView,
    stageAll,
    stageHunk,
    stageSelection,
    toggleFile,
} from './model.ts';
import type { Place, RenderContext, UiState } from './render/context.ts';
import { createUi } from './render/context.ts';
import { quickItems } from './render/overlays.ts';
import type { Regions } from './render/regions.ts';
import { renderRegions } from './render/regions.ts';
import type { DemoStrings, DemoText } from './text.ts';
import { createText } from './text.ts';

/**
 * 演示窗口在浏览器里的控制器：接住点击、键盘与输入，改状态，再把变了的区域写回页面。
 */

/** 页面交给控制器的东西。 */
export interface DemoOptions {
    /** 演示的外层元素：窗口、步骤条与提示都在里面。 */
    root: HTMLElement;
    data: RepoData;
    strings: DemoStrings;
    lang: string;
    appIcon: string;

    /** 网站自己的提示文字：演示里没有的功能、获取后没有新提交。 */
    notices: { unavailable: string; upToDate: string };

    /** 按需取全部提交的变更集。 */
    loadChanges: () => Promise<Record<string, ChangeData[]>>;
}

/** 每一步完成时在 `document` 上发出的事件。 */
export const stepEvents: Record<Step, string> = {
    stage: 'spooky-demo:staged',
    commit: 'spooky-demo:committed',
    push: 'spooky-demo:pushed',
};

/** 获取按钮转圈的时长。 */
const fetchDuration = 1200;

/** 提示停留的时长。 */
const toastDuration = 2600;

/** 提交信息的输入框与展开后的选项：焦点在它们里面时提交区展开。 */
const messageArea = '.sd-commit :is(.sd-field, .sd-details)';

/** 启动演示。 */
export function startDemo(options: DemoOptions): void {
    new Demo(options).start();
}

/** 一个演示窗口的全部运行状态。 */
class Demo {
    private state: DemoState;
    private ui: UiState = createUi();
    private changes: Record<string, ChangeData[]> | null = null;
    private loading: Promise<void> | null = null;
    private regions: Regions;
    private readonly scrolls: ScrollMemory = new Map();
    private readonly text: DemoText;
    private readonly frame: HTMLElement;
    private readonly toast: HTMLElement | null;
    private toastTimer = 0;

    /** 打开浮层之前焦点所在的控件，关掉浮层时放回去。 */
    private opener: HTMLElement | null = null;

    /** 用页面给的数据建出初始状态；窗口的 HTML 已在构建时写好，与初始状态一致。 */
    constructor(private readonly options: DemoOptions) {
        this.state = createState(options.data);
        this.text = createText(options.strings, options.lang);
        this.frame = options.root.querySelector<HTMLElement>('.sd-window') ?? options.root;
        this.toast = options.root.querySelector<HTMLElement>('.sd-toast');
        this.regions = renderRegions(this.context());
    }

    /** 接上事件；脚本加载之前访客已经在输入框里打的字记进状态。 */
    start(): void {
        const { root } = this.options;

        this.frame.addEventListener('click', (event) => this.click(event));
        this.frame.addEventListener('keydown', (event) => this.keydown(event));
        this.frame.addEventListener('input', (event) => this.input(event));
        root.addEventListener('click', (event) => this.guideClick(event));
        root.addEventListener('pointerover', (event) => this.highlight(event.target));
        root.addEventListener('pointerout', () => this.highlight(null));
        root.addEventListener('focusin', (event) => this.highlight(event.target));
        root.addEventListener('focusout', () => this.highlight(null));
        this.trackComposing();

        // 第一次和窗口打交道时就开始取变更集，打开历史时多半已经取好
        this.frame.addEventListener('pointerdown', () => void this.ensureChanges(), { once: true });
        this.frame.addEventListener('focusin', () => void this.ensureChanges(), { once: true });

        root.dataset.ready = 'true';

        // 脚本加载之前打的字记进状态，剩余字数与提交按钮随之重绘
        const typed = (name: string) =>
            this.frame.querySelector<HTMLInputElement | HTMLTextAreaElement>(`[data-input="${name}"]`)?.value;

        this.update({
            ...this.state,
            subject: typed('subject') ?? this.state.subject,
            body: typed('body') ?? this.state.body,
        });
    }

    // MARK: - 更新

    /** 本轮渲染的上下文。 */
    private context(): RenderContext {
        return {
            state: this.state,
            ui: this.ui,
            data: this.options.data,
            text: this.text,
            changes: this.changes,
            appIcon: this.options.appIcon,
        };
    }

    /** 改状态并重绘变了的区域；新完成的步骤发出事件。 */
    private update(state: DemoState, ui: Partial<UiState> = {}): void {
        const before = this.state.done;

        this.state = state;
        this.ui = { ...this.ui, ...ui };

        const next = renderRegions(this.context());

        patch(this.frame, this.regions, next, this.scrolls);
        this.regions = next;
        this.syncChrome();

        for (const step of Object.keys(stepEvents) as Step[]) {
            if (state.done[step] && !before[step]) {
                document.dispatchEvent(new CustomEvent(stepEvents[step]));
            }
        }
    }

    /** 不在区域里的部分：输入框的值、窗口上的视图标记、快捷操作的选中项与步骤条。 */
    private syncChrome(): void {
        const values: Record<string, string> = {
            subject: this.state.subject,
            body: this.state.body,
            query: this.ui.query,
        };

        for (const field of this.frame.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('[data-input]')) {
            const value = values[field.dataset.input ?? ''] ?? '';

            if (field.value !== value) {
                field.value = value;
            }
        }

        this.frame.dataset.view = this.state.view;
        this.frame
            .querySelector('.sd-quick-input')
            ?.setAttribute('aria-activedescendant', `sd-quick-${this.ui.quickIndex}`);

        for (const item of this.options.root.querySelectorAll<HTMLElement>('[data-step]')) {
            const done = this.state.done[item.dataset.step as Step];

            item.classList.toggle('is-done', done);
            item.querySelector('.sd-step-state')?.toggleAttribute('hidden', !done);
        }
    }

    // MARK: - 点击

    /** 委托给 `data-action` 的点击。 */
    private click(event: MouseEvent): void {
        const target = (event.target as Element).closest<HTMLElement>('[data-action]');

        if (!target || !this.frame.contains(target) || target.matches(':disabled')) {
            return;
        }

        this.perform(target.dataset.action ?? '', target.dataset.arg ?? '', event.shiftKey, target);
    }

    /** 执行一个动作。 */
    private perform(action: string, arg: string, shift: boolean, source: HTMLElement | null): void {
        if (this.workingAction(action, arg, shift)) {
            return;
        }

        if (this.navigationAction(action, arg)) {
            return;
        }

        this.windowAction(action, arg, source);
    }

    /** 工作区里的动作：选文件、暂存、选行、提交。 */
    private workingAction(action: string, arg: string, shift: boolean): boolean {
        const state = this.state;

        switch (action) {
            case 'select-file':
                this.update(selectFile(state, arg));
                return true;
            case 'toggle-file':
                this.update(toggleFile(state, arg));
                return true;
            case 'stage-all':
            case 'unstage-all':
                this.update(stageAll(state, action === 'stage-all'));
                return true;
            case 'side':
                this.update(selectSide(state, arg === 'staged' ? 'staged' : 'unstaged'));
                return true;
            case 'stage-hunk':
                this.update(stageHunk(state, Number(arg)));
                return true;
            case 'stage-lines':
                this.update(stageSelection(state));
                return true;
            case 'pick': {
                const [hunk, op] = arg.split(':').map(Number);

                this.update(selectLine(state, hunk ?? 0, op ?? 0, shift));
                return true;
            }
            case 'commit':
                this.commit();
                return true;
            case 'pin':
                this.update(state, { pinned: !this.ui.pinned });
                return true;
            default:
                return false;
        }
    }

    /** 换位置的动作：视图、引用、提交、后退与前进。 */
    private navigationAction(action: string, arg: string): boolean {
        const { data } = this.options;

        switch (action) {
            case 'view': {
                const view = arg === 'history' || arg === 'stashes' ? arg : 'working';

                this.navigate(selectView(this.state, data, view));
                return true;
            }
            case 'ref':
                this.navigate(selectRef(this.state, data, arg));
                return true;
            case 'select-commit':
                this.update(selectCommit(this.state, arg));
                return true;
            case 'stash':
                this.update(this.state, { stashSelected: true });
                return true;
            case 'back':
            case 'forward':
                this.travel(action);
                return true;
            default:
                return false;
        }
    }

    /** 窗口上的其余动作：折叠、浮层、获取、推送与演示里没有的功能。 */
    private windowAction(action: string, arg: string, source: HTMLElement | null): void {
        switch (action) {
            case 'toggle-group':
                this.update(this.state, { closedGroups: toggled(this.ui.closedGroups, arg) });
                break;
            case 'toggle-file-changes':
                this.update(this.state, { collapsed: toggled(this.ui.collapsed, arg) });
                break;
            case 'collapse-all':
            case 'expand-all':
                this.collapseAll(arg, action === 'collapse-all');
                break;
            case 'toggle-metadata':
                this.update(this.state, { metadataCollapsed: !this.ui.metadataCollapsed });
                break;
            case 'quick':
                this.openOverlay('quick', source);
                break;
            case 'push':
                this.openOverlay('push', source);
                break;
            case 'close':
                this.closeOverlay();
                break;
            case 'confirm-push':
                this.update(push(this.state, this.options.data));
                this.closeOverlay();
                break;
            case 'quick-pick':
                this.pick(Number(arg));
                break;
            case 'fetch':
                this.fetch();
                break;
            case 'unavailable':
                this.notify(this.options.notices.unavailable);
                break;
        }
    }

    // MARK: - 各个动作

    /** 提交：标题为空或没有暂存的改动时不做任何事；提交之后焦点离开提交信息，提交区收起。 */
    private commit(): void {
        const next = commit(this.state, this.options.data, new Date());

        if (next === this.state) {
            return;
        }

        this.update(next);
        this.frame.querySelector<HTMLElement>(`${messageArea} :focus`)?.blur();
    }

    /** 换到新位置，原来的位置记进后退的栈。 */
    private navigate(next: DemoState): void {
        const from = placeOf(this.state);
        const to = placeOf(next);

        if (from.view === to.view && from.historyRef === to.historyRef) {
            this.update(next);
            return;
        }

        this.update(next, { back: [...this.ui.back, from], forward: [] });
        void this.ensureChanges();
    }

    /** 后退或前进一步。 */
    private travel(direction: 'back' | 'forward'): void {
        const stack = direction === 'back' ? this.ui.back : this.ui.forward;
        const place = stack.at(-1);

        if (!place) {
            return;
        }

        const current = placeOf(this.state);
        const rest = stack.slice(0, -1);
        const state = selectView({ ...this.state, historyRef: place.historyRef }, this.options.data, place.view);

        this.update(
            state,
            direction === 'back'
                ? { back: rest, forward: [...this.ui.forward, current] }
                : { back: [...this.ui.back, current], forward: rest },
        );
    }

    /** 全部折叠或展开一个提交的文件。 */
    private collapseAll(scope: string, collapse: boolean): void {
        const changes = this.changes?.[scope] ?? this.state.addedChanges[scope] ?? [];
        const keys = changes.map((change) => `${scope}:${change.path}`);
        const others = this.ui.collapsed.filter((key) => !keys.includes(key));

        this.update(this.state, { collapsed: collapse ? [...others, ...keys] : others });
    }

    /** 打开推送对话框或快捷操作，焦点移进去。 */
    private openOverlay(overlay: 'push' | 'quick', source: HTMLElement | null): void {
        const active = document.activeElement;

        this.opener = source ?? (active instanceof HTMLElement ? active : null);
        this.update(this.state, { overlay, query: '', quickIndex: 0 });

        if (overlay === 'quick') {
            void this.ensureChanges();
        }

        const targetSelector = overlay === 'quick' ? '.sd-quick-input' : '.sd-default';
        const target = this.frame.querySelector<HTMLElement>(targetSelector);

        target?.focus({ preventScroll: true });
    }

    /** 关掉浮层，焦点回到打开它的控件。 */
    private closeOverlay(): void {
        const opener = this.opener;

        this.opener = null;
        this.update(this.state, { overlay: null, query: '', quickIndex: 0 });

        const selector = opener?.dataset.action ? `[data-action="${opener.dataset.action}"]` : null;
        const target = selector ? this.frame.querySelector<HTMLElement>(selector) : null;

        (target ?? this.frame).focus({ preventScroll: true });
    }

    /** 快捷操作里回车或点一行：去对应的视图、引用、文件或提交。 */
    private pick(index: number): void {
        const item = quickItems(this.context())[index];

        if (!item) {
            return;
        }

        this.opener = null;
        this.update(this.state, { overlay: null, query: '', quickIndex: 0 });

        const { data } = this.options;

        switch (item.kind) {
            case 'navigation':
                this.perform('view', item.id, false, null);
                break;
            case 'commit':
                this.navigate(
                    selectCommit(
                        selectView({ ...this.state, historyRef: null }, data, 'history'),
                        item.id,
                    ),
                );
                break;
            case 'file':
                this.pickFile(item.id);
                break;
            default:
                this.navigate(selectRef(this.state, data, item.id));
        }

        this.frame.focus({ preventScroll: true });
    }

    /** 快捷操作里选中文件：有改动的文件在工作区里选中，其余的文件演示里没有可看的地方。 */
    private pickFile(path: string): void {
        if (!this.state.files.some((file) => file.path === path)) {
            this.notify(this.options.notices.unavailable);
            return;
        }

        this.navigate(selectFile({ ...this.state, view: 'working' }, path));
    }

    /** 获取：转一会儿圈，然后告诉访客远端没有新提交。 */
    private fetch(): void {
        this.update(this.state, { fetching: true });

        window.setTimeout(() => {
            this.update(this.state, { fetching: false });
            this.notify(this.options.notices.upToDate);
        }, fetchDuration);
    }

    /** 在窗口下方显示一条提示，读屏软件也会读出来。 */
    private notify(message: string): void {
        if (!this.toast) {
            return;
        }

        window.clearTimeout(this.toastTimer);
        this.toast.textContent = message;
        this.toast.classList.add('is-visible');
        this.toastTimer = window.setTimeout(() => this.toast?.classList.remove('is-visible'), toastDuration);
    }

    /** 取全部提交的变更集；只取一次。 */
    private ensureChanges(): Promise<void> {
        this.loading ??= this.options.loadChanges().then((changes) => {
            this.changes = changes;
            this.update(this.state);
        });

        return this.loading;
    }

    // MARK: - 键盘与输入

    /** 窗口里的快捷键。 */
    private keydown(event: KeyboardEvent): void {
        const target = event.target as HTMLElement;
        const command = event.metaKey || event.ctrlKey;

        if (command && event.key === 'Enter' && target.closest('[data-commit]')) {
            event.preventDefault();
            this.commit();
            return;
        }

        if (command && event.shiftKey && event.key.toLowerCase() === 'a') {
            event.preventDefault();
            this.openOverlay('quick', target);
            return;
        }

        if (event.key === 'Escape' && this.ui.overlay) {
            event.preventDefault();
            this.escape();
            return;
        }

        if (target.dataset.input === 'query') {
            this.quickKey(event);
            return;
        }

        if (target.getAttribute('role') === 'option') {
            this.optionKey(event, target);
            return;
        }

        if (target.matches('.sd-side-list .sd-row')) {
            this.sidebarKey(event, target);
        }
    }

    /** 侧边栏行上的方向键：上下移动焦点，Home 与 End 到首尾，Tab 位置跟着焦点走。 */
    private sidebarKey(event: KeyboardEvent, target: HTMLElement): void {
        const rows = [...this.frame.querySelectorAll<HTMLElement>('.sd-side-list .sd-row')];
        const index = rows.indexOf(target);

        const targets: Record<string, HTMLElement | undefined> = {
            ArrowDown: rows[index + 1],
            ArrowUp: rows[index - 1],
            Home: rows[0],
            End: rows.at(-1),
        };

        const next = targets[event.key];

        if (!next) {
            return;
        }

        event.preventDefault();
        target.tabIndex = -1;
        next.tabIndex = 0;
        next.focus();
    }

    /** Esc：快捷操作里先清空输入，再按一次才关掉。 */
    private escape(): void {
        if (this.ui.overlay === 'quick' && this.ui.query !== '') {
            this.update(this.state, { query: '', quickIndex: 0 });
            return;
        }

        this.closeOverlay();
    }

    /** 快捷操作输入框里的方向键与回车。 */
    private quickKey(event: KeyboardEvent): void {
        const count = quickItems(this.context()).length;

        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();

            const step = event.key === 'ArrowDown' ? 1 : -1;
            const quickIndex = count === 0 ? 0 : (this.ui.quickIndex + step + count) % count;

            this.update(this.state, { quickIndex });
            this.frame.querySelector(`#sd-quick-${quickIndex}`)?.scrollIntoView({ block: 'nearest' });
            return;
        }

        if (event.key === 'Enter') {
            event.preventDefault();
            this.pick(this.ui.quickIndex);
        }
    }

    /** 列表行上的方向键、回车与空格：方向键移动选中并把焦点跟过去。 */
    private optionKey(event: KeyboardEvent, target: HTMLElement): void {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.perform(target.dataset.action ?? '', target.dataset.arg ?? '', false, target);
            return;
        }

        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') {
            return;
        }

        const listbox = target.closest('[role="listbox"]');
        const rows = [...(listbox?.querySelectorAll<HTMLElement>('[role="option"]') ?? [])];
        const next = rows[rows.indexOf(target) + (event.key === 'ArrowDown' ? 1 : -1)];

        if (!next) {
            return;
        }

        event.preventDefault();
        this.perform(next.dataset.action ?? '', next.dataset.arg ?? '', false, next);

        const nextArg = CSS.escape(next.dataset.arg ?? '');
        const moved = this.frame.querySelector<HTMLElement>(`[role="option"][data-arg="${nextArg}"]`);

        moved?.focus({ preventScroll: true });
        moved?.scrollIntoView({ block: 'nearest' });
    }

    /**
     * 焦点在提交信息的输入框或展开后的选项上时给窗口打上 `data-composing`，提交区按它展开。
     * 选项也算在内：它们一得到焦点提交区就收起的话，用键盘走不到它们。
     *
     * 焦点从标题框换到正文框的那一刻两个框都没有焦点，浏览器这时会先按收起的样式判断正文框能不能聚焦；
     * 所以离开时等焦点落定再看，不跟着 `:focus-within` 收起。
     *
     * 提交区一收起，它下面的内容整个上移。按下鼠标时焦点就离开了输入框，这时收起的话，松开时指针下面已经换了内容，点击落不到按下的控件上；
     * 所以按着的时候不收起，松开之后再看。
     */
    private trackComposing(): void {
        const inMessage = () => document.activeElement?.closest(messageArea) != null;

        let pressed = false;

        const settle = () => {
            if (!pressed && !inMessage()) {
                delete this.frame.dataset.composing;
            }
        };

        const release = () => {
            pressed = false;
            setTimeout(settle);
        };

        this.frame.addEventListener('focusin', () => {
            if (inMessage()) {
                this.frame.dataset.composing = 'true';
            }
        });

        this.frame.addEventListener('focusout', () => setTimeout(settle));

        // 在页面上任何地方按下都算：窄屏上窗口随内容变高，提交区收起时窗口下面的内容也跟着上移
        document.addEventListener(
            'pointerdown',
            (event) => {
                pressed = event.button === 0;
            },
            true,
        );

        document.addEventListener('pointerup', release, true);
        document.addEventListener('pointercancel', release, true);

        // 按提交区里的按钮时焦点留在原处，提交区保持展开
        this.frame.addEventListener('mousedown', (event) => {
            const control = (event.target as Element).closest('.sd-commit :is(button, [data-action])');

            if (control && inMessage()) {
                event.preventDefault();
            }
        });
    }

    /** 输入框里的文字写回状态；只重绘剩余字数、按钮与快捷操作的结果。 */
    private input(event: Event): void {
        const field = event.target as HTMLInputElement | HTMLTextAreaElement;

        switch (field.dataset.input) {
            case 'subject':
                this.update({ ...this.state, subject: field.value });
                break;
            case 'body':
                this.update({ ...this.state, body: field.value });
                break;
            case 'query':
                this.update(this.state, { query: field.value, quickIndex: 0 });
                break;
        }
    }

    // MARK: - 步骤条

    /** 步骤条与重置按钮。 */
    private guideClick(event: MouseEvent): void {
        const target = event.target as Element;

        if (target.closest('[data-reset]')) {
            this.reset();
            return;
        }

        const step = target.closest<HTMLElement>('[data-step]')?.dataset.step;

        if (step) {
            this.focusStep(step);
        }
    }

    /** 点步骤：焦点移到窗口里对应的第一个控件。 */
    private focusStep(step: string): void {
        const controls = [...this.frame.querySelectorAll<HTMLElement>(`[data-guide="${step}"]`)];
        const target = controls.find(
            (control) => !control.matches(':disabled') && control.offsetParent !== null,
        );

        target?.focus();
    }

    /** 悬停或聚焦步骤时，窗口里对应的控件描上边框。 */
    private highlight(target: EventTarget | null): void {
        const step =
            target instanceof Element
                ? target.closest<HTMLElement>('[data-step]')?.dataset.step
                : undefined;

        if (step) {
            this.frame.dataset.highlight = step;
        } else {
            delete this.frame.dataset.highlight;
        }
    }

    /** 重置演示：回到初始状态，已取来的变更集留着。 */
    private reset(): void {
        this.scrolls.clear();
        this.opener = null;
        this.update(createState(this.options.data), createUi());

        // 留在页面上没被替换的列表同样回到顶上
        for (const element of this.frame.querySelectorAll<HTMLElement>('[data-scroll]')) {
            element.scrollTop = 0;
        }
    }
}

// MARK: - Helpers

/** 状态所在的位置。 */
function placeOf(state: DemoState): Place {
    return { view: state.view, historyRef: state.historyRef };
}

/** 有就去掉，没有就加上。 */
function toggled(values: readonly string[], value: string): string[] {
    return values.includes(value) ? values.filter((item) => item !== value) : [...values, value];
}
