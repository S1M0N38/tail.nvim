-- plugin/tail.lua
-- Exposed Commands

local tail = require("tail")

vim.api.nvim_create_user_command("TailEnable", function()
	tail.enable()
end, { desc = "Enable tail.nvim for the current buffer" })

vim.api.nvim_create_user_command("TailDisable", function()
	tail.disable()
end, { desc = "Disable tail.nvim for the current buffer" })

vim.api.nvim_create_user_command("TailToggle", function()
	tail.toggle()
end, { desc = "Toggle tail.nvim for the current buffer" })

vim.api.nvim_create_user_command("TailTimestampEnable", function()
	tail.timestamps_enable(0, { backfill = false })
end, { desc = "Enable timestamps for current buffer" })

vim.api.nvim_create_user_command("TailTimestampDisable", function()
	tail.timestamps_disable()
end, { desc = "Disable timestamps for current buffer" })

vim.api.nvim_create_user_command("TailTimestampToggle", function()
	tail.timestamps_toggle(0, { backfill = false })
end, { desc = "Toggle timestamps for current buffer" })
