local M = {}

M.defaults = {
  -- 全局开关
  enabled = true,

  -- 支持的文件类型，* 表示默认规则
  filetypes = {
    ["*"] = {
      max_depth = 12,
      strategy = "cycle", -- "cycle" | "gradient"
      colors = nil,       -- { "#rrggbb", ... }，nil 时自动根据主题生成
      include_angle = true, -- 是否包括 < >
      include_operators = false, -- 是否给操作符附加同色
      match_pairs = { "()", "[]", "{}" },
    },
    lua = {
      max_depth = 16,
      strategy = "gradient",
    },
    vim = {
      include_operators = true,
    },
  },

  -- 性能相关
  throttle = 80,    -- 毫秒，光标移动／文本变更后的延时
  max_lines = 5000, -- 超过该行数则只对可见窗口区域做标记

  -- UI 相关
  undercurl = false,
  bold = false,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", M.options, opts)
end

function M.get_ft_config(ft)
  local base = M.options.filetypes["*"] or {}
  local ft_conf = M.options.filetypes[ft] or {}
  return vim.tbl_deep_extend("force", base, ft_conf)
end

return M
