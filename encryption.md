# Encryption
The plugin saves the state of your terminal in written files. As the state can contain information such as output of shells and other potentially secret information, then it is recommended to encrypt the state files.

The plugin provides by default a way to encrypt using [age](https://github.com/FiloSottile/age), but if you wish to change it, then this document will guide you.

> [!IMPORTANT]  
> There is currently a problem with encrypting large states on Windows, see [#32](https://github.com/MLFlexer/resurrect.wezterm/issues/32).

If you wish to share a non-documented way of encrypting your files, then please make a PR or file an issue.
## Changing the encryption provider
It is recommended to use [wezterm.run_child_process](https://wezfurlong.org/wezterm/config/lua/wezterm/run_child_process.html) like how it is done in the default `age` implementation below:
```lua
local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

---executes cmd and passes input to stdin
---@param cmd string command to be run
---@param input string input to stdin
---@return boolean
---@return string
local function execute_cmd_with_stdin(cmd, input)
	if is_windows and #input < 32000 then -- Check if input is larger than max cmd length on Windows
		input = input:gsub("\\", "\\\\"):gsub('"', '`"'):gsub("\n", "`n"):gsub("\r", "`r")
		cmd = string.format('Write-Output -NoEnumerate "%s" | %s', input, cmd)
		local process_args = { "pwsh.exe", "-NoProfile", "-Command", cmd }

		local success, stdout, stderr = wezterm.run_child_process(process_args)
		if success then
			return success, stdout
		else
			return success, stderr
		end
	elseif #input < 261000 and not is_windows then -- Check if input is larger than common max on MacOS and Linux
		cmd = string.format("printf '%s' | %s", input, cmd)
		local process_args = { os.getenv("SHELL"), "-c", cmd }

		local success, stdout, stderr = wezterm.run_child_process(process_args)
		if success then
			return success, stdout
		else
			return success, stderr
		end
	else
		local stdin = io.popen(cmd, "w")
		if not stdin then
			return false, "Failed to execute: " .. cmd
		end
		stdin:write(input)
		stdin:flush()
		stdin:close()
		return true, '"' .. cmd .. '" <input> ran successfully.'
	end
end

local public_key = "public_key"
local private_key = "/path/to/private/key.txt"

resurrect.set_encryption({
  enable = true,
  private_key = private_key,
  public_key = public_key,
	encrypt = function(file_path, lines)
		local cmd = string.format("age -r %s -o %s", public_key, file_path:gsub(" ", "\\ "))
		local success, output = execute_cmd_with_stdin(cmd, lines)

		if not success then
			wezterm.log_error("Encryption failed: " .. output)
			return
		end
	end,
	decrypt = function(file_path)
		local success, stdout, stderr =
			wezterm.run_child_process({ "age", "-d", "-i", private_key, file_path })
		if not success then
			wezterm.log_error("Decryption failed: " .. stderr)
			return
		end
		if is_windows then
			stdout = stdout:gsub('`"', '"'):gsub("\\\\", "\\"):gsub("`n", "\n"):gsub("`r", "\r")
		end
		return stdout
	end,
})
```

# Providers
If you think something is missing, then please provide a PR or an issue.

## Rage
[Rage](https://github.com/str4d/rage) is a drop in replacement for age and can be used by installing it to the path, and then replace `age` by `rage` in the example in the [Changing the encryption provider section](#changing-the-encryption-provider)

## GPG
[GnuPG](https://gnupg.org/) can be used by installing it to the path.
Then generating a key pair: `gpg --full-generate-key`
Get the public key with `gpg --armor --export your_email@example.com`

Your commands to replace the `age` commands in the section [Changing the encryption provider section](#changing-the-encryption-provider), should then be something like the following:
```lua
local encryption_cmd = string.format(
    "echo %s | gpg --batch --yes --encrypt --recipient %s --output %s",
    wezterm.shell_quote_arg(lines),
    public_key,
    file_path:gsub(" ", "\\ ")
  )
local decryption_cmd = string.format('gpg --batch --yes --decrypt "%s"', file_path)
```
