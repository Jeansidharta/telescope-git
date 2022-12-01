local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local Job = require("plenary.job")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local notify = require("notify")

local M = {}

--- @alias GitBranchEntry { branch_name: string, remote: string | nil, is_current_branch: boolean, is_local_branch: boolean, is_remote_branch: boolean }

--- Maps a function over an iterable table
--- @generic T
--- @generic R
--- @param tbl T[] The table that will be iterated over
--- @param f fun(key: T): R The function that will be aplied over all items of the table
--- @return R[] A table
function map(tbl, f)
	local t = {}
	for k, v in pairs(tbl) do
		t[k] = f(v)
	end
	return t
end

--- Filters an iterable table using the provided function
--- @generic T
--- @param tbl T[]
--- @param f fun(key: T): boolean The filter function. Will be executed on every table item. If this function returns true, the item will be kept. Otherwise, it'll be ignored
--- @return T[]
function filter(tbl, f)
	local t = {}
	for _, v in pairs(tbl) do
		if f(v) then
			table.insert(t, v)
		end
	end
	return t
end

function map_filter_non_null(tbl, map_fn)
	return filter(map(tbl, map_fn), function(item)
		return item
	end)
end

--- Creates highlights for the branches previewer
--- @param bufnr number The number of the preview buffer
function set_branches_previewer_highlights(bufnr)
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd([[syntax match BranchNames "(\zs.\{-1,}\ze)"]])
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
--- @param entry { value: GitBranchEntry }
function previewer_jump_to_branch(bufnr, entry)
	vim.api.nvim_buf_call(bufnr, function()
		-- Highlights the cursor line
		vim.wo.cursorline = true

		local branch_name = entry.value.is_local_branch and entry.value.branch_name
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
	return vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
end

function sync_job_with_error_notify(job)
	local result, code = job:sync()

	if code ~= 0 then
		vim.notify(table.concat(job:stderr_result(), "\n"), "error")
		return nil
	end

	return result
end

--- @param current_user_buffernr number
--- @param format_type string
--- @return string[] | nil
function make_git_graph(current_user_buffernr, format_type)
	local job = Job:new({
		command = "git",
		args = { "log", "--graph", "--all", "--decorate", "--format=format: " .. format_type },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	})

	return sync_job_with_error_notify(job)
end

--- @param current_user_buffernr number
--- @return string[] | nil
function get_git_branches(current_user_buffernr)
	local job = Job:new({
		command = "git",
		args = { "branch", "--all" },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	})

	return sync_job_with_error_notify(job)
end

--- @param current_user_buffernr number
--- @param branch_name number
--- @return boolean
function git_checkout(current_user_buffernr, branch_name)
	local job = Job:new({
		command = "git",
		args = { "checkout", branch_name },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	})

	return sync_job_with_error_notify(job) ~= nil
end

--- @param current_user_buffernr number
--- @param branch_name number
--- @return boolean
function git_merge(current_user_buffernr, branch_name)
	local job = Job:new({
		command = "git",
		args = { "merge", branch_name },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	})

	return sync_job_with_error_notify(job) ~= nil
end

--- @param current_user_buffernr number
--- @param branch_name number
--- @param mode "soft" | "hard"
--- @return boolean
function git_reset(current_user_buffernr, branch_name, mode)
	local args = { "reset" }

	if mode == "hard" then
		table.insert(args, "--hard")
	end

	table.insert(args, branch_name)

	local job = Job:new({
		command = "git",
		args = args,
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	})

	return sync_job_with_error_notify(job) ~= nil
end

--- @param branch_name number
--- @param current_user_buffernr number
--- @return boolean
function git_create_branch(current_user_buffernr, branch_name)
	local job = Job:new({
		command = "git",
		args = { "branch", branch_name },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	})

	return sync_job_with_error_notify(job) ~= nil
end

--- @param current_user_buffernr number
--- @return boolean
function git_fetch(current_user_buffernr)
	local job = Job:new({
		command = "git",
		args = { "fetch", "--prune" },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	})

	return sync_job_with_error_notify(job) ~= nil
end

--- @param branch_name number
--- @param current_user_buffernr number
--- @return boolean
function git_delete_branch(current_user_buffernr, branch_name)
	local job = Job:new({
		command = "git",
		args = { "branch", "--delete", branch_name },
		cwd = get_cwd_of_bufnr(current_user_buffernr),
	})

	return sync_job_with_error_notify(job) ~= nil
end

function get_git_branches_and_parse_them(current_user_buffernr)
	local git_branches = get_git_branches(current_user_buffernr)

	local seen_branches = {}
	return map_filter_non_null(
		git_branches,
		--- @return GitBranchEntry
		function(branch)
			local branch_name, remote, is_current_branch = parse_git_branch_line(branch)

			local is_remote_branch = remote ~= nil
			local is_local_branch = not is_remote_branch

			local seen_branch = seen_branches[branch_name]
			if seen_branch then
				seen_branch.is_local_branch = true
				seen_branch.is_remote_branch = true
				seen_branch.remote = remote or seen_branch.remote
				return nil
			end

			local result = {
				branch_name = branch_name,
				remote = remote,
				is_current_branch = is_current_branch,
				is_local_branch = is_local_branch,
				is_remote_branch = is_remote_branch,
			}

			seen_branches[branch_name] = result

			return result
		end
	)
end

function ask_yes_no_confirmation(prompt, cancel_message, on_yes_function)
	vim.ui.input({ prompt = prompt }, function(input)
		local treated_input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

		if treated_input ~= "y" and treated_input ~= "yes" then
			vim.notify(cancel_message, vim.log.levels.WARN)
			return
		end

		on_yes_function()
	end)
end

vim.api.nvim_set_hl(0, "Telescope_CurrentBranch", { fg = "#aaff00" })
vim.api.nvim_set_hl(0, "Telescope_RemoteMarker", { fg = "#ff0000" })
vim.api.nvim_set_hl(0, "Telescope_LocalMarker", { fg = "#00ff00" })

--- @param branch string
function parse_git_branch_line(branch)
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

	return branch_name, remote or nil, is_current_branch
end

M.all_branches = function(opts)
	opts = opts or {}

	local current_user_buffernr = vim.api.nvim_win_get_buf(0)
	local has_set_previewer = false
	local git_branches = get_git_branches_and_parse_them(current_user_buffernr)

	if not git_branches then
		return
	end

	--- @type number
	local previewer_bufnr

	local graph_formats = {
		"%p -%d %s",
		"%cn -%d %s",
		"%cr -%d %s",
		current = 1,
	}

	function get_next_format()
		graph_formats.current = graph_formats.current + 1
		if graph_formats.current > #graph_formats then
			graph_formats.current = 1
		end
		return graph_formats[graph_formats.current]
	end

	function get_current_format()
		return graph_formats[graph_formats.current]
	end

	function make_finder(git_branches_array)
		return finders.new_table({
			results = git_branches_array,
			entry_maker = function(entry)
				--- @type string
				local display
				if entry.is_local_branch and entry.is_remote_branch then
					display = "[L|R] " .. entry.branch_name
				elseif entry.is_local_branch then
					display = "[L|*] " .. entry.branch_name
				elseif entry.is_remote_branch then
					display = "[*|R] " .. entry.branch_name
				end

				return {
					value = entry,
					display = function()
						local highligh_groups = {}
						if entry.is_current_branch then
							table.insert(highligh_groups, { { 6, 1000 }, "Telescope_CurrentBranch" })
						end
						if entry.is_local_branch then
							table.insert(highligh_groups, { { 1, 2 }, "Telescope_LocalMarker" })
						end
						if entry.is_remote_branch then
							table.insert(highligh_groups, { { 3, 4 }, "Telescope_RemoteMarker" })
						end
						return display, highligh_groups
					end,
					ordinal = display,
				}
			end,
		})
	end

	local picker = pickers.new(opts, {
		prompt_title = "Git Branches",
		finder = make_finder(git_branches),
		previewer = previewers.new_buffer_previewer({
			title = "Branches",
			get_buffer_by_name = function()
				return "git_branches"
			end,
			define_preview = function(self, entry)
				local bufnr = self.state.bufnr
				previewer_bufnr = bufnr
				if not has_set_previewer then
					local graph = make_git_graph(current_user_buffernr, get_next_format())
					if not graph then
						return
					end
					vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, graph)
					set_branches_previewer_highlights(bufnr)
					has_set_previewer = true
					-- For some reason, if no wait is provided, the jumo_to_branch function does not work.
					vim.wait(0)
				end
				previewer_jump_to_branch(bufnr, entry)
			end,
		}),
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, mapping)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				print(vim.inspect(selection))
				-- vim.api.nvim_put({ selection[1] }, "", false, true)
			end)

			function refresh_picker()
				local picker = action_state.get_current_picker(prompt_bufnr)
				local new_git_branches = get_git_branches_and_parse_them(current_user_buffernr)
				picker:refresh(make_finder(new_git_branches))
			end

			function refresh_previewer()
				local graph = make_git_graph(current_user_buffernr, get_current_format())
				if not graph then
					return
				end
				vim.api.nvim_buf_set_lines(previewer_bufnr, 0, -1, false, graph)
			end

			function switch_previewer_info()
				get_next_format()
				refresh_picker()
				refresh_previewer()
			end

			function checkout()
				local selection = action_state.get_selected_entry().value
				if git_checkout(current_user_buffernr, selection.branch_name) then
					vim.notify("Checkout to " .. selection.branch_name .. " successful")
				else
					return
				end

				refresh_picker()
			end

			function merge()
				local selection = action_state.get_selected_entry().value

				ask_yes_no_confirmation("Are you sure you want to merge? (y/n)", "Merge canceled", function()
					if not git_merge(current_user_buffernr, selection.branch_name) then
						return
					end

					vim.notify("Merge from " .. selection.branch_name .. " to current branch was successful")

					refresh_previewer()
				end)
			end

			--- @param mode "soft" | "hard"
			function reset(mode)
				function reset_branch()
					local selection = action_state.get_selected_entry().value
					ask_yes_no_confirmation("Are you sure you want to reset? (y/n)", "Reset canceled", function()
						if not git_reset(current_user_buffernr, selection.branch_name, mode) then
							return
						end

						vim.notify(mode .. "reset to " .. selection.branch_name .. " branch was successful")

						refresh_previewer()
					end)
				end
				return reset_branch
			end

			function new_branch()
				vim.ui.input({
					prompt = "Create new branch",
				}, function(input)
					if not input or #input == 0 then
						vim.notify("Canceled branch creation", vim.log.levels.WARN)
						return
					end

					if not git_create_branch(current_user_buffernr, input) then
						return
					end
					vim.notify("Created branch named " .. input)
					refresh_previewer()
					refresh_picker()
				end)
			end

			function delete_branch()
				local selection = action_state.get_selected_entry().value

				ask_yes_no_confirmation(
					[[Are you sure you want to delete branch "]] .. selection.branch_name .. [["? (y/n)]],
					"Deletion canceled",
					function()
						if not git_delete_branch(current_user_buffernr, selection.branch_name) then
							return
						end

						vim.notify([["Successfuly deleted branch "]] .. selection.branch_name .. [[".]])

						refresh_previewer()
						refresh_picker()
					end
				)
			end

			mapping("i", "<C-s>", switch_previewer_info)
			mapping("n", "<C-s>", switch_previewer_info)
			mapping("i", "<C-c>", checkout)
			mapping("n", "<C-c>", checkout)
			mapping("i", "<C-n>", new_branch)
			mapping("n", "<C-n>", new_branch)
			mapping("i", "<C-x>", delete_branch)
			mapping("n", "<C-x>", delete_branch)
			mapping("i", "<C-m>", merge)
			mapping("n", "<C-m>", merge)
			mapping("i", "<C-r>s", reset("soft"))
			mapping("n", "<C-r>s", reset("soft"))
			mapping("i", "<C-r>h", reset("hard"))
			mapping("n", "<C-r>h", reset("hard"))
			return true
		end,
	})

	picker:find()
end

return M
