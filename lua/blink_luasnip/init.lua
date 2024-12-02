---@class blink_luasnip.Options
---@field use_show_condition? boolean Disables filtering completion candidates
---@field show_autosnippets? boolean Whether to show autosnippets in the completion list
---@field show_ghost_text? boolean Whether to show a preview of the selected snippet (experimental)

local util = require "vim.lsp.util"

local source = {}

local defaults_config = {
  use_show_condition = true,
  show_autosnippets = false,
}

---@param user_config blink_luasnip.Options
function source.new(user_config)
  local config = vim.tbl_deep_extend("keep", user_config or {}, defaults_config)
  vim.validate {
    use_show_condition = { config.use_show_condition, "boolean" },
    show_autosnippets = { config.show_autosnippets, "boolean" },
  }
  local self = setmetatable({}, { __index = source })
  self.config = config
  return self
end

local snip_cache = {}
local doc_cache = {}

-- How whitespace and indentation is handled during completion item insertion.
-- Ref: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#insertTextMode
-- Note that blink.cmp only supports `AsIs` for now.
local INSERT_TEXT_MODE_ASIS = 1

function source.clear_cache()
  snip_cache = {}
  doc_cache = {}
end

function source.refresh()
  local ft = require("luasnip.session").latest_load_ft
  snip_cache[ft] = nil
  doc_cache[ft] = nil
end

local function get_documentation(snip, data)
  local header = (snip.name or "") .. " _ `[" .. data.filetype .. "]`\n"
  local docstring = { "", "```" .. vim.bo.filetype, snip:get_docstring(), "```" }
  local documentation = { header .. "---", (snip.dscr or ""), docstring }
  documentation = util.convert_input_to_markdown_lines(documentation)
  documentation = table.concat(documentation, "\n")

  doc_cache[data.filetype] = doc_cache[data.filetype] or {}
  doc_cache[data.filetype][data.snip_id] = documentation
  return documentation
end

source.get_keyword_pattern = function()
  return "\\%([^[:alnum:][:blank:]]\\|\\w\\+\\)"
end

function source:enabled()
  local ok, _ = pcall(require, "luasnip")
  return ok
end

function source:get_completions(ctx, callback)
  local filetypes = require("luasnip.util.util").get_snippet_filetypes()
  local items = {}

  for i = 1, #filetypes do
    local ft = filetypes[i]
    if not snip_cache[ft] then
      -- ft not yet in cache.
      local ft_items = {}
      local ft_table = require("luasnip").get_snippets(ft, { type = "snippets" })
      local iter_tab
      if self.config.show_autosnippets then
        local auto_table = require("luasnip").get_snippets(ft, { type = "autosnippets" })
        iter_tab = { { ft_table, false }, { auto_table, true } }
      else
        iter_tab = { { ft_table, false } }
      end
      for _, ele in ipairs(iter_tab) do
        local tab, auto = unpack(ele)
        for _, snip in pairs(tab) do
          if not snip.hidden then
            local complete_opts = {
              label = snip.trigger,
              kind = vim.lsp.protocol.CompletionItemKind.Snippet,
              data = {
                priority = snip.effective_priority or 1000, -- Default priority is used for old luasnip versions
                filetype = ft,
                snip_id = snip.id,
                show_condition = snip.show_condition,
                auto = auto,
              },
              insertText = "",
            }
            ft_items[#ft_items + 1] = complete_opts
          end
        end
      end
      table.sort(ft_items, function(a, b)
        return a.data.priority > b.data.priority
      end)
      snip_cache[ft] = ft_items
    end
    vim.list_extend(items, snip_cache[ft])
  end

  if self.config.use_show_condition then
    local line_to_cursor = ctx.cursor_before_line
    items = vim.tbl_filter(function(i)
      -- check if show_condition exists in case (somehow) user updated blink_luasnip but not luasnip
      return not i.data.show_condition or i.data.show_condition(line_to_cursor)
    end, items)
  end

  callback { is_incomplete_forward = false, is_incomplete_backwards = false, items = items }
end

function source:resolve(completion_item, callback)
  local item_snip_id = completion_item.data.snip_id
  local snip = require("luasnip").get_id_snippet(item_snip_id)
  local doc_ft = doc_cache[completion_item.data.filetype] or {}
  local doc_itm = doc_ft[completion_item.data.snip_id]
    or get_documentation(snip, completion_item.data)
  completion_item.documentation = {
    kind = "markdown",
    value = doc_itm,
  }
  callback(completion_item)
end

function source:can_execute()
  return true
end

function source:execute(ctx, completion_item)
  local snip = require("luasnip").get_id_snippet(completion_item.data.snip_id)

  -- if trigger is a pattern, expand "pattern" instead of actual snippet.
  if snip.regTrig then
    snip = snip:get_pattern_expand_helper()
  end

  local line =
    ctx.line:sub(ctx.bounds.start_col, ctx.bounds.start_col + ctx.bounds.length - 1)
  local expand_params = snip:matches(line)

  require("luasnip").snip_expand(snip, {
    expand_params = expand_params,
  })
end

return source
