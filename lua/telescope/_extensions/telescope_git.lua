return require("telescope").register_extension({
	setup = function(ext_config, config)
		-- access extension config and user config
	end,
	exports = {
		all_branches = require("telescope_git").all_branches,
	},
})
