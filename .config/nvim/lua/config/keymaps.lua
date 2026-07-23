-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

map({ "t" }, "<A-m>", "<C-\\><C-n>", { silent = true })

local wk = require("which-key")
wk.add({
  { "<leader>fs", "<leader>fs", desc = "File Save" },

  { "<leader>t", group = "Terminal" },
  { "<leader>tr", "<Cmd>vnew | te<CR>", desc = "Terminal Right" },
  { "<leader>td", "<Cmd>split | te<CR>", desc = "Terminal Down" },

  { ']"', '/"<CR>', desc = "Next quote" },
  { '["', '?"<CR>', desc = "Previous quote" },
})
