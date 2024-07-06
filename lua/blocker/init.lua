local M = {}

local function convert_time_to_string(time)
	return os.date("%I:%M%p", time)
end

local function build_time(hour, minute)
	local today = os.date("*t")
	return os.time({ year = today.year, month = today.month, day = today.day, hour = hour, min = minute, sec = 0 })
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

function M.draw_blocks()
	for i = 0, M.max_block_index do
		local time_string = M.times[i]
		local block = M.blocks[time_string]
		print(time_string, block)
	end
end

function M.load()
	vim.notify("Blocker loaded")
	M.draw_blocks()
end

function M.setup(user_options)
	M.options = {
		start_hour = 9,
		start_minutes = 0,
		end_hour = 17,
		end_minutes = 0,
		division_in_minutes = 30,
	}

	M.options = vim.tbl_extend("force", M.options, user_options)
	vim.api.nvim_create_user_command("Blocker", function()
		require("blocker").load()
	end, {})
	M.build_model()
end

return M
