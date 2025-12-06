local config = require("chromatica_brackets.config")

local M = {}

-- 为每个 buffer 维护独立状态
local state = {}

-- 简单的括号对映射
local function build_pair_table(conf)
  local pairs = {}
  for _, p in ipairs(conf.match_pairs) do
    local left = p:sub(1, 1)
    local right = p:sub(2, 2)
    pairs[left] = right
    pairs[right] = left
  end
  if conf.include_angle then
    pairs["<"] = ">"
    pairs[">"] = "<"
  end
  return pairs
end

-- 自动生成颜色表：根据当前 colorscheme 推出一组可区分颜色
local function generate_palette(depth, strategy)
  local palette = {}
  -- 非严格依赖 colorscheme 的简单策略：HSV 环均匀取点
  for i = 1, depth do
    local h = (360 / depth) * (i - 1)
    local s = 70
    local v = 80
    local function hsv_to_rgb(hh, ss, vv)
      local c = vv * ss / 100
      local x = c * (1 - math.abs((hh / 60) % 2 - 1))
      local m = vv - c
      local r, g, b
      if hh < 60 then
        r, g, b = c, x, 0
      elseif hh < 120 then
        r, g, b = x, c, 0
      elseif hh < 180 then
        r, g, b = 0, c, x
      elseif hh < 240 then
        r, g, b = 0, x, c
      elseif hh < 300 then
        r, g, b = x, 0, c
      else
        r, g, b = c, 0, x
      end
      local function ch(vv2)
        return math.floor((vv2 + m) / 100 * 255)
      end
      return ch(r), ch(g), ch(b)
    end
    local r, g, b = hsv_to_rgb(h, s, v)
    palette[i] = string.format("#%02x%02x%02x", r, g, b)
  end
  return palette
end

local function ensure_hlgroups(bufnr, ft_conf)
  local key = "hlgroups"
  state[bufnr] = state[bufnr] or {}
  if state[bufnr][key] then
    return state[bufnr][key]
  end

  local max_depth = ft_conf.max_depth or 8
  local palette = ft_conf.colors or generate_palette(max_depth, ft_conf.strategy)
  local hls = {}
  for i = 1, max_depth do
    local hl_name = string.format("ChromaticaBracketLevel%d", i)
    vim.api.nvim_set_hl(0, hl_name, {
      fg = palette[((i - 1) % #palette) + 1],
      bold = config.options.bold,
      undercurl = config.options.undercurl,
    })
    hls[i] = hl_name
  end
  state[bufnr][key] = hls
  return hls
end

local function clear_extmarks(bufnr)
  if not state[bufnr] or not state[bufnr].ns then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, state[bufnr].ns, 0, -1)
end

local function get_or_create_ns(bufnr)
  state[bufnr] = state[bufnr] or {}
  if not state[bufnr].ns then
    state[bufnr].ns = vim.api.nvim_create_namespace("chromatica_brackets_" .. bufnr)
  end
  return state[bufnr].ns
end

-- 核心扫描与标记逻辑：简单栈算法按嵌套深度着色
local function decorate(bufnr, ft_conf)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local ns = get_or_create_ns(bufnr)
  clear_extmarks(bufnr)
  local hlgroups = ensure_hlgroups(bufnr, ft_conf)
  local pairs = build_pair_table(ft_conf)

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local start_line = 0
  local end_line = line_count - 1

  -- 大文件只处理可见窗口
  if line_count > config.options.max_lines then
    local win = vim.fn.bufwinid(bufnr)
    if win ~= -1 then
      start_line = vim.fn.line("w0", win) - 1
      end_line = vim.fn.line("w$", win) - 1
    end
  end

  local stack = {}

  for lnum = start_line, end_line do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
    if not line then
      goto continue
    end

    local chars = vim.split(line, "")
    for col, ch in ipairs(chars) do
      local matching = pairs[ch]
      if not matching then
        goto inner_continue
      end

      -- 判断是左括号还是右括号
      local is_left = (matching ~= nil) and (ch == "(" or ch == "[" or ch == "{" or ch == "<")
      if is_left then
        table.insert(stack, { ch = ch, lnum = lnum, col = col - 1 })
        local depth = #stack
        local hl = hlgroups[((depth - 1) % #hlgroups) + 1]
        vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, col - 1, {
          hl_group = hl,
          end_col = col,
          priority = 180,
        })
      else
        -- 右括号：从栈顶找最近可匹配的
        for i = #stack, 1, -1 do
          if pairs[stack[i].ch] == ch then
            local depth = i
            local hl = hlgroups[((depth - 1) % #hlgroups) + 1]
            vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, col - 1, {
              hl_group = hl,
              end_col = col,
              priority = 180,
            })
            table.remove(stack, i)
            break
          end
        end
      end

      ::inner_continue::
    end

    ::continue::
  end
end

-- 防抖包装
local function schedule_decorate(bufnr)
  state[bufnr] = state[bufnr] or {}
  if state[bufnr].timer then
    state[bufnr].timer:stop()
    state[bufnr].timer:close()
    state[bufnr].timer = nil
  end

  local timer = vim.loop.new_timer()
  state[bufnr].timer = timer
  timer:start(config.options.throttle, 0, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      return
    end
    local ft = vim.bo[bufnr].filetype
    local ft_conf = config.get_ft_config(ft)
    if not config.options.enabled then
      clear_extmarks(bufnr)
      return
    end
    decorate(bufnr, ft_conf)
  end))
end

function M.attach(bufnr)
  local ft = vim.bo[bufnr].filetype
  local ft_conf = config.get_ft_config(ft)
  if ft_conf == nil then
    return
  end

  get_or_create_ns(bufnr)
  schedule_decorate(bufnr)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave", "CursorMoved" }, {
    group = vim.api.nvim_create_augroup("ChromaticaBracketsBuf" .. bufnr, { clear = true }),
    buffer = bufnr,
    callback = function()
      schedule_decorate(bufnr)
    end,
  })
end

function M.detach(bufnr)
  clear_extmarks(bufnr)
  if state[bufnr] and state[bufnr].timer then
    state[bufnr].timer:stop()
    state[bufnr].timer:close()
  end
  state[bufnr] = nil
end

function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local ft_conf = config.get_ft_config(ft)
  decorate(bufnr, ft_conf)
end

return M
