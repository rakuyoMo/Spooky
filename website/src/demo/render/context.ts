import type { ChangeData, DemoState, RepoData } from '../model.ts';
import type { DemoText } from '../text.ts';

/**
 * 渲染用到的全部输入：数据、文案、界面上的临时状态，以及按需取来的变更集。
 */

/** 只属于界面的临时状态：浮层、快捷操作的输入、获取中的转圈与提示。 */
export interface UiState {
    /** 打开着的浮层：推送对话框或快捷操作。 */
    overlay: 'push' | 'quick' | null;

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
}

/** 初始的界面状态。 */
export function createUi(): UiState {
    return {
        overlay: null,
        query: '',
        quickIndex: 0,
        fetching: false,
        collapsed: [],
        stashSelected: false,
        metadataCollapsed: false,
        pinned: false,
        closedGroups: [],
        back: [],
        forward: [],
    };
}
