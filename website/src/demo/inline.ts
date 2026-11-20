/**
 * 块内修改行的单词级比较：删除行与新增行成对比较，找出两行中改动的部分，Diff 给它们铺上高亮底色。
 *
 * 一行先切成单词、连续空白与其它单个字符，再按最长公共子序列比较两行的切分结果。
 */

/** 一行里改动的范围：起止偏移按 UTF-16 计，止点不含。 */
export type Range = [number, number];

/** 参与比较的一行最多的字符数，任一行超过时这一对不比较。 */
const maximumLength = 1000;

/** 一行中改动的字符超过这个比例时，这一对不高亮：几乎整行重写时，高亮只会盖满整行。 */
const maximumChangedRatio = 0.75;

/**
 * 一个块里各修改行需要高亮的范围。
 *
 * 被上下文行隔开的每段连续改动是一组：组内删除行与新增行数目相同时按顺序一一配对比较，数目不同的组不高亮。
 * 返回值的键是行在 `rows` 里的序号。
 */
export function inlineRanges(rows: readonly { kind: 'c' | 'd' | 'a'; text: string }[]): Map<number, Range[]> {
    const result = new Map<number, Range[]>();
    let start = 0;

    while (start < rows.length) {
        if (rows[start]?.kind === 'c') {
            start += 1;
            continue;
        }

        let end = start;

        while (end < rows.length && rows[end]?.kind !== 'c') {
            end += 1;
        }

        const indices = Array.from({ length: end - start }, (_, offset) => start + offset);
        const deleted = indices.filter((index) => rows[index]?.kind === 'd');
        const added = indices.filter((index) => rows[index]?.kind === 'a');

        if (deleted.length === added.length) {
            deleted.forEach((index, pair) => {
                const other = added[pair] ?? -1;
                const ranges = compare(rows[index]?.text ?? '', rows[other]?.text ?? '');

                if (ranges) {
                    result.set(index, ranges.deleted);
                    result.set(other, ranges.added);
                }
            });
        }

        start = end;
    }

    return result;
}

// MARK: - Private

/** 比较一对删除行与新增行；任一行太长或改动太多时没有结果。 */
function compare(deleted: string, added: string): { deleted: Range[]; added: Range[] } | null {
    if (deleted.length > maximumLength || added.length > maximumLength) {
        return null;
    }

    const old = tokens(deleted);
    const next = tokens(added);

    // 最长公共子序列的长度表，倒着填，便于从头回溯
    const table = Array.from({ length: old.length + 1 }, () => new Array<number>(next.length + 1).fill(0));

    for (let i = old.length - 1; i >= 0; i -= 1) {
        for (let j = next.length - 1; j >= 0; j -= 1) {
            const row = table[i] ?? [];

            row[j] =
                old[i] === next[j]
                    ? (table[i + 1]?.[j + 1] ?? 0) + 1
                    : Math.max(table[i + 1]?.[j] ?? 0, row[j + 1] ?? 0);
        }
    }

    // 回溯出两行各自不在公共子序列里的段
    const removed: number[] = [];
    const inserted: number[] = [];
    let i = 0;
    let j = 0;

    while (i < old.length || j < next.length) {
        if (i < old.length && j < next.length && old[i] === next[j]) {
            i += 1;
            j += 1;
        } else if (
            j >= next.length ||
            (i < old.length && (table[i + 1]?.[j] ?? 0) >= (table[i]?.[j + 1] ?? 0))
        ) {
            removed.push(i);
            i += 1;
        } else {
            inserted.push(j);
            j += 1;
        }
    }

    if (
        ratio(removed, old, deleted) > maximumChangedRatio ||
        ratio(inserted, next, added) > maximumChangedRatio
    ) {
        return null;
    }

    return { deleted: merged(removed, old), added: merged(inserted, next) };
}

/** 把一行切成单词、连续空白与其它单个字符。 */
function tokens(line: string): string[] {
    return line.match(/[\p{L}\p{N}\p{M}\p{Pc}\u200D]+|\s+|./gsu) ?? [];
}

/** 改动的段占整行字符的比例；空行按 0 计。 */
function ratio(indices: readonly number[], parts: readonly string[], line: string): number {
    const length = [...line].length;

    if (length === 0) {
        return 0;
    }

    return indices.reduce((sum, index) => sum + [...(parts[index] ?? '')].length, 0) / length;
}

/** 把相邻的改动段合并成范围。 */
function merged(indices: readonly number[], parts: readonly string[]): Range[] {
    const offsets: number[] = [];
    let offset = 0;

    for (const part of parts) {
        offsets.push(offset);
        offset += part.length;
    }

    const ranges: Range[] = [];

    for (const index of indices) {
        const from = offsets[index] ?? 0;
        const to = from + (parts[index]?.length ?? 0);
        const last = ranges.at(-1);

        if (last && last[1] === from) {
            last[1] = to;
        } else {
            ranges.push([from, to]);
        }
    }

    return ranges;
}
