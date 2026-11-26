import type { ChangeData, CommitData, RepoData } from './model.ts';
import { reachableFrom } from './model.ts';

/** 演示里可打开的请求详情分段。 */
export const requestPages = ['conversation', 'commits', 'changeset', 'checks'] as const;

/** 示例项目里的标签与颜色。 */
export const requestLabels = { enhancement: '#2871b2', ui: '#793ab2', 'needs review': '#875b15' };

/** 示例项目里可为请求选择的标签名。 */
export type RequestLabel = keyof typeof requestLabels;

/** 一条示例评论或访客在演示里写的评论。 */
export interface RequestComment {
    author: string;
    date: number;
    body: string;
}

/** 请求保留源与目标的提交快照；演示里的托管操作更新这份记录。 */
export interface PullRequest {
    id: number;
    title: string;
    description: string;
    author: string;
    date: number;
    source: string;
    head: string;
    base: string;
    status: 'open' | 'closed' | 'merged';
    labels: RequestLabel[];
    comments: RequestComment[];
}

/** 三个示例请求与 driftwood 仓库的分支和提交对应。 */
export function sampleRequests(data: RepoData): PullRequest[] {
    const units = sampleSource(data, 'feature/units-toggle');
    const theme = sampleSource(data, 'feature/dark-mode');
    const forecast = data.commits.find((commit) => commit.message.startsWith("Merge branch 'feature/forecast-panel'"));

    if (!units || !theme || !forecast?.parents[0] || !forecast.parents[1]) {
        throw new Error('示例仓库缺少 Pull Request 的提交');
    }

    return [
        {
            id: 12,
            title: 'Add a units toggle',
            description: 'Let readers switch between metric and imperial units from the dashboard.',
            author: units.author[0],
            date: units.author[2],
            source: 'feature/units-toggle',
            head: units.hash,
            base: units.parents[0] ?? '',
            status: 'open',
            labels: ['enhancement', 'ui'],
            comments: [{
                author: 'Mina Park',
                date: units.author[2] + 4200,
                body: 'The station drawer now follows the dashboard units. Looks good to me!',
            }],
        },
        {
            id: 11,
            title: 'Add a dark mode toggle',
            description: 'Add a theme toggle to the header and remember the selected theme.',
            author: theme.author[0],
            date: theme.author[2],
            source: 'feature/dark-mode',
            head: theme.hash,
            base: data.remoteBranches.find((ref) => ref.name === data.remoteHead)?.hash ?? '',
            status: 'closed',
            labels: ['ui'],
            comments: [],
        },
        {
            id: 8,
            title: 'Show a forecast panel',
            description: 'Show the hourly forecast together with the latest station readings.',
            author: forecast.author[0],
            date: forecast.author[2],
            source: 'feature/forecast-panel',
            head: forecast.parents[1],
            base: forecast.parents[0],
            status: 'merged',
            labels: ['enhancement'],
            comments: [],
        },
    ];
}

/** 只允许从示例远端已发布、没有打开请求的功能分支创建请求。 */
export function availableSources(data: RepoData, requests: readonly PullRequest[]): string[] {
    return data.remoteBranches
        .filter((ref) => ref.name.startsWith('origin/feature/'))
        .map((ref) => ref.name.slice('origin/'.length))
        .filter((name) => !requests.some((request) => request.status === 'open' && request.source === name));
}

/** 创建新请求时固定目标为示例远端的默认分支，源与目标保存当时的提交。 */
export function createRequest(
    data: RepoData,
    requests: readonly PullRequest[],
    source: string,
    title: string,
    description: string,
    date: number,
): PullRequest | null {
    const head = sampleSource(data, source);
    const base = data.remoteBranches.find((ref) => ref.name === data.remoteHead);

    if (!head || !base || !title.trim() || !availableSources(data, requests).includes(source)) {
        return null;
    }

    return {
        id: Math.max(0, ...requests.map((request) => request.id)) + 1,
        title: title.trim(),
        description: description.trim(),
        author: data.identity.name,
        date,
        source,
        head: head.hash,
        base: base.hash,
        status: 'open',
        labels: [],
        comments: [],
    };
}

/** 按当前筛选显示请求，保持请求列表的顺序。 */
export function visibleRequests(requests: readonly PullRequest[], all: boolean): PullRequest[] {
    return requests.filter((request) => all || request.status === 'open');
}

/** 源分支可达、目标分支不可达的提交，最新的在前。 */
export function requestCommits(data: RepoData, request: PullRequest): CommitData[] {
    const source = reachableFrom(data.commits, request.head);
    const target = reachableFrom(data.commits, request.base);

    return data.commits.filter((commit) => source.has(commit.hash) && !target.has(commit.hash));
}

/** 请求的净变更：多次修改同一个文件的示例分支使用预先导出的范围补丁。 */
export function requestChanges(
    data: RepoData,
    request: PullRequest,
    changes: Record<string, ChangeData[]>,
): ChangeData[] {
    return changes[request.head + ':' + request.base] ??
        requestCommits(data, request).flatMap((commit) => changes[commit.hash] ?? []);
}

/** 从示例远端找分支对应的提交。 */
function sampleSource(data: RepoData, name: string): CommitData | undefined {
    const hash = data.remoteBranches.find((ref) => ref.name === `origin/${name}`)?.hash;

    return data.commits.find((commit) => commit.hash === hash);
}
