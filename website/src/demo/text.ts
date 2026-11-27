/**
 * 演示窗口的界面文字：全部取自 App 的 `Localizable.strings`，构建时只把这里列出的键按页面的语言交给浏览器。
 */

/** 演示窗口用到的全部资源键；带 `.one` 的是数量为 1 时 App 换用的写法。 */
export const demoKeys = [
    // 工具栏
    'toolbar.bookmarks',
    'navigation.back',
    'navigation.forward',
    'toolbar.previous',
    'toolbar.next',
    'toolbar.finder',
    'toolbar.terminal',
    'sync.fetch',
    'sync.pull',
    'sync.push',
    'toolbar.forcePush',
    'toolbar.applyStash',
    'toolbar.saveStash',
    'toolbar.createBranch',
    'action.refresh',
    'action.search',
    'history.search.forFile',
    'history.search.forMessage',
    'stash.search',

    // 侧边栏
    'workspace.group',
    'workspace.title',
    'history.title',
    'stash.title',
    'pr.title',
    'review.title',
    'repositorySettings.title',
    'branch.group',
    'sidebar.archived',
    'sidebar.tags',
    'remote.group',
    'workspace.changed',
    'stash.count',
    'branch.ahead',
    'branch.default',
    'activity.title',
    'reference.addMenu',
    'sidebar.viewSettings',
    'sidebar.menu',

    // 工作区
    'connection.connected',
    'working.viewMode',
    'working.subtitle',
    'working.subtitle.branch',
    'working.subject',
    'working.body',
    'commit.quickAmendHint',
    'commit.remaining',
    'commit.pin',
    'editor.wrapping',
    'working.amend',
    'commit.signOff',
    'working.stageAll',
    'working.unstageAll',
    'working.commit',
    'working.staging',
    'status.column',
    'status.filename',
    'status.description',
    'status.modified',
    'status.added',
    'status.copied',
    'status.deleted',
    'status.renamed',
    'status.typeChanged',
    'status.conflicted',
    'status.untracked',
    'status.unchanged',
    'working.staged',
    'working.unstaged',
    'working.diffSide',
    'working.stageChunk',
    'working.unstageChunk',
    'working.discardChunk',
    'working.stageLine',
    'working.stageLines',
    'working.unstageLine',
    'working.unstageLines',
    'working.discardLine',
    'working.discardLines',
    'working.selectLine',
    'working.diffSummary',
    'diff.summary.chunks',
    'diff.summary.chunks.one',
    'diff.summary.insertions',
    'diff.summary.insertions.one',
    'diff.summary.deletions',
    'diff.summary.deletions.one',
    'diff.context',
    'diff.ignoreWhitespace',
    'diff.showEntireFile',
    'diff.contextLines',
    'detail.empty.title',
    'diff.summary.binary',

    // 历史与储藏
    'history.subtitle',
    'history.all',
    'history.viewOptions',
    'history.author',
    'history.authorDate',
    'history.committer',
    'history.commitDate',
    'history.refs',
    'history.hash',
    'history.parentHash',
    'history.treeHash',
    'history.changeset',
    'history.tree',
    'history.collapseAll',
    'history.expandAll',
    'history.summary',
    'history.summary.files',
    'history.summary.files.one',
    'history.summary.additions',
    'history.summary.additions.one',
    'history.summary.deletions',
    'history.summary.deletions.one',
    'history.noSelection',
    'history.unpushed',
    'history.detailMode',
    'history.metadata',
    'history.loadingChanges',
    'history.rollback',
    'rewrite.revert.button',
    'history.diffTool',
    'stash.applyButton',
    'stash.deleteButton',
    'stash.noSelection',
    'stash.subtitle',
    'stash.subtitle.one',
    'stash.basedOn',

    // Pull Request
    'pr.create.menu',
    'pr.create.title',
    'pr.create.message',
    'pr.create.submit',
    'pr.edit.title',
    'pr.edit.message',
    'pr.comment.title',
    'pr.comment.message',
    'pr.checkout.title',
    'pr.close.title',
    'pr.close.message',
    'pr.close.submit',
    'pr.accept.title',
    'pr.accept.message',
    'pr.accept.submit',
    'pr.empty.title',
    'pr.noSelection',
    'pr.stateFilter',
    'pr.description.title',
    'pullRequests.addComment',
    'pullRequests.addLabel.title',
    'pullRequests.branchName',
    'pullRequests.changeset',
    'pullRequests.checkout',
    'pullRequests.checkout.message',
    'pullRequests.checks',
    'pullRequests.checks.state.success',
    'pullRequests.checks.status',
    'pullRequests.close',
    'pullRequests.comment',
    'pullRequests.comment.commented',
    'pullRequests.commits',
    'pullRequests.contributors',
    'pullRequests.contributors.one',
    'pullRequests.contributors.commits',
    'pullRequests.conversation',
    'pullRequests.description',
    'pullRequests.edit',
    'pullRequests.error.branchMismatch',
    'pullRequests.filter.all',
    'pullRequests.filter.open',
    'pullRequests.header.info',
    'pullRequests.header.commits',
    'pullRequests.header.commits.one',
    'pullRequests.header.labels',
    'pullRequests.labels.add',
    'pullRequests.merge',
    'pullRequests.noDescription',
    'pullRequests.removeLabel.title',
    'pullRequests.save',
    'pullRequests.source',
    'pullRequests.state.closed',
    'pullRequests.state.merged',
    'pullRequests.state.open',
    'pullRequests.target',
    'pullRequests.titleField',

    // 仓库设置
    'repositorySettings.general',
    'repositorySettings.lfs',
    'repositorySettings.ignores',
    'repositorySettings.excludes',
    'repositorySettings.lfs.patterns',
    'repositorySettings.name',
    'repositorySettings.path',
    'repositorySettings.localLocation',
    'repositorySettings.signing',
    'repositorySettings.signCommits',
    'bookmarks.detail.identity',
    'bookmarks.detail.unset',
    'localLocation.value',
    'localLocation.notMounted',
    'localLocation.change',
    'localLocation.title',
    'localLocation.message',
    'localLocation.method',
    'localLocation.method.automatic',
    'localLocation.method.smbMount',
    'localLocation.method.sshfsMount',
    'localLocation.method.chosenFolder',
    'localLocation.mountAt',
    'localLocation.folder',
    'localLocation.mount',
    'localLocation.save',

    // 推送
    'sync.pushHead',
    'sync.pushHead.help',
    'sync.destination',
    'dialog.options',
    'action.cancel',
    'help.help',

    // 快捷操作
    'quickActions.placeholder',
    'quickActions.noResults',
    'quickActions.objectHint',
    'quickActions.detail',
    'quickActions.type.navigation',
    'quickActions.type.branch',
    'quickActions.type.remoteBranch',
    'quickActions.type.tag',
    'quickActions.type.stash',
    'quickActions.type.file',
    'quickActions.type.commit',
    'quickActions.showBranchHistory',
    'quickActions.showRemoteBranchHistory',
    'quickActions.showTagHistory',
    'quickActions.revealInHistory',
    'quickActions.showInApp',
    'quickActions.showFile',
] as const;

/** 演示窗口的资源键。 */
export type DemoKey = (typeof demoKeys)[number];

/** 一种语言里演示窗口用到的文案。 */
export type DemoStrings = Record<DemoKey, string>;

/** 演示窗口取文字的接口。 */
export interface DemoText {
    /** BCP-47 语言标签，日期与数字按它格式化。 */
    lang: string;

    /** 取一个键的文案并代入参数。 */
    t(key: DemoKey, ...args: (string | number)[]): string;

    /** 带数量的文案：数量为 1 且有 `.one` 写法时用它。 */
    count(key: DemoKey, count: number): string;
}

/**
 * 从 App 的文案表里取出一种语言的演示文案，构建时调用。
 *
 * `tables` 以站点的语言代号为键；任何一种语言缺了演示用到的键都抛出错误，构建随之失败。
 */
export function demoStrings(tables: Record<string, Record<string, string>>, code: string): DemoStrings {
    for (const [language, table] of Object.entries(tables)) {
        const missing = demoKeys.filter((key) => !(key in table));

        if (missing.length > 0) {
            throw new Error(`演示窗口的资源键在 ${language} 的文案里不存在：${missing.join('、')}`);
        }
    }

    const table = tables[code];

    if (!table) {
        throw new Error(`没有 ${code} 的文案`);
    }

    return Object.fromEntries(demoKeys.map((key) => [key, table[key] ?? ''])) as DemoStrings;
}

/** 按一种语言的文案建出取文字的接口。 */
export function createText(strings: DemoStrings, lang: string): DemoText {
    const t = (key: DemoKey, ...args: (string | number)[]) => format(strings[key], args);

    return {
        lang,
        t,
        count(key, count) {
            const single = `${key}.one`;

            return count === 1 && single in strings ? t(single as DemoKey, count) : t(key, count);
        },
    };
}

/**
 * 按格式说明符代入参数：`%@`、`%d`、`%ld` 按出现顺序取参数，`%1$@` 这类按序号取，`%%` 是百分号本身。
 */
export function format(template: string, args: readonly (string | number)[]): string {
    const specifier = /%(?:(\d+)\$)?(?:l|ll|q)?([@dDiuU%])/g;
    let next = 0;

    return template.replace(specifier, (_match, position: string | undefined, type: string) => {
        if (type === '%') {
            return '%';
        }

        const index = position === undefined ? next++ : Number(position) - 1;

        return String(args[index] ?? '');
    });
}
