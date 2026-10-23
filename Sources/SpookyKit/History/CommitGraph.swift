// MARK: - CommitGraphRow

/// 一行提交图的几何模型，与 Git 颜色和界面框架无关。
public struct CommitGraphRow: Sendable, Equatable {
    /// 提交圆点所在列。
    public let column: Int

    /// 本行的所有线段。
    public let segments: [CommitGraphSegment]

    /// 包括圆点和跨行端点的总列数。
    public var columnCount: Int {
        1 + segments.reduce(column) { max($0, $1.start, $1.end) }
    }
}

// MARK: - CommitGraphSegment

/// 相邻行依靠列索引连接，首尾线段在当前提交圆点处起止。
public struct CommitGraphSegment: Sendable, Equatable {
    /// 同一父链持续使用的颜色标识，从 1 开始。
    public let line: Int

    /// 上沿列；起始段为圆点列。
    public let start: Int

    /// 下沿列；终止段为圆点列。
    public let end: Int

    /// 是否从当前提交圆点出发。
    public let startsAtCommit: Bool

    /// 是否在当前提交圆点终止。
    public let endsAtCommit: Bool
}

// MARK: - CommitGraph

/// 按拓扑序增量分配父链，分页时保留活动线即可连续绘制。
public struct CommitGraph: Sendable {
    /// 等待父提交到来的线段。
    private struct Lane: Sendable {
        /// 生命周期内保持不变的颜色标识。
        let id: Int

        /// 下一次汇合的提交。
        var target: String
    }

    /// 顺序就是当前列位置。
    private var lanes: [Lane] = []

    /// 每条新线取得新的身份，避免合并后颜色跳变。
    private var nextID = 1

    /// 新的历史快照从空图开始。
    public init() { }

    /// 第一父延续主线，其余父分叉；重复等待同一提交的线在该行汇合。
    public mutating func append(_ commit: HistoryCommit) -> CommitGraphRow {
        let before = lanes
        let matching = before.filter { $0.target == commit.id }
        let primary = matching.first
        let column = before.firstIndex { $0.target == commit.id } ?? before.count

        // 已有主线保留身份，汇合进来的其它线从活动表移除。
        lanes.removeAll { $0.target == commit.id && $0.id != primary?.id }
        var starting: [Int] = []

        if commit.parents.isEmpty {
            lanes.removeAll { $0.id == primary?.id }
        } else {
            for (index, parent) in commit.parents.enumerated() {
                if index == 0, let primary, let position = lanes.firstIndex(where: { $0.id == primary.id }) {
                    lanes[position].target = parent
                } else if primary != nil, let existing = lanes.first(where: { $0.target == parent }) {
                    starting.append(existing.id)
                } else {
                    lanes.append(Lane(id: nextID, target: parent))
                    starting.append(nextID)
                    nextID += 1
                }
            }
        }

        // 快照记录上沿，更新后的表记录下沿，移除列后右侧线自然左移。
        let positions = Dictionary(
            uniqueKeysWithValues: lanes.enumerated().map { ($0.element.id, $0.offset) }
        )
        var segments = before.enumerated()
            .map { index, lane in
                CommitGraphSegment(
                    line: lane.id,
                    start: index,
                    end: positions[lane.id] ?? column,
                    startsAtCommit: false,
                    endsAtCommit: positions[lane.id] == nil
                )
            }
        segments += starting.compactMap { id in
            positions[id]
                .map {
                    CommitGraphSegment(
                        line: id,
                        start: column,
                        end: $0,
                        startsAtCommit: true,
                        endsAtCommit: false
                    )
                }
        }
        return CommitGraphRow(column: column, segments: segments)
    }
}
