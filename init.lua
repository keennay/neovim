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

local function delete_buffer(bufnr)
  local ok, bufremove = pcall(require, "mini.bufremove")
  if ok then
    bufremove.delete(bufnr, false)
  else
    vim.cmd(("bdelete %d"):format(bufnr))
  end
end

local function close_all_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then
      delete_buffer(buf)
    end
  end
end

local function close_saved_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and not vim.bo[buf].modified then
      delete_buffer(buf)
    end
  end
end

local function with_bufferline_buf(bufnr, fn)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_set_current_buf(bufnr)
  local ok, bufferline = pcall(require, "bufferline")
  if ok then
    fn(bufferline)
  end
end

local function close_others_for(bufnr)
  with_bufferline_buf(bufnr, function(bufferline)
    bufferline.close_others()
  end)
end

local function close_right_of(bufnr)
  with_bufferline_buf(bufnr, function(bufferline)
    bufferline.close_in_direction("right")
  end)
end

local tab_menu = { win = nil, buf = nil, target = nil }

local function close_tab_menu()
  if tab_menu.win and vim.api.nvim_win_is_valid(tab_menu.win) then
    vim.api.nvim_win_close(tab_menu.win, true)
  end
  if tab_menu.buf and vim.api.nvim_buf_is_valid(tab_menu.buf) then
    vim.api.nvim_buf_delete(tab_menu.buf, { force = true })
  end
  tab_menu.win = nil
  tab_menu.buf = nil
  tab_menu.target = nil
end

local function show_tab_actions(bufnr)
  close_tab_menu()
  tab_menu.target = bufnr

  local actions = {
    { label = "Close", fn = function() delete_buffer(bufnr) end },
    { label = "Close Others", fn = function() close_others_for(bufnr) end },
    { label = "Close to the Right", fn = function() close_right_of(bufnr) end },
    { label = "Close Saved", fn = close_saved_buffers },
    { label = "Close All", fn = close_all_buffers },
  }

  local lines = { "[-] [x]", "" }
  local width = 7
  for i, action in ipairs(actions) do
    local line = string.format("%d. %s", i, action.label)
    lines[#lines + 1] = line
    width = math.max(width, #line)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "TabActions")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = width + 4,
    height = #lines,
    row = 2,
    col = math.max(0, math.floor((vim.o.columns - (width + 4)) / 2)),
    title = " Tab Actions ",
    title_pos = "center",
  })

  tab_menu.buf = buf
  tab_menu.win = win

  local function run_action_at_cursor()
    if not (tab_menu.win and vim.api.nvim_win_is_valid(tab_menu.win)) then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(tab_menu.win)
    local row = cursor[1]
    local col = cursor[2] + 1
    if row == 1 then
      if (col >= 1 and col <= 3) or (col >= 5 and col <= 7) then
        close_tab_menu()
      end
      return
    end
    local action = actions[row - 2]
    if action then
      close_tab_menu()
      action.fn()
    end
  end

  vim.keymap.set("n", "<CR>", run_action_at_cursor, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<LeftMouse>", function()
    local ok, mouse = pcall(vim.fn.getmousepos)
    if not ok or mouse.winid ~= tab_menu.win then
      close_tab_menu()
      return
    end
    vim.schedule(function()
      vim.api.nvim_win_set_cursor(tab_menu.win, { mouse.line, math.max(mouse.column - 1, 0) })
      run_action_at_cursor()
    end)
  end, { buffer = buf, nowait = true, silent = true })

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, close_tab_menu, { buffer = buf, nowait = true, silent = true })
  end

  vim.api.nvim_create_autocmd({ "BufLeave", "TabLeave" }, {
    buffer = buf,
    once = true,
    callback = function()
      close_tab_menu()
    end,
  })
end

local function handle_tab_click(bufnr)
  if tab_menu.win and vim.api.nvim_win_is_valid(tab_menu.win) then
    local previous_target = tab_menu.target
    close_tab_menu()
    if bufnr ~= previous_target then
      vim.api.nvim_set_current_buf(bufnr)
    end
    return
  end

  if bufnr == vim.api.nvim_get_current_buf() then
    show_tab_actions(bufnr)
  else
    vim.api.nvim_set_current_buf(bufnr)
  end
end

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
            h = "close_node",
            l = "open",
            ["<left>"] = "close_node",
            ["<right>"] = "open",
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
            delete_buffer(bufnr)
          end,
          right_mouse_command = false,
          middle_mouse_command = false,
          left_mouse_command = handle_tab_click,
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
