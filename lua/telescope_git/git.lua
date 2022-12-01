local Job = require("plenary.job")

local M = {}

function sync_job_with_error_notify(job)
	local result, code = job:sync()

	if code ~= 0 then
		vim.notify(table.concat(job:stderr_result(), "\n"), "error")
		return nil
	end

	return result
end

M.make_graph =
	--- @param current_user_buffernr number
	--- @param format_type string
	--- @return string[] | nil
	function(current_user_buffernr, format_type)
		local job = Job:new({
			command = "git",
			args = { "log", "--graph", "--all", "--decorate", "--format=format: " .. format_type },
			cwd = get_cwd_of_bufnr(current_user_buffernr),
		})

		return sync_job_with_error_notify(job)
	end

M.get_branches =
	--- @param current_user_buffernr number
	--- @return string[] | nil
	function(current_user_buffernr)
		local job = Job:new({
			command = "git",
			args = { "branch", "--all" },
			cwd = get_cwd_of_bufnr(current_user_buffernr),
		})

		return sync_job_with_error_notify(job)
	end

M.checkout =
	--- @param current_user_buffernr number
	--- @param branch_name number
	--- @return boolean
	function(current_user_buffernr, branch_name)
		local job = Job:new({
			command = "git",
			args = { "checkout", branch_name },
			cwd = get_cwd_of_bufnr(current_user_buffernr),
		})

		return sync_job_with_error_notify(job) ~= nil
	end

M.merge =
	--- @param current_user_buffernr number
	--- @param branch_name number
	--- @return boolean
	function(current_user_buffernr, branch_name)
		local job = Job:new({
			command = "git",
			args = { "merge", branch_name },
			cwd = get_cwd_of_bufnr(current_user_buffernr),
		})

		return sync_job_with_error_notify(job) ~= nil
	end

M.reset =
	--- @param current_user_buffernr number
	--- @param branch_name number
	--- @param mode "soft" | "hard"
	--- @return boolean
	function(current_user_buffernr, branch_name, mode)
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

M.create_branch =
	--- @param branch_name number
	--- @param current_user_buffernr number
	--- @return boolean
	function(current_user_buffernr, branch_name)
		local job = Job:new({
			command = "git",
			args = { "branch", branch_name },
			cwd = get_cwd_of_bufnr(current_user_buffernr),
		})

		return sync_job_with_error_notify(job) ~= nil
	end

M.fetch =
	--- @param current_user_buffernr number
	--- @return boolean
	function(current_user_buffernr)
		local job = Job:new({
			command = "git",
			args = { "fetch", "--prune" },
			cwd = get_cwd_of_bufnr(current_user_buffernr),
		})

		return sync_job_with_error_notify(job) ~= nil
	end

M.delete_branch =
	--- @param branch_name number
	--- @param current_user_buffernr number
	--- @return boolean
	function(current_user_buffernr, branch_name)
		local job = Job:new({
			command = "git",
			args = { "branch", "--delete", branch_name },
			cwd = get_cwd_of_bufnr(current_user_buffernr),
		})

		return sync_job_with_error_notify(job) ~= nil
	end

return M
