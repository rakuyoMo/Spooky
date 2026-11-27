import { patch } from './dom.ts';
import type { ScrollMemory } from './dom.ts';
import type { ChangeData, DemoState, RepoData, Step } from './model.ts';
import {
    commit,
    createState,
    multilineParts,
    newline,
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
import type { PullRequest, RequestLabel } from './pull-requests.ts';
import { createRequest, requestChanges, requestLabels, requestPages, visibleRequests } from './pull-requests.ts';
import type { DemoForm, Place, RenderContext, UiState } from './render/context.ts';
import { createUi, locationMethods, settingsPages } from './render/context.ts';
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

    /** 工具栏 » 的名字。 */
    overflowLabel: string;

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

/** 外层容器窄于这个宽度时窗口用极窄版式，与 `demo.css` 里的界线相同。 */
const narrowWidth = 820;

/** 提交信息的输入框与展开后的选项：焦点在它们里面时提交区展开。 */
const messageArea = '.sd-commit :is(.sd-field, .sd-details)';

/** 窗口上能通过按钮打开的表单。 */
const demoForms: readonly DemoForm[] = [
    'pr-create', 'pr-edit', 'pr-comment', 'pr-checkout', 'pr-close', 'pr-merge', 'location',
];

/** 启动演示。 */
export function startDemo(options: DemoOptions): void {
    new Demo(options).start();
}

/** 一个演示窗口的全部运行状态。 */
class Demo {
    private state: DemoState;
    private ui: UiState;
    private changes: Record<string, ChangeData[]> | null = null;
    private loading: Promise<void> | null = null;
    private regions: Regions;
    private readonly scrolls: ScrollMemory = new Map();
    private readonly text: DemoText;
    private readonly frame: HTMLElement;
    private readonly toast: HTMLElement | null;
    private toastTimer = 0;

    /** 在当前页面第一次看到极窄版式后，步骤一直显示为已完成。 */
    private sawNarrowLayout = false;

    /** 打开浮层之前焦点所在的控件，关掉浮层时放回去。 */
    private opener: HTMLElement | null = null;

    /** 用页面给的数据建出初始状态；窗口的 HTML 已在构建时写好，与初始状态一致。 */
    constructor(private readonly options: DemoOptions) {
        this.state = createState(options.data);
        this.ui = createUi(options.data);
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
        this.frame.addEventListener('change', (event) => this.changeForm(event));
        this.frame.addEventListener('submit', (event) => this.submitForm(event));
        this.frame.addEventListener('paste', (event) => this.paste(event));
        root.addEventListener('click', (event) => this.guideClick(event));
        root.addEventListener('pointerover', (event) => this.highlight(event.target));
        root.addEventListener('pointerout', () => this.highlight(null));
        root.addEventListener('focusin', (event) => this.highlight(event.target));
        root.addEventListener('focusout', () => this.highlight(null));
        this.trackComposing();
        this.trackLayout();

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
            overflowLabel: this.options.overflowLabel,
        };
    }

    /** 改状态并重绘变了的区域；新完成的步骤发出事件。 */
    private update(state: DemoState, ui: Partial<UiState> = {}): void {
        const before = this.state.done;
        const view = this.state.view;

        this.state = state;
        this.ui = { ...this.ui, ...ui };

        const next = renderRegions(this.context());

        patch(this.frame, this.regions, next, this.scrolls);
        this.regions = next;
        this.syncChrome();

        if (state.view !== view) {
            this.revealCompactEntry();
        }

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
        this.frame.toggleAttribute('data-sidebar-open', this.ui.sidebarOpen);
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

        // 选了 » 的菜单里的一项：先收起菜单，再执行它
        if (target.closest('.sd-menu')) {
            this.update(this.state, { overlay: null });
        }

        this.perform(target.dataset.action ?? '', target.dataset.arg ?? '', event.shiftKey, target);
    }

    /** 执行一个动作。 */
    private perform(action: string, arg: string, shift: boolean, source: HTMLElement | null): void {
        if (this.workingAction(action, arg, shift)) {
            return;
        }

        if (this.navigationAction(action, arg) || this.requestAction(action, arg)) {
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
                const view = arg === 'history' || arg === 'stashes' || arg === 'requests' || arg === 'settings'
                    ? arg
                    : 'working';

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

    /** 窗口上的其余动作：折叠、极窄版式里的侧边栏、浮层、获取、推送与演示里没有的功能。 */
    private windowAction(action: string, arg: string, source: HTMLElement | null): void {
        switch (action) {
            case 'toggle-group':
                this.update(this.state, { closedGroups: toggled(this.ui.closedGroups, arg) });
                break;
            case 'toggle-file-changes':
                this.update(this.state, { expandedFiles: toggled(this.ui.expandedFiles, arg) });
                break;
            case 'select-change':
                this.update(this.state, { selectedFileChange: arg });
                break;
            case 'collapse-all':
            case 'expand-all':
                this.collapseAll(arg, action === 'collapse-all');
                break;
            case 'toggle-metadata':
                this.update(this.state, { metadataCollapsed: !this.ui.metadataCollapsed });
                break;
            case 'toggle-sidebar':
                this.update(this.state, { sidebarOpen: !this.ui.sidebarOpen });
                break;
            case 'more':
                this.toggleOverflow(source);
                break;
            case 'push':
                this.openOverlay('push', source);
                break;
            case 'show-form': {
                const form = demoForms.find((name) => name === arg);

                if (form) {
                    this.openOverlay(form, source);
                }

                break;
            }
            case 'settings-page': {
                const page = settingsPages.find((name) => name === arg);

                if (page) {
                    this.update(this.state, { settingsPage: page });
                }

                break;
            }
            case 'close':
                this.closeOverlay();
                break;
            case 'confirm-push':
                this.update(push(this.state));
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
        const sidebarFocused = this.ui.sidebarOpen && document.activeElement?.closest('.sd-sidebar');

        if (from.view === to.view && from.historyRef === to.historyRef) {
            this.update(next, { sidebarOpen: false });
        } else {
            this.update(next, { back: [...this.ui.back, from], forward: [], sidebarOpen: false });
            void this.ensureChanges();
        }

        if (sidebarFocused) {
            this.frame.querySelector<HTMLElement>('.sd-compact-toggle')?.focus({ preventScroll: true });
        }
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
        // 前进和后退复原当时的引用范围，与直接打开全部历史共用提交选择规则
        const state = selectView(this.state, this.options.data, place.view, place.historyRef);

        this.update(
            state,
            direction === 'back'
                ? { back: rest, forward: [...this.ui.forward, current] }
                : { back: [...this.ui.back, current], forward: rest },
        );
    }

    /** 全部折叠或展开一个提交的文件。 */
    private collapseAll(scope: string, collapse: boolean): void {
        const request = this.ui.requests.find(({ id }) => scope === `pr:${id}`);
        const changes = request && this.changes
            ? requestChanges(this.options.data, request, this.changes)
            : this.state.addedChanges[scope] ?? this.changes?.[scope] ?? [];
        const keys = changes.map((change) => `${scope}:${change.path}`);
        const others = this.ui.expandedFiles.filter((key) => !keys.includes(key));

        this.update(this.state, { expandedFiles: collapse ? others : [...others, ...keys] });
    }

    /** 请求列表和详情的选择；筛选结果变了时，保持可见的请求或选择首项。 */
    private requestAction(action: string, arg: string): boolean {
        switch (action) {
            case 'pr-filter': {
                const allRequests = arg === 'all';
                const requests = visibleRequests(this.ui.requests, allRequests);

                this.update(this.state, requests.some(({ id }) => id === this.ui.requestId)
                    ? { allRequests }
                    : { allRequests, requestId: requests[0]?.id ?? null, requestPage: 'conversation', requestCommit: null });
                return true;
            }
            case 'pr-select':
                if (this.ui.requestId !== Number(arg)) {
                    this.update(this.state, { requestId: Number(arg), requestPage: 'conversation', requestCommit: null });
                }

                return true;
            case 'pr-page': {
                const page = requestPages.find((name) => name === arg);

                if (page) {
                    this.update(this.state, { requestPage: page });
                }

                return true;
            }
            case 'pr-commit':
                this.update(this.state, { requestPage: 'commits', requestCommit: arg });
                return true;
            case 'pr-label': {
                const request = this.ui.requests.find(({ id }) => id === this.ui.requestId);

                if (request && Object.hasOwn(requestLabels, arg)) {
                    const labels = toggled(request.labels, arg as RequestLabel);

                    this.update(this.state, {
                        requests: this.ui.requests.map((item) => item.id === request.id ? { ...item, labels } : item),
                    });
                }

                return true;
            }
            default:
                return false;
        }
    }

    /** 打开或收起工具栏 » 的菜单：列出此刻工具栏上看不到的项，焦点移到第一项。 */
    private toggleOverflow(source: HTMLElement | null): void {
        if (this.ui.overlay === 'more') {
            this.closeOverlay();
            return;
        }

        const items = [...this.frame.querySelectorAll<HTMLElement>('[data-item]')];
        const shown = new Set(items.filter((item) => item.offsetParent !== null).map((item) => item.dataset.item));
        const overflow = [...new Set(items.map((item) => item.dataset.item ?? ''))].filter((item) => !shown.has(item));

        this.opener = source;
        this.update(this.state, { overlay: 'more', overflow });
        this.frame.querySelector<HTMLElement>('.sd-menu-item:not(:disabled)')?.focus({ preventScroll: true });
    }

    /** 打开对话框或快捷操作并挪入焦点；对话框打开时收起侧边栏。 */
    private openOverlay(overlay: 'push' | 'quick' | DemoForm, source: HTMLElement | null): void {
        const active = document.activeElement;

        this.opener = source ?? (active instanceof HTMLElement ? active : null);
        this.update(this.state, {
            overlay,
            query: '',
            quickIndex: 0,
            locationMethod: this.ui.location.method,
            sidebarOpen: overlay === 'quick' && this.ui.sidebarOpen,
        });

        if (overlay === 'quick') {
            void this.ensureChanges();
        }

        const field = this.frame.querySelector<HTMLElement>('.sd-demo-form [data-form-field]');
        const target = field ?? this.frame.querySelector<HTMLElement>(overlay === 'quick' ? '.sd-quick-input' : '.sd-default');

        target?.focus({ preventScroll: true });
    }

    /** 关掉浮层，焦点回到打开它的控件；控件已消失时回到窗口。 */
    private closeOverlay(): void {
        const opener = this.opener;
        const action = opener?.dataset.action;
        const arg = opener?.dataset.arg;

        this.opener = null;
        this.update(this.state, { overlay: null, query: '', quickIndex: 0 });

        const selector = action === undefined ? null :
            `[data-action="${CSS.escape(action)}"]${arg === undefined ? '' : `[data-arg="${CSS.escape(arg)}"]`}`;
        const targets = selector ? [...this.frame.querySelectorAll<HTMLElement>(selector)] : [];
        const target = targets.find((control) => control.offsetParent !== null && !control.matches(':disabled'));

        (target ?? this.frame).focus({ preventScroll: true });
    }

    /** 切换本机位置的方法，表单按该方法显示目录字段。 */
    private changeForm(event: Event): void {
        const field = event.target;

        if (!(field instanceof HTMLSelectElement) || field.dataset.formField !== 'method') {
            return;
        }

        const method = locationMethods.find((value) => value === field.value);

        if (method) {
            this.update(this.state, { locationMethod: method });
        }
    }

    /** 将表单里的值写回演示状态；挂载和托管服务操作都由示例数据反馈。 */
    private submitForm(event: SubmitEvent): void {
        const form = event.target;

        if (!(form instanceof HTMLFormElement)) {
            return;
        }

        event.preventDefault();

        const action = form.dataset.demoForm;
        const { data } = this.options;
        const fields = new FormData(form);
        const read = (name: string) => String(fields.get(name) ?? '').trim();
        const date = Math.floor(Date.now() / 1000);

        if (action === 'location') {
            const method = this.ui.locationMethod;
            const folder = method === 'smbMount' ? `/Volumes/${data.repository}` : read('folder');

            if ((method === 'sshfsMount' || method === 'chosenFolder') && !folder) {
                return;
            }

            this.update(this.state, { location: { method, folder } });
            this.closeOverlay();
            return;
        }

        if (action === 'pr-create') {
            const request = createRequest(data, this.ui.requests, read('source'), read('title'), read('description'), date);

            if (request) {
                this.update(this.state, {
                    requests: [request, ...this.ui.requests],
                    requestId: request.id,
                    requestPage: 'conversation',
                    requestCommit: null,
                });
                this.closeOverlay();
            }

            return;
        }

        const request = this.ui.requests.find(({ id }) => id === this.ui.requestId);

        if (request) {
            this.submitRequestAction(request, action, read, date);
        }
    }

    /** 修改当前请求。关闭或合并后切到全部请求，保留当前请求供访客查看结果。 */
    private submitRequestAction(
        request: PullRequest,
        action: string | undefined,
        read: (name: string) => string,
        date: number,
    ): void {
        let changed: PullRequest;

        switch (action) {
            case 'pr-edit':
                if (!read('title')) {
                    return;
                }

                changed = { ...request, title: read('title'), description: read('description') };
                break;
            case 'pr-comment':
                if (!read('comment')) {
                    return;
                }

                changed = {
                    ...request,
                    comments: [...request.comments, { author: this.options.data.identity.name, date, body: read('comment') }],
                };
                break;
            case 'pr-checkout':
                this.checkoutRequest(request, read('branch'));
                return;
            case 'pr-close':
            case 'pr-merge':
                if (request.status !== 'open') {
                    return;
                }

                changed = { ...request, status: action === 'pr-close' ? 'closed' : 'merged' };
                break;
            default:
                return;
        }

        this.update(this.state, {
            requests: this.ui.requests.map((item) => item.id === request.id ? changed : item),
            allRequests: this.ui.allRequests || changed.status !== 'open',
        });
        this.closeOverlay();
    }

    /** 检出示例请求的源分支；同名分支指向别的提交时保留原分支，并要求另取名字。 */
    private checkoutRequest(request: PullRequest, name: string): void {
        if (!name) {
            return;
        }

        const existing = this.state.branches.find((branch) => branch.name === name);

        if (existing && existing.hash !== request.head) {
            this.notify(this.text.t('pullRequests.error.branchMismatch'));
            return;
        }

        const upstream = this.state.remoteBranches.find(({ hash, name }) =>
            hash === request.head && name === `origin/${request.source}`)?.name ?? null;
        const branches = existing ? this.state.branches : [
            ...this.state.branches,
            { name, hash: request.head, upstream, ahead: 0, behind: 0 },
        ];

        this.closeOverlay();
        this.navigate({ ...this.state, branches, head: name, view: 'working' });
        this.frame.focus({ preventScroll: true });
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
                // 快捷操作搜索全部提交，选中的提交也在全部历史中打开
                this.navigate(selectCommit(selectView(this.state, data, 'history'), item.id));
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

        // 标题框里的回车转到正文；输入法选字时的回车留给输入法
        if (event.key === 'Enter' && target.dataset.input === 'subject') {
            // Safari 里确认选字的那次回车 isComposing 已是 false，只能靠 keyCode 229 认出
            if (!event.isComposing && event.keyCode !== 229) {
                event.preventDefault();
                this.frame.querySelector<HTMLElement>('[data-input="body"]')?.focus();
            }

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

        // 表单开着时，Tab 在输入框和按钮之间循环
        if (event.key === 'Tab') {
            const controls = this.frame.querySelectorAll<HTMLElement>(
                '.sd-demo-form :is(input, textarea, select, button):not(:disabled)',
            );
            const end = controls[event.shiftKey ? 0 : controls.length - 1];
            const start = controls[event.shiftKey ? controls.length - 1 : 0];

            if (target === end && start) {
                event.preventDefault();
                start.focus();
                return;
            }
        }

        if (target.dataset.input === 'query') {
            this.quickKey(event);
            return;
        }

        if (target.getAttribute('role') === 'option') {
            this.optionKey(event, target);
            return;
        }

        if (target.matches('.sd-menu-item')) {
            this.menuKey(event, target);
            return;
        }

        if (target.matches('.sd-side-list .sd-row')) {
            this.sidebarKey(event, target);
            return;
        }

        // 文件行有焦点时，方向键逐行选中文件，展开仍由独立的三角按钮控制
        if (target.matches('.sd-change-select') && (event.key === 'ArrowUp' || event.key === 'ArrowDown')) {
            const rows = [...(target.closest('.sd-change-list')?.querySelectorAll<HTMLButtonElement>('.sd-change-select') ?? [])];
            const next = rows[rows.indexOf(target as HTMLButtonElement) + (event.key === 'ArrowUp' ? -1 : 1)];

            if (next) {
                event.preventDefault();
                next.focus();
                next.click();
            }
        }
    }

    /** » 的菜单里的方向键：上下移动焦点，跳过不能用的项。 */
    private menuKey(event: KeyboardEvent, target: HTMLElement): void {
        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') {
            return;
        }

        const rows = [...this.frame.querySelectorAll<HTMLElement>('.sd-menu-item:not(:disabled)')];
        const next = rows[rows.indexOf(target) + (event.key === 'ArrowDown' ? 1 : -1)];

        event.preventDefault();
        next?.focus({ preventScroll: true });
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

        this.frame.addEventListener(
            'pointerdown',
            (event) => {
                pressed = event.button === 0;
            },
            true,
        );

        // 在窗口里按下之后可能拖到窗口外面才松开
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

    /**
     * 窗口宽度变了之后：工具栏上收起来的项跟着变，打开着的 » 菜单收起；
     * 回到常规版式时，极窄版式里打开的侧边栏算作收起，再收窄时不会自己盖上来；
     * 极窄版式里所在视图的一项留在视图导航的可见范围里。
     */
    private trackLayout(): void {
        new ResizeObserver(([entry]) => {
            if (!entry || entry.contentRect.width === 0) {
                return;
            }

            const regular = entry.contentRect.width >= narrowWidth;

            // 版式变回常规或重置仓库时，保留已经完成的这一步
            if (!regular && !this.sawNarrowLayout) {
                this.sawNarrowLayout = true;
                const step = this.options.root.querySelector('[data-narrow-step]');

                step?.classList.add('is-done');
                step?.querySelector('.sd-step-state')?.removeAttribute('hidden');
            }

            if (this.ui.overlay === 'more') {
                this.closeOverlay();
            }

            if (this.ui.sidebarOpen && regular) {
                this.update(this.state, { sidebarOpen: false });
            }

            this.revealCompactEntry();
        }).observe(this.options.root);
    }

    /** 极窄版式的视图导航里，把所在视图的一项滚进可见范围，只滚到它完整露出为止。 */
    private revealCompactEntry(): void {
        const list = this.frame.querySelector<HTMLElement>('.sd-compact-scroll');
        const entry = list?.querySelector<HTMLElement>('.is-selected');

        // 常规版式里导航不显示，没有可滚的
        if (!list || !entry || list.offsetParent === null) {
            return;
        }

        const start = entry.offsetLeft;
        const end = start + entry.offsetWidth;

        if (start < list.scrollLeft) {
            list.scrollLeft = start;
        } else if (end > list.scrollLeft + list.clientWidth) {
            list.scrollLeft = end - list.clientWidth;
        }
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

    /** 标题框里粘贴多行文字：第一行插到光标处，其余接到正文后面。 */
    private paste(event: ClipboardEvent): void {
        const field = event.target as HTMLInputElement;
        const pasted = event.clipboardData?.getData('text/plain') ?? '';

        // 只接管标题框里带换行的粘贴，单行文字照常粘贴
        if (field.dataset.input !== 'subject' || !newline.test(pasted)) {
            return;
        }

        event.preventDefault();

        // 第一行替换选中的文字、插到光标处，光标停在它后面；其余接到正文后面
        const parts = multilineParts(pasted, this.state.body);

        field.setRangeText(
            parts.subject,
            field.selectionStart ?? 0,
            field.selectionEnd ?? 0,
            'end',
        );
        this.update({ ...this.state, subject: field.value, body: parts.body });
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

    /** 点步骤：焦点移到窗口里对应的第一个控件；它收进了工具栏的 » 时移到 » 上。 */
    private focusStep(step: string): void {
        const find = (guide: string) =>
            [...this.frame.querySelectorAll<HTMLElement>(`[data-guide="${guide}"]`)].find(
                (control) => !control.matches(':disabled') && control.offsetParent !== null,
            );

        (find(step) ?? find(`${step}-overflow`))?.focus();
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
        this.update(createState(this.options.data), createUi(this.options.data));

        // 留在页面上没被替换的列表同样回到顶上
        for (const element of this.frame.querySelectorAll<HTMLElement>('[data-scroll]')) {
            element.scrollTop = 0;
        }
    }
}

// MARK: - Helpers

/** 导航位置；只有历史视图需要记录引用范围。 */
function placeOf(state: DemoState): Place {
    return { view: state.view, historyRef: state.view === 'history' ? state.historyRef : null };
}

/** 有就去掉，没有就加上。 */
function toggled<T>(values: readonly T[], value: T): T[] {
    return values.includes(value) ? values.filter((item) => item !== value) : [...values, value];
}
