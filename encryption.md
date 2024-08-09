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
	local process_args = is_windows and { "pwsh.exe", "-NoProfile", "-NoLogo", "-Command", cmd } or
		{ os.getenv("SHELL"), "-c", cmd }
	local success, stdout, stderr = wezterm.run_child_process(process_args)
	return success, stdout, stderr
end

local public_key = "public_key"
local private_key = "/path/to/private/key.txt"

resurrect.set_encryption({
  enable = true,
  private_key = private_key,
  public_key = public_key,
	encrypt = function(file_path, lines)
		wezterm.emit("resurrect.encrypt.start", file_path)
		local cmd = string.format('age -r %s -o "%s"', public_key, file_path)

		if is_windows then
			lines = lines:gsub("\\", "\\\\"):gsub('"', '`"'):gsub("\n", "`n"):gsub("\r", "`r")
		end

		local ok, err = pcall(function()
			local stdin = io.popen(cmd, "w")
			if not stdin then
				wezterm.emit("resurrect.error", "resurrect.encrypt could not open command: " .. cmd)
				wezterm.log_error("Could not open command: " .. cmd)
				return
			end
			stdin:write(lines)
			stdin:close()
		end)
		if not ok then
			wezterm.emit("resurrect.error", "resurrect.encrypt: " .. tostring(err))
			wezterm.log_error("Encryption failed: " .. tostring(err))
		end

		wezterm.emit("resurrect.encrypt.finished", file_path)
		return ok
	end,
	decrypt = function(file_path)
		wezterm.emit("resurrect.decrypt.start", file_path)
		local cmd = string.format('age -d -i "%s" "%s"', pub.encryption.private_key, file_path)

		local success, stdout, stderr = execute_shell_cmd(cmd)
		if not success then
			wezterm.emit("resurrect.error", "resurrect.decrypt: " .. tostring(stderr))
			wezterm.log_error("Decryption failed: " .. tostring(stderr))
			return nil
		end
		if is_windows then
			stdout = stdout:gsub('`"', '"'):gsub("\\\\", "\\"):gsub("`n", "\n"):gsub("`r", "\r")
		end
		wezterm.emit("resurrect.decrypt.finished", file_path)
		return stdout
	end
})
```

# Providers
If you think something is missing, then please provide a PR or an issue.

## Rage
[Rage](https://github.com/str4d/rage) is a drop in replacement for age and can be used by installing it to the path, and then using the code from [Changing the encryption provider](#changing-the-encryption-provider), modifying:

```lua
-- encryption function
local cmd = string.format('rage -r %s -o "%s"', public_key, file_path:gsub(" ", "\\ "))
-- decryption function
local cmd = string.format('rage -d -i "%s" "%s"', private_key, file_path)
```
## GPG
[GnuPG](https://gnupg.org/) can be used by installing it to the path.
Then generating a key pair: `gpg --full-generate-key`
Get the public key with `gpg --armor --export your_email@example.com`

Modify the code from [Changing the encryption provider](#changing-the-encryption-provider) with:
```lua
local public_key = "your_email@example.com"

-- encryption function
local cmd = string.format('gpg --batch --yes --encrypt --recipient %s --output "%s"', public_key, file_path:gsub(" ", "\\ "))
-- decryption function
local cmd = string.format('gpg --batch --yes --decrypt "%s"', file_path)
```
