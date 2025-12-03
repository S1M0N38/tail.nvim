-- plugin/tail.lua
--
-- User commands:
--   :TailEnable
--   :TailDisable
--   :TailToggle
--
--   :TailTimestampEnable
--   :TailTimestampDisable
--   :TailTimestampToggle
--
-- Behaviour:
--   - If :TailEnable is called on a *real file buffer*:
--       * opens a split *above* the current window
--       * shows a scratch "tail://<path>" buffer there
--       * feeds `tail -F <path>` into that buffer
--       * enables tail.nvim + timestamps on that scratch buffer
--   - If called on any other buffer (MQTT / already tail:// / etc.):
--       * just calls tail.enable(bufnr) as before.

local tail = require("tail")

-- scratch_bufnr -> job_id for tail -F
local jobs = {}

local function is_regular_file_buf(bufnr)
	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == nil or name == "" then
		return false
	end

	-- don't re-wrap our own scratch buffers
	if name:match("^tail://") then
		return false
	end

	local stat = vim.loop.fs_stat(name)
	return stat ~= nil and stat.type == "file"
end

local function start_tail_job_for_file(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == nil or path == "" then
		return nil
	end

	-- create an unlisted scratch buffer
	local scratch = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(scratch, "tail://" .. path)

	-- scratch buffer options: no file on disk, no swap, auto-wipe, no save nags
	vim.bo[scratch].buftype    = "nofile"
	vim.bo[scratch].bufhidden  = "wipe"
	vim.bo[scratch].swapfile   = false
	vim.bo[scratch].modifiable = true
	vim.bo[scratch].filetype   = vim.bo[bufnr].filetype

	-- open a split *above* the current window and show the scratch buffer there
	local cur_win              = vim.api.nvim_get_current_win()
	vim.cmd("aboveleft split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, scratch)

	-- optionally, make the top window smaller
	local cur_height = vim.api.nvim_win_get_height(cur_win)
	local new_height = math.max(5, math.floor(cur_height / 3))
	pcall(vim.api.nvim_win_set_height, win, new_height)

	local job_id = vim.fn.jobstart({ "tail", "-F", path }, {
		stdout_buffered = false,
		on_stdout = function(_, data, _)
			if not data then
				return
			end
			if #data > 0 and data[#data] == "" then
				table.remove(data)
			end
			if #data == 0 then
				return
			end
			if not vim.api.nvim_buf_is_valid(scratch) then
				return
			end

			vim.api.nvim_buf_set_lines(scratch, -1, -1, false, data)
			-- prevent "No write since last change" when closing this buffer
			vim.bo[scratch].modified = false
		end,
		on_exit = function()
			jobs[scratch] = nil
			if vim.api.nvim_buf_is_valid(scratch) then
				vim.api.nvim_buf_set_lines(
					scratch,
					-1,
					-1,
					false,
					{ "[tail.nvim] tail -F exited for " .. path }
				)
				vim.bo[scratch].modified = false
			end
		end,
	})

	if job_id <= 0 then
		if vim.api.nvim_buf_is_valid(scratch) then
			vim.api.nvim_buf_set_lines(
				scratch,
				-1,
				-1,
				false,
				{ "[tail.nvim] failed to start tail -F for " .. path }
			)
			vim.bo[scratch].modified = false
		end
	else
		jobs[scratch] = job_id
	end

	return scratch
end

----------------------------------------------------------------------
-- Core tail commands
----------------------------------------------------------------------

vim.api.nvim_create_user_command("TailEnable", function()
	local bufnr = vim.api.nvim_get_current_buf()

	if is_regular_file_buf(bufnr) then
		-- external file: create streaming scratch buffer above and tail it
		local scratch = start_tail_job_for_file(bufnr)
		if scratch and vim.api.nvim_buf_is_valid(scratch) then
			tail.enable(scratch)
			-- no backfill here: only new lines get timestamps by default
			tail.timestamps_enable(scratch, { backfill = false })
		end
	else
		-- MQTT / internal buffer / already tail:// → just use normal behaviour
		tail.enable(bufnr)
	end
end, {
	desc = "Enable tail.nvim for current buffer (auto tail -F + split for file buffers)",
})

vim.api.nvim_create_user_command("TailDisable", function()
	local bufnr = vim.api.nvim_get_current_buf()

	-- stop external tail job if this is a scratch tail buffer
	local job_id = jobs[bufnr]
	if job_id then
		pcall(vim.fn.jobstop, job_id)
		jobs[bufnr] = nil
	end

	tail.disable(bufnr)
end, {
	desc = "Disable tail.nvim for current buffer (stops tail -F if used)",
})

vim.api.nvim_create_user_command("TailToggle", function()
	-- simple toggle; job handling is minimal here
	tail.toggle()
end, {
	desc = "Toggle tail.nvim for current buffer",
})

----------------------------------------------------------------------
-- Timestamp commands
----------------------------------------------------------------------

vim.api.nvim_create_user_command("TailTimestampEnable", function()
	tail.timestamps_enable(nil, { backfill = true })
end, {
	desc = "Enable per-line timestamps for current buffer (with backfill)",
})

vim.api.nvim_create_user_command("TailTimestampDisable", function()
	tail.timestamps_disable()
end, {
	desc = "Disable per-line timestamps for current buffer",
})

vim.api.nvim_create_user_command("TailTimestampToggle", function()
	tail.timestamps_toggle(nil, { backfill = false })
end, {
	desc = "Toggle per-line timestamps for current buffer",
})
