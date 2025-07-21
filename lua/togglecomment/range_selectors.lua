local util = require("togglecomment.util")
return {
	shortest = function()
		local best

		return {
			record = function(new)
				if best.range == nil or util.range_includes_range(best.range, new.range) then
					best = new
				end
			end,
			retrieve = function()
				return best
			end
		}
	end,
	sorted = function()
		local sorted = {}

		return {
			record = function(new)
				for i = 1, #sorted do
					if util.range_includes_range(sorted[i].range, new.range) then
						-- ranges are before all ranges that include them =>
						-- ordered by inclusion.
						-- Obv. a non-O(n^2) sorting algorithm would be better here :D
						table.insert(sorted, i, new)
						return
					end
				end
				table.insert(sorted, new)
			end,
			retrieve = function()
				return sorted
			end
		}
	end
}
