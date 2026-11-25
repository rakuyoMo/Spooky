import type { ChangeData, DemoState, RepoData } from '../model.ts';
import type { DemoText } from '../text.ts';

/**
 * 渲染用到的全部输入：数据、文案、界面上的临时状态，以及按需取来的变更集。
 */

/** 只属于界面的临时状态：浮层、快捷操作的输入、获取中的转圈与提示，以及极窄版式里的侧边栏。 */
export interface UiState {
    /** 打开着的浮层：推送对话框、快捷操作或工具栏 » 的菜单。 */
    overlay: 'push' | 'quick' | 'more' | null;

    /** 打开 » 的菜单时，工具栏上收起来的项。 */
    overflow: string[];

    /** 快捷操作框里的文字与选中的结果。 */
    query: string;
    quickIndex: number;

    /** 获取按钮正在转圈。 */
    fetching: boolean;

    /** 提交详情里折叠起来的文件，键是 `提交:路径`。 */
    collapsed: string[];

    /** 储藏视图里选中了那份储藏。 */
    stashSelected: boolean;

    /** 详情的元信息只显示作者、日期与引用。 */
    metadataCollapsed: boolean;

    /** 提交区固定展开。 */
    pinned: boolean;

    /** 侧边栏里收起来的文件夹与远端。 */
    closedGroups: string[];

    /** 极窄版式里侧边栏盖在主视图上。 */
    sidebarOpen: boolean;

    /** 后退与前进能回到的位置。 */
    back: Place[];
    forward: Place[];
}

/** 后退、前进记下的位置：视图与历史只看的引用。 */
export interface Place {
    view: DemoState['view'];
    historyRef: string | null;
}

/** 一次渲染的上下文。 */
export interface RenderContext {
    state: DemoState;
    ui: UiState;
    data: RepoData;
    text: DemoText;

    /** 全部提交的变更集；还没取来时是 `null`。 */
    changes: Record<string, ChangeData[]> | null;

    /** 推送对话框里的应用图标地址。 */
    appIcon: string;

    /** 工具栏 » 的名字：它是系统画的控件，App 的文案里没有，由网站给出。 */
    overflowLabel: string;
}

/** 初始的界面状态。 */
export function createUi(): UiState {
    return {
        overlay: null,
        overflow: [],
        query: '',
        quickIndex: 0,
        fetching: false,
        collapsed: [],
        stashSelected: false,
        metadataCollapsed: false,
        pinned: false,
        closedGroups: [],
        sidebarOpen: false,
        back: [],
        forward: [],
    };
}
