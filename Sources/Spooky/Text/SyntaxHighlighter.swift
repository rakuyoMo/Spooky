import Foundation

// MARK: - SyntaxStyle

/// 语法片段的类别，原始值即主题里的颜色键。
enum SyntaxStyle: String, Sendable {
    /// 关键字与字面量。
    case keyword

    /// 类型等其它标识符。
    case identifier

    /// 函数名与调用。
    case function

    /// 数字。
    case number

    /// 字符串。
    case string

    /// 注释。
    case comment

    /// 预处理指令与注解。
    case preprocessor

    /// 标记语言的标签名。
    case xmlTag

    /// 标记语言的属性名、配置文件的键。
    case attributeName

    /// 标记语言的属性值。
    case attributeValue

    /// 样式表的选择器。
    case cssSelector

    /// 文档标题。
    case heading

    /// 斜体强调。
    case emphasized

    /// 粗体强调。
    case stronglyEmphasized

    /// 行内代码与代码块。
    case codeBlock

    /// 链接地址。
    case url
}

// MARK: - SyntaxSpan

/// 一行中连续的一段同类文字，长度按 UTF-16 计，没有类别的片段按正文显示。
struct SyntaxSpan: Sendable, Equatable {
    /// 片段长度。
    let length: Int

    /// 片段类别。
    let style: SyntaxStyle?
}
