---@alias remote-nvim.ssh.ParsedHostConfig table<string, string>

---@class remote-nvim.ssh.SSHConfigHost
---@field source_file string Path to the SSH config file
---@field post_process_from_hosts string[] List of existing hosts that match with the current host pattern
---@field parsed_config remote-nvim.ssh.ParsedHostConfig Parsed key-value config

---@class remote-nvim.ssh.SSHConfigParser
---@field global_options remote-nvim.ssh.ParsedHostConfig
---@field config table<string, remote-nvim.ssh.SSHConfigHost>
local SSHConfigParser = require("remote-nvim.middleclass")("SSHConfigParser")
local ssh_utils = require("remote-nvim.providers.ssh.ssh_utils")

--- This is a best effort parsing since we are mostly just interested in getting the hostnames and close-to-accurate
--- configuration details. If we want to build a full on SSH config parser, we would need to put more efforts into
--- making this closer to spec and not allowing invalid attributes. We don't need one, so we won't build one.

function SSHConfigParser:init()
  self.global_options = {}
  self.config = {}
  self.current_hosts = nil
  self.known_hosts = {}
  self.in_match_block = false
end

---Process an SSH config directive
---@param key string Directive key
---@param value string Directive value
---@param source_file string Source of the directive
function SSHConfigParser:process_directive(key, value, source_file)
  if key == "Host" then -- Handle Host directive
    self.current_hosts = vim.split(value, "%s+")
    self.in_match_block = false

    for _, current_host in ipairs(self.current_hosts) do
      local apply_chain = { self.global_options }
      local post_process_hosts = {}
      for _, known_host in ipairs(self.known_hosts) do
        if ssh_utils.matches_host_name_pattern(current_host, known_host) then
          table.insert(apply_chain, (self.config[known_host] or {}).parsed_config or {})
          table.insert(post_process_hosts, known_host)
        end

        if ssh_utils.matches_host_name_pattern(known_host, current_host) and self.config[known_host] ~= nil then
          table.insert(self.config[known_host].post_process_from_hosts, current_host)
        end
      end
      table.insert(self.known_hosts, current_host)

      self.config[current_host] = {
        source_file = source_file,
        post_process_from_hosts = post_process_hosts,
        parsed_config = vim.tbl_extend(
          "keep",
          (self.config[current_host] or {}).parsed_config or {},
          unpack(apply_chain)
        ),
      }
    end
  elseif key == "Match" then
    self.in_match_block = true
  elseif key == "Include" then -- Handle Include clause
    self.in_match_block = false
    self:parse_config_file(value)
  elseif self.current_hosts == nil then -- Handle global options
    self.global_options[key] = value
  else
    if not self.in_match_block then
      for _, current_host in ipairs(self.current_hosts) do
        self.config[current_host].parsed_config[key] = self.config[current_host].parsed_config[key] or value
      end
    end
  end

  --- Before changing current_host, let's post process everything we have so far
  self:_post_process_all_configs()
end

---@private
---@param line string? Line to be processed
---@param source string Source of the line
function SSHConfigParser:_process_line(line, source)
  local directive, directive_value = ssh_utils.process_line(line)

  if directive_value ~= nil and directive ~= nil then
    self:process_directive(directive, directive_value, source)
  end
end

---@param raw_string string Raw string containing SSH config
---@return remote-nvim.ssh.SSHConfigParser parser Returns the parser back
function SSHConfigParser:parse_config_string(raw_string)
  local lines = vim.split(raw_string, "\n", { plain = true })

  for _, line in ipairs(lines) do
    self:_process_line(line, "LITERAL_STRING")
  end
  self:_post_process_all_configs()

  return self
end

---@private
function SSHConfigParser:_post_process_all_configs()
  -- Update each configuration with its matching hosts configuration
  local config
  for _, host_name in ipairs(self.known_hosts) do
    config = self.config[host_name]
    for _, matched_host in ipairs(config.post_process_from_hosts) do
      self.config[host_name].parsed_config =
        vim.tbl_extend("keep", self.config[host_name].parsed_config, self.config[matched_host].parsed_config)
    end
  end
end

---@param file_path string SSH config file path
---@return remote-nvim.ssh.SSHConfigParser parser Returns the parser back
function SSHConfigParser:parse_config_file(file_path)
  file_path = vim.fn.expand(file_path)

  for line in io.lines(file_path) do
    self:_process_line(line, file_path)
  end
  self:_post_process_all_configs()

  return self
end

---@return table<string, remote-nvim.ssh.SSHConfigHost>
function SSHConfigParser:get_config()
  local config = {}

  for host_name, ssh_config in pairs(self.config) do
    if not ssh_utils.hostname_contains_wildcard(host_name) then
      config[host_name] = ssh_config
    end
  end

  return config
end

return SSHConfigParser
