-- Bootstrap lazy.nvim if it is missing.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.opt.termguicolors = true
vim.opt.mouse = "a"

local persist_view = vim.api.nvim_create_augroup("PersistView", { clear = true })

vim.api.nvim_create_autocmd("BufWinLeave", {
  group = persist_view,
  callback = function(event)
    if vim.bo[event.buf].buftype == "" then
      vim.b[event.buf].__saved_view = vim.fn.winsaveview()
    end
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = persist_view,
  callback = function(event)
    local view = vim.b[event.buf].__saved_view
    if view and vim.bo[event.buf].buftype == "" then
      vim.fn.winrestview(view)
    end
  end,
})

require("lazy").setup({
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = false,
        popup_border_style = "rounded",
        enable_git_status = true,
        enable_diagnostics = false,
        window = {
          position = "left",
          width = 32,
          mappings = {
            ["<space>"] = "none",
          },
        },
        filesystem = {
          follow_current_file = { enabled = true, leave_dirs_open = true },
          hijack_netrw_behavior = "open_current",
          filtered_items = {
            hide_dotfiles = false,
            hide_gitignored = true,
          },
          use_libuv_file_watcher = true,
        },
      })

      vim.keymap.set("n", "<leader>e", ":Neotree toggle filesystem left<CR>", { silent = true, desc = "Toggle Neo-tree" })

      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          if vim.fn.argc() == 0 then
            require("neo-tree.command").execute({
              action = "show",
              source = "filesystem",
              position = "left",
            })
          end
        end,
      })
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    version = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
          mappings = {
            i = {
              ["<C-u>"] = false,
              ["<C-d>"] = false,
            },
          },
        },
      })
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "List buffers" })
    end,
  },
  {
    "nvim-pack/nvim-spectre",
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      local spectre = require("spectre")
      spectre.setup({
        open_cmd = "vnew",
        highlight = { search = "Search", replace = "IncSearch" },
      })
      vim.keymap.set("n", "<leader>sr", spectre.open, { desc = "Spectre: search/replace" })
      vim.keymap.set("n", "<leader>sw", function()
        spectre.open_visual({ select_word = true })
      end, { desc = "Spectre: search word under cursor" })
      vim.keymap.set("v", "<leader>sw", spectre.open_visual, { desc = "Spectre: search selection" })
    end,
  },
  {
    "echasnovski/mini.bufremove",
    version = "*",
    config = function()
      require("mini.bufremove").setup()
      vim.keymap.set("n", "<leader>bd", function()
        require("mini.bufremove").delete(0, false)
      end, { desc = "Close current buffer" })
    end,
  },
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({
        options = {
          numbers = "none",
          mode = "buffers",
          diagnostics = "nvim_lsp",
          show_buffer_close_icons = true,
          show_close_icon = false,
          close_command = function(bufnr)
            require("mini.bufremove").delete(bufnr, false)
          end,
          right_mouse_command = function(bufnr)
            require("mini.bufremove").delete(bufnr, false)
          end,
          separator_style = "slant",
          offsets = {
            {
              filetype = "neo-tree",
              text = "Explorer",
              text_align = "left",
              separator = true,
            },
          },
        },
      })
    end,
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 12,
        open_mapping = [[<c-\>]],
        direction = "horizontal",
        shade_terminals = true,
        persist_mode = true,
      })

      vim.keymap.set("n", "<leader>t", "<cmd>ToggleTerm<CR>", { silent = true, desc = "Toggle integrated terminal" })
    end,
  },
})
