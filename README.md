为嵌套括号提供按深度着色的现代 Neovim 插件，基于 Lua 和 Neovim 原生 API，专注简洁、高性能与良好的生态兼容性。

## 特性

- 使用 Lua 与 `extmark`，避免粗暴覆盖原有语法定义，兼容 Treesitter 与 LSP 高亮。[web:2][web:7]  
- 自动根据当前配色方案生成一组可区分的括号颜色，也支持完全自定义。  
- 针对不同文件类型单独配置最大嵌套深度、配色策略、括号类型等。  
- 对大文件启用窗口范围扫描与防抖机制，尽量减少性能开销。  
- 提供命令：`ChromaticaBracketsToggle` 与 `ChromaticaBracketsRefresh`。

## 安装

使用 lazy.nvim 为例：

{
"your-name/chromatica-brackets.nvim",
config = function()
require("chromatica_brackets").setup()
end,
}

text

使用 packer.nvim：

use {
"your-name/chromatica-brackets.nvim",
config = function()
require("chromatica_brackets").setup()
end,
}

text

## 快速开始

安装后无需额外配置，默认会在支持的文件类型中自动启用：

- 扫描 `()[]{}<>` 等括号  
- 按嵌套深度循环使用一组自动生成的颜色  
- 在插入和编辑过程中自动更新着色结果

常用命令：

- `:ChromaticaBracketsToggle` 开关当前 buffer 的括号着色  
- `:ChromaticaBracketsRefresh` 强制重新扫描并刷新高亮

## 配置示例

require("chromatica_brackets").setup({
enabled = true,
throttle = 60,
max_lines = 8000,
undercurl = false,
bold = false,

filetypes = {
["*"] = {
max_depth = 10,
strategy = "cycle", -- "cycle" 或 "gradient"
match_pairs = { "()", "[]", "{}" },
include_angle = true,
include_operators = false,
},
lua = {
strategy = "gradient",
max_depth = 16,
},
javascript = {
include_operators = true,
},
},
})

text

可随时在运行时使用 `:ChromaticaBracketsToggle` 快速关闭或开启当前 buffer 的效果。

## 设计思路

与老一代括号着色插件相比，本项目强调以下几点改进：[web:2][web:7]

- 使用 Neovim 的命名空间与 `extmark` 来渲染颜色，不再直接覆写原语法高亮组，以减小对其他插件的干扰。  
- 使用简单的栈算法对括号进行匹配，逻辑清晰、易于维护，并经过防抖处理避免在频繁编辑时阻塞 UI。  
- 通过文件类型粒度的配置，允许针对 Lisp 类语言、脚本语言等深度括号场景进行更细致的调优。

## 许可与致谢

本项目从众多历史上的括号着色插件中获得灵感，特别是早期的 Rainbow 类插件及其改进工作，感谢这些先行者在可读性方面的探索。[web:2][web:5][web:7]

你可以自由地修改和分发本插件代码，但在引用时请尊重相关项目的版权与许可证说明。
