# blink_luasnip

[luasnip](https://github.com/L3MON4D3/LuaSnip) completion source for [blink.cmp](https://github.com/Saghen/blink.cmp)

Forked from [cmp_luasnip](https://github.com/saadparwaiz1/cmp_luasnip)

Considering you have Luasnip and blink.cmp already setup, add this to your configuration of the latter (example using lazy.nvim):
```lua
return {
    {
  "saghen/blink.cmp",

  dependencies = {
    "L3MON4D3/LuaSnip",
    "leiserfg/blink_luasnip",
  },
  opts = {
    --  This one is not mandatory but I think it's a good idea to use the same snippet provider so you use the same 
    --  keybindings regardless of how was the snippet expanded
    accept = {
      expand_snippet = require("luasnip").lsp_expand,
    },
    -- Inscribe luasnip and add it to the list of providers
    sources = {
        completion = {
          enabled_providers = { "lsp", "path", "luasnip", "buffer" },
        },

     providers = {
        luasnip = {
            name = "luasnip",
            module = "blink_luasnip",

            score_offset = -3,

            ---@module 'blink_luasnip'
            ---@type blink_luasnip.Options
            opts = {
                use_show_condition = false, -- disables filtering completion candidates
                show_autosnippets = true, 
                show_ghost_text = false,  -- whether to show a preview of the selected snippet (experimental)
            },
        },
      },
      },
    ...
}
```
