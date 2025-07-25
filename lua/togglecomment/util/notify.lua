local M = {}

local name_to_level = {
	warn = vim.log.levels.WARN,
	error = vim.log.levels.ERROR,
}

for name, level in pairs(name_to_level) do
	M[name] = function(msg, ...)
		vim.notify(msg:format(...), level)
	end
end

return M
