// MARK: - RevisionPreview

/// 输入停顿后按版本读出的预览，与读取时的输入记在一起。
///
/// 输入变了之后、新结果出来之前，仍显示上一次的结果与错误，新结果出来后一次替换；
/// 只有与当前输入对应的结果算读完：主按钮据此可用，提交也只用它，晚到的旧结果不会被当成当前输入的结果。
struct RevisionPreview<Input: Equatable, Value> {
    /// 正在显示的结果；还没有读到或读取失败时为 nil。
    private(set) var value: Value? = nil

    /// 正在显示的错误；没有错误时为空。
    private(set) var error = ""

    /// 正在显示的结果与错误对应的输入；还没有读完任何输入时为 nil。
    private var input: Input? = nil

    /// 与这个输入对应的结果；正在显示的结果属于别的输入或没有结果时为 nil。
    ///
    /// - Parameter input: 当前的输入。
    func value(for input: Input) -> Value? {
        self.input == input ? value : nil
    }

    /// 某个输入读完：结果与错误一次替换。
    ///
    /// - Parameters:
    ///   - value: 读到的结果；读取失败或输入不完整时为 nil。
    ///   - error: 错误区的说明；没有错误时为空。
    ///   - input: 读取时的输入。
    mutating func show(_ value: Value?, error: String = "", for input: Input) {
        self.value = value
        self.error = error
        self.input = input
    }
}
