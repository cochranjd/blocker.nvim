local M = {}

function M.load()
	vim.notify("Blocker loaded")
end

function M.setup(user_options)
	vim.api.nvim_create_user_command("Blocker", function()
		require("blocker").load()
	end, {})
end

return M
