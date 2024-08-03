# Encryption
The plugin saves the state of your terminal in written files. As the state can contain information such as output of shells and other potentially secret information, then it is recommended to encrypt the state files.

The plugin provides by default a way to encrypt using [age](https://github.com/FiloSottile/age), but if you wish to change it, then this document will guide you.

If you wish to share a non-documented way of encrypting your files, then please make a PR or file an issue.
## Changing the encryption provider
It is recommended to use [wezterm.run_child_process]()
```lua
local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
resurrect.encryption.encrypt = function(file_path, lines)
  local args = {
    "sh",
    "-c",

    "echo "
      .. wezterm.shell_quote_arg(lines)
      .. " | "
      .. "age "
      .. "-r "
      .. pub.encryption.public_key
      .. " -o "
      .. file_path,
  }

  local success, stdout, stderr = wezterm.run_child_process(args)
  if not success then
    wezterm.log_error(stderr)
  end
end,
resurrect.encryption.decrypt = function(file_path)
  local args = { "age", "-d", "-i", pub.encryption.private_key, file_path }
  local success, stdout, stderr = wezterm.run_child_process(args)
  if not success then
    wezterm.log_error(stderr)
  else
    return stdout
  end
end,
```
