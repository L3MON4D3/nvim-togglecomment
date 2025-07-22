local M = {}

local function fetch_lines_safe(buf, from, to, n_lines)
	if from == nil then
		print(buf, from, to)
	end
	local max_to = n_lines
	local clamped_from = math.max(from, 0)
	local clamped_to = math.min(to, max_to)
	return clamped_from, clamped_to, vim.api.nvim_buf_get_lines(buf, clamped_from, clamped_to, true)
end

local extend_factor = 1.5
local initial_range_pm = 10

---@class ToggleComment.LazyContiguousLinerange
local LazyContiguousLinerange = {}
local LazyContiguousLinerange_mt = {__index = function(t, k)
	if type(k) == "number" then
		if k < 0 or k >= t.n_lines then
			return nil
		end

		local from, to, lines
		if k < t.fetched_range_from then
			local n_required_lines = t.fetched_range_to - k
			-- prefetch a bit.
			-- This might be negative/outside the buffer range, but that's
			-- fine, we use the safe prefetch.
			local fetch_from = math.floor(t.fetched_range_to - extend_factor*n_required_lines)
			local fetch_to = t.fetched_range_from
			from, to, lines = fetch_lines_safe(0, fetch_from, fetch_to, t.n_lines)
			t.fetched_range_from = from
		elseif k >= t.fetched_range_to then
			local n_required_lines = k - t.fetched_range_from
			local fetch_to = math.ceil(t.fetched_range_from + extend_factor*n_required_lines)
			local fetch_from = t.fetched_range_to
			from, to, lines = fetch_lines_safe(0, fetch_from, fetch_to, t.n_lines)
			t.fetched_range_to = to
		end

		for i = from, to-1 do
			rawset(t, i, lines[i - from + 1])
		end
		return t[k]
	else
		return LazyContiguousLinerange[k]
	end
end}

function LazyContiguousLinerange.new(opts)
	local initial_from, initial_to
	if opts.center then
		initial_from = opts.center-initial_range_pm
		initial_to = opts.center+initial_range_pm
	else
		initial_from = opts.from
		initial_to = opts.to
	end
	-- ought to be enough for most comments.
	local n_lines = vim.api.nvim_buf_line_count(0)
	local from, to, lines = fetch_lines_safe(0, initial_from, initial_to, n_lines)
	local o = {}
	for i = from, to-1 do
		o[i] = lines[i - from + 1]
	end

	o.fetched_range_from = from
	o.fetched_range_to = to
	o.n_lines = n_lines
	return setmetatable(o, LazyContiguousLinerange_mt)
end

function LazyContiguousLinerange:get_text(range)
	local text = {}
	for i = range[1], range[3] do
		table.insert(text, self[i])
	end

	text[#text] = text[#text]:sub(1, range[4])
	text[1] = text[1]:sub(range[2]+1)

	return text
end

M.new = LazyContiguousLinerange.new

return M
