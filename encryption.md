# Encryption
The plugin saves the state of your terminal in written files. As the state can contain information such as output of shells and other potentially secret information, then it is recommended to encrypt the state files.

The plugin provides by default a way to encrypt using [age](https://github.com/FiloSottile/age), but if you wish to change it, then this document will guide you.

If you wish to share a non-documented way of encrypting your files, then please make a PR or file an issue.
## Changing the encryption provider
It is recommended to use [wezterm.run_child_process](https://wezfurlong.org/wezterm/config/lua/wezterm/run_child_process.html) like how it is done in the default `age` implementation below:
```lua
local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

local function execute_shell_cmd(cmd)
	local process_args = is_windows and { "cmd.exe", "/C", cmd } or { os.getenv("SHELL"), "-c", cmd }
	local success, stdout, stderr = wezterm.run_child_process(process_args)
	return success, stdout, stderr
end


resurrect.set_encryption({
  enable = true,
  private_key = "/path/to/private/key.txt",
  public_key = "public_key",
	encrypt = function(file_path, lines)
		local success, _, stderr = execute_shell_cmd(
			string.format(
				"echo %s | age -r %s -o %s",
				wezterm.shell_quote_arg(lines),
				pub.encryption.public_key,
				file_path:gsub(" ", "\\ ")
			)
		)
		if not success then
			wezterm.log_error(stderr)
		end
	end,
	decrypt = function(file_path)
		local success, stdout, stderr =
			execute_shell_cmd(string.format('age -d -i "%s" "%s"', pub.encryption.private_key, file_path))
		if not success then
			wezterm.log_error(stderr)
		else
			return stdout
		end
	end,
})
```
