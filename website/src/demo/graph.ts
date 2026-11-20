/**
 * 提交图的泳道：按列表顺序逐个提交排出所在的列与穿过这一行的线段。
 */

/** 穿过一行的一段线：从上沿的 `start` 列到下沿的 `end` 列，`line` 决定颜色。 */
export interface GraphSegment {
    line: number;
    start: number;
    end: number;
    startsAtCommit: boolean;
    endsAtCommit: boolean;
}

/** 一行的图：提交所在的列与全部线段。 */
export interface GraphRow {
    column: number;
    segments: GraphSegment[];
}

/** 一条泳道：等待的父提交与线的编号。 */
interface Lane {
    id: number;
    target: string;
}

/**
 * 逐行排出提交图。
 *
 * 提交落在第一条等它的泳道上，没有就新开一列；第一个父提交接着走这条泳道，其余父提交并到已有的泳道或另开一条。
 */
export function graphRows(commits: readonly { hash: string; parents: readonly string[] }[]): GraphRow[] {
    let lanes: Lane[] = [];
    let nextId = 1;

    return commits.map(({ hash, parents }) => {
        const before = lanes;
        const primary = before.find((lane) => lane.target === hash);
        const found = before.findIndex((lane) => lane.target === hash);
        const column = found < 0 ? before.length : found;

        // 同时等这个提交的其余泳道在这里汇合
        lanes = lanes.filter((lane) => !(lane.target === hash && lane.id !== primary?.id));

        const starting: number[] = [];

        if (parents.length === 0) {
            lanes = lanes.filter((lane) => lane.id !== primary?.id);
        }

        parents.forEach((parent, index) => {
            const position = primary ? lanes.findIndex((lane) => lane.id === primary.id) : -1;

            if (index === 0 && position >= 0) {
                lanes = lanes.map((lane, offset) =>
                    offset === position ? { ...lane, target: parent } : lane,
                );
                return;
            }

            const existing = primary ? lanes.find((lane) => lane.target === parent) : undefined;

            if (existing) {
                starting.push(existing.id);
                return;
            }

            lanes = [...lanes, { id: nextId, target: parent }];
            starting.push(nextId);
            nextId += 1;
        });

        const positions = new Map(lanes.map((lane, offset) => [lane.id, offset]));

        const segments: GraphSegment[] = before.map((lane, index) => ({
            line: lane.id,
            start: index,
            end: positions.get(lane.id) ?? column,
            startsAtCommit: false,
            endsAtCommit: !positions.has(lane.id),
        }));

        for (const id of starting) {
            const end = positions.get(id);

            if (end !== undefined) {
                segments.push({ line: id, start: column, end, startsAtCommit: true, endsAtCommit: false });
            }
        }

        return { column, segments };
    });
}

/** 一行图占的列数。 */
export function columnCount(row: GraphRow): number {
    return 1 + Math.max(row.column, ...row.segments.flatMap((segment) => [segment.start, segment.end]));
}
