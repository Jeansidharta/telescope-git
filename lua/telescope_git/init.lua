local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local Job = require("plenary.job")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local notify = require("notify")

local M = {}

--- Maps a function over an iterable table
--- @param tbl table The table that will be iterated over
--- @param f fun(key: any): any The function that will be aplied over all items of the table
--- @return table A table
function map(tbl, f)
	local t = {}
	for k, v in pairs(tbl) do
		t[k] = f(v)
	end
	return t
end

--- Creates highlights for the branches previewer
--- @param bufnr number The number of the preview buffer
function set_branches_previewer_highlights(bufnr)
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd([[syntax match BranchNames "(\zs.\{-1,}\ze)"]])
		-- vim.cmd([[syntax match TimeAgo "[0-9]\+ \w\+ ago -\@="]])
		vim.cmd([[syntax match PrecedingInfo "\(^.\+  \)\zs[^*]\{-1,}\( -\)\@="]])
		vim.cmd([[syntax match CurrentCursorLine "^\%#.\+$"]])
		vim.cmd([[highligh CurrentCursorLine guibg=#2c008a]])
		vim.cmd([[highligh link BranchNames Keyword]])
		vim.cmd([[highligh PrecedingInfo guifg=#12ee00]])
	end)
end

--- Jumps the cursor to the selected branch, and makes sure it's in
--- the middle of the screen when possible
--- @param bufnr number The buffer number of the previewer buffer
function previewer_jump_to_branch(bufnr, entry)
	vim.api.nvim_buf_call(bufnr, function()
		-- Highlights the cursor line
		vim.wo.cursorline = true

		local branch_name = entry.value.tracked and entry.value.branch_name
			or entry.value.remote .. "/" .. entry.value.branch_name
		local branch_line = vim.fn.search("([^)]*[^/]\\=" .. branch_name .. ".*)", "n")
		local window_height = vim.fn.winheight(0)
		local window_top_line = branch_line - window_height / 2
		local window_bottom_line = branch_line + window_height / 2
		print(branch_line .. ", " .. window_height .. ", " .. window_top_line)
		if window_top_line >= 0 then
			vim.cmd("normal " .. window_top_line .. "G")
		end
		vim.cmd("normal " .. window_bottom_line .. "G")
		vim.cmd("normal 0") -- Go to the start of the line
		vim.cmd("normal " .. branch_line .. "G")
	end)
end

function get_cwd_of_bufnr(bufnr)
	vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
end

--- @param format_type string
function make_git_graph(current_user_buffernr, format_type)
	--- @type string
	return Job:new({
		command = "git",
		args = { "log", "--graph", "--all", "--decorate", "--format=format: " .. format_type },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	}):sync()
end

vim.api.nvim_set_hl(0, "Telescope_CurrentBranch", { fg = "#aaff00" })

M.all_branches = function(opts)
	opts = opts or {}

	local current_user_buffernr = vim.api.nvim_win_get_buf(0)

	--- @type boolean
	local has_set_previewer = false

	--- @type string[]
	local git_branches = Job:new({
		command = "git",
		args = { "branch", "--all" },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	}):sync()

	--- Git branches treated
	--- @type { branch_name: string, remote: string | nil, is_current_branch: boolean, tracked: boolean | nil }[]
	local treated_git_branches = map(
		git_branches,
		--- @param branch string
		function(branch)
			local start_index, end_index, remote = branch:find("remotes/([^/]+)/")
			local is_remote_branch = start_index ~= nil
			local branch_name = is_remote_branch and branch:sub(end_index + 1) or branch
			branch_name = branch_name:gsub("^%s+", "")
			local is_current_branch = branch_name:find("*") == 1
			if is_current_branch then
				branch_name = branch_name:gsub("^* ", "")
			end
			if is_remote_branch and branch_name:find("HEAD") ~= nil then
				branch_name = "HEAD"
			end

			return {
				branch_name = branch_name,
				remote = remote or nil,
				is_current_branch = is_current_branch,
				tracked = nil,
			}
		end
	)

	local tracked_git_branches = {}
	for key, branch in pairs(treated_git_branches) do
		local branch_name = branch.branch_name
		if tracked_git_branches[branch_name] ~= nil then
			tracked_git_branches[branch_name].tracked = true
		else
			table.insert(tracked_git_branches, branch)
			tracked_git_branches[branch_name] = branch
			branch.tracked = false
		end
	end

	--- @type number
	local previewer_bufnr

	local graph_formats = {
		"%cr -%d %s",
		"%cn -%d %s",
		"%p -%d %s",
		current = 1,
	}

	function get_format()
		local format = graph_formats[graph_formats.current]
		graph_formats.current = graph_formats.current + 1
		if graph_formats.current > #graph_formats then
			graph_formats.current = 1
		end
		return format
	end

	local picker = pickers.new(opts, {
		prompt_title = "Git Branches",
		finder = finders.new_table({
			results = tracked_git_branches,
			entry_maker = function(entry)
				--- @type string
				local display
				if entry.tracked then
					display = entry.branch_name
				elseif entry.branch_name == "HEAD" then
					display = "[" .. entry.remote .. "] " .. entry.branch_name
				else
					display = "[UNT] " .. entry.branch_name
				end
				return {
					value = entry,
					display = function()
						local highligh_groups = {}
						if entry.is_current_branch then
							table.insert(highligh_groups, { { 0, 1000 }, "Telescope_CurrentBranch" })
						end
						return display, highligh_groups
					end,
					ordinal = display,
				}
			end,
		}),
		previewer = previewers.new_buffer_previewer({
			title = "Branches",
			get_buffer_by_name = function()
				return "git_branches"
			end,
			define_preview = function(self, entry)
				local bufnr = self.state.bufnr
				previewer_bufnr = bufnr
				if not has_set_previewer then
					local graph = make_git_graph(current_user_buffernr, get_format())
					vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, graph)
					set_branches_previewer_highlights(bufnr)
					has_set_previewer = true
				end
				previewer_jump_to_branch(bufnr, entry)
			end,
		}),
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, mapping)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				print(vim.inspect(selection))
				-- vim.api.nvim_put({ selection[1] }, "", false, true)
			end)

			function switch_previewer_info()
				local graph = make_git_graph(current_user_buffernr, get_format())
				vim.api.nvim_buf_set_lines(previewer_bufnr, 0, -1, false, graph)
			end

			mapping("i", "<C-r>", switch_previewer_info)
			mapping("n", "<C-r>", switch_previewer_info)
			return true
		end,
	})

	picker:find()
end

M.all_branches()

return M
