local serpent = require("blocker.serpent")
local M = {}
local header_1 = "<cr>:add  -:remove  .:repeat   r:reset"
local header_2 = "c:copy    x:cut     v:paste_block"

local function find_matching_time_label(previous_half_hour)
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	for i, line in ipairs(lines) do
		local time_label = string.match(line, "(%d%d:%d%d %a%a)")
		if time_label == previous_half_hour then
			return i - 1 -- Return the line number (0-based)
		end
	end

	return nil -- Return nil if no match is found
end

local function get_previous_half_hour()
	local current_time = os.date("*t")
	local minute = current_time.min < 30 and 0 or 30
	local hour = current_time.hour
	local period = hour >= 12 and "PM" or "AM"

	if hour > 12 then
		hour = hour - 12
	elseif hour == 0 then
		hour = 12
	end

	return string.format("%02d:%02d %s", hour, minute, period)
end

local function setup_highlight(color)
	vim.cmd("highlight NowHighlight guifg=" .. color .. " gui=bold ctermfg=198 cterm=bold ctermbg=black")
end

local function build_buffer()
	vim.cmd("enew")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false

	return buf
end

local function parse_time_from_string(time_string)
	local hour, minute, period = string.match(time_string, "(%d%d):(%d%d) ([apAP][mM])")

	hour = tonumber(hour)
	minute = tonumber(minute)

	if period:lower() == "pm" and hour ~= 12 then
		hour = hour + 12
	elseif period:lower() == "am" and hour == 12 then
		hour = 0
	end

	local today = os.date("*t")
	local time_table = {
		year = today.year,
		month = today.month,
		day = today.day,
		hour = hour,
		min = minute,
		sec = 0,
	}

	return os.time(time_table)
end

local function offset_time(time, offset)
	return time + (offset * 60)
end

local function convert_time_to_string(time)
	return os.date("%I:%M %p", time)
end

local function build_time(hour, minute)
	local today = os.date("*t")
	return os.time({ year = today.year, month = today.month, day = today.day, hour = hour, min = minute, sec = 0 })
end

function M.update_now_highlight()
	local previous_half_hour = get_previous_half_hour()
	local matching_line = find_matching_time_label(previous_half_hour)

	if matching_line and M.namespace_id then
		local buf = vim.api.nvim_get_current_buf()
		-- Remove any existing highlights in the namespace
		vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, 0, -1)
		-- Add the highlight to the matching line
		vim.api.nvim_buf_add_highlight(buf, M.namespace_id, "NowHighlight", matching_line, 0, -1)
	end
end

function M.build_model()
	M.blocks = {}
	M.times = {}
	local counter = 0

	local start_time = build_time(M.options.start_hour, M.options.start_minute)
	local end_time = build_time(M.options.end_hour, M.options.end_minute)
	local current_time = start_time

	while current_time <= end_time do
		local time_string = convert_time_to_string(current_time)
		M.blocks[time_string] = ""
		M.times[counter] = time_string
		counter = counter + 1
		current_time = current_time + (60 * M.options.division_in_minutes)
	end

	M.max_block_index = counter - 1
end

function M.clear_buffer()
	vim.bo[M.buffer].modifiable = true
	vim.api.nvim_buf_set_lines(M.buffer, 0, -1, false, {})
	vim.bo[M.buffer].modifiable = false
end

function M.build_lines()
	local lines = {}

	table.insert(lines, header_1)
	table.insert(lines, header_2)
	table.insert(lines, "")

	for i = 0, M.max_block_index do
		local time_string = M.times[i]
		local block = M.blocks[time_string] or ""

		table.insert(lines, "----------")
		table.insert(lines, time_string .. "  " .. block)
	end

	return lines
end

function M.render_lines(lines)
	vim.bo[M.buffer].modifiable = true
	vim.api.nvim_buf_set_lines(M.buffer, 0, -1, false, lines)
	vim.bo[M.buffer].modifiable = false
end

function M.refresh_output()
	local lines = M.build_lines()
	M.render_lines(lines)
	M.update_now_highlight()
end

function M.load()
	setup_highlight(M.options.now_color)
	M.load_from_file()
	M.buffer = build_buffer()
	M.namespace_id = vim.api.nvim_create_namespace("TimeBlockNamespace")

	M.refresh_output()
	M.setup_keymaps()
	M.setup_now_highlight()
end

function M.setup_keymaps()
	vim.api.nvim_buf_set_keymap(
		M.buffer,
		"n",
		"<CR>",
		':lua require("blocker").handle_action("add")<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		M.buffer,
		"n",
		"-",
		':lua require("blocker").handle_action("remove")<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		M.buffer,
		"n",
		".",
		':lua require("blocker").handle_action("repeat_previous")<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		M.buffer,
		"n",
		"yy",
		':lua require("blocker").handle_action("copy")<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		M.buffer,
		"n",
		"dd",
		':lua require("blocker").handle_action("cut")<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		M.buffer,
		"n",
		"p",
		':lua require("blocker").handle_action("paste")<CR>',
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		M.buffer,
		"n",
		"r",
		':lua require("blocker").handle_action("reset")<CR>',
		{ noremap = true, silent = true }
	)
end

function M.setup_now_highlight()
	local timer = vim.loop.new_timer()
	timer:start(0, 30000, vim.schedule_wrap(M.update_now_highlight))

	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			timer:stop()
			timer:close()
		end,
	})
end

function M.get_time_string_for_current_line()
	local cursor_line = vim.fn.line(".") - 1
	local line_content = vim.api.nvim_buf_get_lines(M.buffer, cursor_line, cursor_line + 1, false)[1]
	return string.match(line_content, "^(%d%d:%d%d [AP]M).*")
end

function M.build_action_lookups()
	M.actions = {
		add = M.add_action,
		remove = M.remove_action,
		repeat_previous = M.repeat_previous_action,
		copy = M.copy_action,
		cut = M.cut_action,
		paste = M.paste_action,
		reset = M.reset_action,
	}
end

function M.handle_action(action)
	M.actions[action]()
	M.write_to_file()
end

function M.update_block(time_string, content)
	M.blocks[time_string] = content
	M.refresh_output()
end

function M.add_action()
	local time_string = M.get_time_string_for_current_line()
	if time_string == nil then
		return
	end

	-- Get the block content
	local content = vim.fn.input("Enter block content: ")
	if content == nil or content == "" then
		return
	end

	M.update_block(time_string, content)
end

function M.remove_action()
	local time_string = M.get_time_string_for_current_line()
	if time_string == nil then
		return
	end

	M.update_block(time_string, "")
end

function M.repeat_previous_action()
	local time_string = M.get_time_string_for_current_line()
	if time_string == nil then
		return
	end

	local previous_time_string = M.get_offset_time_string(time_string, -1)
	local previous_content = M.blocks[previous_time_string]
	M.update_block(time_string, previous_content)

	local next_time_string = M.get_offset_time_string(time_string, 1)
	M.advance_cursor_until(next_time_string)
end

function M.advance_cursor_until(next_time_string)
	local total_lines = vim.api.nvim_buf_line_count(M.buffer)
	local pattern = "^" .. next_time_string

	for i = vim.fn.line(".") - 1, total_lines - 1 do
		local line = vim.api.nvim_buf_get_lines(M.buffer, i, i + 1, false)[1]
		if line:match(pattern) then
			vim.api.nvim_win_set_cursor(0, { i + 1, 0 })
			return
		end
	end
end

function M.copy_action()
	local time_string = M.get_time_string_for_current_line()
	if time_string == nil then
		return
	end

	M.stashed_content = M.blocks[time_string]
end

function M.cut_action()
	local time_string = M.get_time_string_for_current_line()
	if time_string == nil then
		return
	end

	M.stashed_content = M.blocks[time_string]
	M.update_block(time_string, "")
end

function M.paste_action()
	if M.stashed_content == nil or M.stashed_content == "" then
		return
	end

	local time_string = M.get_time_string_for_current_line()
	if time_string == nil then
		return
	end

	M.update_block(time_string, M.stashed_content)
end

function M.reset_action()
	for time_string in pairs(M.blocks) do
		M.blocks[time_string] = ""
	end
	M.refresh_output()
end

function M.get_offset_time_string(time_string, offset)
	local time = parse_time_from_string(time_string)
	local previous_time = offset_time(time, offset * M.options.division_in_minutes)
	return convert_time_to_string(previous_time)
end

function M.write_to_file()
	local date = os.date("%Y-%m-%d")
	local filename = vim.fn.expand(M.options.blockfile_dir .. "/" .. date .. ".txt")
	local file = io.open(filename, "w")
	if not file then
		return
	end

	local serializedData = serpent.dump(M.blocks)
	file:write(serializedData)
	file:close()
end
-- function M.write_to_file()
-- 	local filename = vim.fn.expand(M.options.blockfile)
-- 	local file = io.open(filename, "w")
-- 	if not file then
-- 		return
-- 	end
--
-- 	local serializedData = serpent.dump(M.blocks)
-- 	file:write(serializedData)
-- 	file:close()
-- end

function M.load_from_file()
	local date = os.date("%Y-%m-%d")
	local filename = vim.fn.expand(M.options.blockfile_dir .. "/" .. date .. ".txt")
	local file = io.open(filename, "r")
	if not file then
		return
	end

	local serialized_data = file:read("*all")
	file:close()

	local loadFunction = load(serialized_data)
	M.blocks = loadFunction()
end
-- function M.load_from_file()
-- 	local filename = vim.fn.expand(M.options.blockfile)
-- 	local file = io.open(filename, "r")
-- 	if not file then
-- 		return
-- 	end
--
-- 	local serialized_data = file:read("*all")
-- 	file:close()
--
-- 	local loadFunction = load(serialized_data)
-- 	M.blocks = loadFunction()
-- end

function M.setup(user_options)
	M.options = {
		start_hour = 9,
		start_minute = 0,
		end_hour = 17,
		end_minute = 0,
		division_in_minutes = 30,
		-- blockfile = "~/.blocker.nvim/blocks.text",
		blockfile_dir = "~/.blocker.nvim",
		now_color = "#ff007c",
	}

	M.options = vim.tbl_extend("force", M.options, user_options)
	vim.fn.mkdir(vim.fn.expand(M.options.blockfile_dir), "p")
	vim.api.nvim_create_user_command("Blocker", function()
		require("blocker").load()
	end, {})

	M.stashed_content = nil
	M.build_model()
	M.build_action_lookups()
end

return M
