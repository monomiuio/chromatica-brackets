local config = require("chromatica_brackets.config")
local core = require("chromatica_brackets.core")

local M = {}

function M.setup(opts)
  config.setup(opts)

  vim.api.nvim_create_user_command("ChromaticaBracketsToggle", function()
    config.options.enabled = not config.options.enabled
    if not config.options.enabled then
      core.detach(vim.api.nvim_get_current_buf())
    else
      core.attach(vim.api.nvim_get_current_buf())
    end
  end, {})

  vim.api.nvim_create_user_command("ChromaticaBracketsRefresh", function()
    core.refresh()
  end, {})

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ChromaticaBracketsGlobal", { clear = true }),
    callback = function(args)
      core.attach(args.buf)
    end,
  })
end

return M
