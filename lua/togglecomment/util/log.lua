local util = require("togglecomment.util")
local notify require("togglecomment.util.notify")

-- older neovim-versions (even 0.7.2) do not have stdpath("log").
local logpath = vim.fn.stdpath("log")

-- just to be sure this dir exists.
-- 448 = 0700
vim.loop.fs_mkdir(logpath, 448)

local log_location = logpath .. "/togglecomment.log"
local log_old_location = logpath .. "/togglecomment.log.old"

local log_fd = vim.loop.fs_open(
	log_location,
	-- only append.
	"a",
	-- 420 = 0644
	420
)

local log_line_append
if not log_fd then
	-- print a warning
	notify.warn(
		"Togglecomment: could not open log at %s. Not logging for this session.", log_location
	)
	-- make log_line_append do nothing.
	log_line_append = util.nop
else
	log_line_append	= function(msg)
		msg = msg:gsub("\n", "\n      | ")
		vim.loop.fs_write(log_fd, msg .. "\n")
	end

	-- if log_fd found, check if log should be rotated.
	local logsize = vim.loop.fs_fstat(log_fd).size
	if logsize > 10 * 2 ^ 20 then
		-- logsize > 10MiB:
		-- move log -> old log, start new log.
		vim.loop.fs_rename(log_location, log_old_location)
		log_fd = vim.loop.fs_open(
			log_location,
			-- only append.
			"a",
			-- 420 = 0644
			420
		)
	end
end

local M = {}

--- The file path we're currently logging into.
function M.log_location()
	return logpath
end
--- Time formatting for logs. Defaults to '%X'.
M.time_fmt = "%X"

local function make_log_level(level)
	return function(msg)
		log_line_append(
			string.format("%s | %s | %s", level, os.date(M.time_fmt), msg)
		)
	end
end

local log = {
	error = make_log_level("ERROR"),
	warn = make_log_level("WARN"),
	info = make_log_level("INFO"),
	debug = make_log_level("DEBUG"),
}

-- functions copied directly by deepcopy.
-- will be initialized later on, by set_loglevel.
local effective_log

-- map level-name to enabled (1) and disabled (2) levels.
local en_disabled_loglevels_by_id = {
	none  = {{},{"error" , "warn" , "info" , "debug"}   },
	error = {   {"error"},{"warn" , "info" , "debug"}   },
	warn  = {   {"error" , "warn"},{"info" , "debug"}   },
	info  = {   {"error" , "warn" , "info"},{"debug"}   },
	debug = {   {"error" , "warn" , "info" , "debug"},{}},
}

-- special key none disable all logging.
function M.set_loglevel(target_level)
	assert(en_disabled_loglevels_by_id[target_level] ~= nil, "invalid level `" .. target_level .. "`!")

	-- reset effective loglevels, set those with importance higher than
	-- target_level, disable (nop) those with lower.
	effective_log = {}
	for _, enabled_level in ipairs(en_disabled_loglevels_by_id[target_level][1]) do
		effective_log[enabled_level] = log[enabled_level]
	end
	for _, enabled_level in ipairs(en_disabled_loglevels_by_id[target_level][2]) do
		effective_log[enabled_level] = util.nop
	end
end

function M.new(module_name)
	local module_log = {}
	for name, _ in pairs(log) do
		module_log[name] = function(msg, ...)
			-- don't immediately get the referenced function, we'd like to
			-- allow changing the loglevel on-the-fly.
			effective_log[name](module_name .. ": " .. msg:format(...))
		end
	end
	return module_log
end

function M.open()
	vim.cmd(("tabnew %s"):format(log_location))
end

-- to verify log is working.
function M.ping()
	log_line_append(("PONG  | pong! (%s)"):format(os.date()))
end

-- set default-loglevel.
M.set_loglevel("warn")

return M
