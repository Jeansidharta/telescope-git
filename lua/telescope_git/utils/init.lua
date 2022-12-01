local M = {}
M.map =
	--- @alias GitBranchEntry { branch_name: string, remote: string | nil, is_current_branch: boolean, is_local_branch: boolean, is_remote_branch: boolean }
	--- Maps a function over an iterable table
	--- @generic T
	--- @generic R
	--- @param tbl T[] The table that will be iterated over
	--- @param f fun(key: T): R The function that will be aplied over all items of the table
	--- @return R[] A table
	function(tbl, f)
		local t = {}
		for k, v in pairs(tbl) do
			t[k] = f(v)
		end
		return t
	end

M.filter =
	--- Filters an iterable table using the provided function
	--- @generic T
	--- @param tbl T[]
	--- @param f fun(key: T): boolean The filter function. Will be executed on every table item. If this function returns true, the item will be kept. Otherwise, it'll be ignored
	--- @return T[]
	function(tbl, f)
		local t = {}
		for _, v in pairs(tbl) do
			if f(v) then
				table.insert(t, v)
			end
		end
		return t
	end

M.map_filter_non_null = function(tbl, map_fn)
	return M.filter(M.map(tbl, map_fn), function(item)
		return item
	end)
end

return M
