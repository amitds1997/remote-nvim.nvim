local SSHConfigParser = require("remote-nvim.providers.ssh.ssh_config_parser")
local assert = require("luassert.assert")
local stub = require("luassert.stub")

describe("SSH Config parser should", function()
  ---@type remote-nvim.ssh.SSHConfigParser
  local parser

  before_each(function()
    parser = SSHConfigParser()
  end)

  describe("handle include paths correctly", function()
    local logger_stub
    before_each(function()
      stub(vim, "notify_once")
      logger_stub = stub(parser.logger, "fmt_error")
    end)

    it("when all paths are correct", function()
      local path = "./data/ISSUE-92/CASE-1/config"
      parser:parse_config_file(path, debug.getinfo(1, "S").source:sub(2))
      local parsed_config = parser:get_config()

      assert.is_true(parsed_config["peacock"] ~= nil)
      assert.is_true(parsed_config["panda"] ~= nil)
      assert.is_true(parsed_config["rambo"] ~= nil)
      assert.stub(logger_stub).was_not_called()
    end)

    it("when there might be incorrect paths", function()
      parser:parse_config_file("./data/ISSUE-92/CASE-2/config", debug.getinfo(1, "S").source:sub(2))
      local parsed_config = parser:get_config()

      assert.is_true(parsed_config["panda"] ~= nil)
      assert.is_true(parsed_config["tantrum"] ~= nil)
      assert.stub(logger_stub).was_called()
    end)
  end)

  it("parse sample ssh config file", function()
    local raw_ssh_config = [[
    ControlMaster auto
    ControlPath ~/.ssh/master-%r@%h:%p
    ServerAliveInterval 80

    Host tahoe1
      HostName tahoe1.com
      Compression yes

    Host tahoe2
      HostName tahoe2.com
      ServerAliveInterval 60

    Host *
      IdentityFile ~/.ssh/id_rsa

    Host tahoe?
      User nil
      ForwardAgent true
      ProxyCommand ssh -q gateway -W %h:%p
    ]]

    assert.are.same({
      tahoe1 = {
        parsed_config = {
          Compression = "yes",
          ControlMaster = "auto",
          ControlPath = "~/.ssh/master-%r@%h:%p",
          ForwardAgent = "true",
          HostName = "tahoe1.com",
          IdentityFile = "~/.ssh/id_rsa",
          ProxyCommand = "ssh -q gateway -W %h:%p",
          ServerAliveInterval = "80",
          User = "nil",
        },
        post_process_from_hosts = { "*", "tahoe?" },
        source_file = "LITERAL_STRING",
      },
      tahoe2 = {
        parsed_config = {
          Compression = "yes",
          ControlMaster = "auto",
          ControlPath = "~/.ssh/master-%r@%h:%p",
          ForwardAgent = "true",
          HostName = "tahoe2.com",
          IdentityFile = "~/.ssh/id_rsa",
          ProxyCommand = "ssh -q gateway -W %h:%p",
          ServerAliveInterval = "80",
          User = "nil",
        },
        post_process_from_hosts = { "*", "tahoe?" },
        source_file = "LITERAL_STRING",
      },
    }, parser:parse_config_string(raw_ssh_config):get_config())
  end)

  it("should parse prefix based hosts", function()
    local raw_ssh_config = [[
    Host www.cyj.me
          ServerAliveInterval 60
          ServerAliveCountMax 2

      Host www
        User matthew
        CanonicalizeHostName yes
        CanonicalDomains cyj.notfound cyj.me
    ]]

    assert.are.same({
      www = {
        parsed_config = {
          CanonicalDomains = "cyj.notfound cyj.me",
          CanonicalizeHostName = "yes",
          ServerAliveCountMax = "2",
          ServerAliveInterval = "60",
          User = "matthew",
        },
        post_process_from_hosts = { "www.cyj.me" },
        source_file = "LITERAL_STRING",
      },
      ["www.cyj.me"] = {
        parsed_config = {
          ServerAliveCountMax = "2",
          ServerAliveInterval = "60",
        },
        post_process_from_hosts = {},
        source_file = "LITERAL_STRING",
      },
    }, parser:parse_config_string(raw_ssh_config):get_config())
  end)

  it("ignores Match directive", function()
    local raw_ssh_config = [[
    Host MACHINE-1075
      User service
      HostName 10.0.100.75

    Match User service
      IdentityFile ~/.ssh/service_user

    Host XXX
     HostName XXX.YYY.com
     User my_username
     Compression yes
     Ciphers arcfour,blowfish-cbc
     Protocol 2
     ControlMaster auto
     ControlPath ~/.ssh/%r@%h:%p
     IdentityFile ~/.ssh/YYY/id_rsa
    ]]

    assert.are.same({
      ["MACHINE-1075"] = {
        parsed_config = {
          HostName = "10.0.100.75",
          User = "service",
        },
        post_process_from_hosts = {},
        source_file = "LITERAL_STRING",
      },
      XXX = {
        parsed_config = {
          Ciphers = "arcfour,blowfish-cbc",
          Compression = "yes",
          ControlMaster = "auto",
          ControlPath = "~/.ssh/%r@%h:%p",
          HostName = "XXX.YYY.com",
          IdentityFile = "~/.ssh/YYY/id_rsa",
          Protocol = "2",
          User = "my_username",
        },
        post_process_from_hosts = {},
        source_file = "LITERAL_STRING",
      },
    }, parser:parse_config_string(raw_ssh_config):get_config())
  end)

  it("handles multiple hosts in a single Host key", function()
    local raw_ssh_config = [[
    Host MACHINE-1075 MACHINE-1076 MACHINE-1077
      User service
      HostName 10.0.100.75
    ]]

    assert.are.same({
      ["MACHINE-1075"] = {
        parsed_config = {
          HostName = "10.0.100.75",
          User = "service",
        },
        post_process_from_hosts = {},
        source_file = "LITERAL_STRING",
      },
      ["MACHINE-1076"] = {
        parsed_config = {
          HostName = "10.0.100.75",
          User = "service",
        },
        post_process_from_hosts = {},
        source_file = "LITERAL_STRING",
      },
      ["MACHINE-1077"] = {
        parsed_config = {
          HostName = "10.0.100.75",
          User = "service",
        },
        post_process_from_hosts = {},
        source_file = "LITERAL_STRING",
      },
    }, parser:parse_config_string(raw_ssh_config):get_config())
  end)

  it("correctly set config from global variables", function()
    local raw_ssh_config = [[
        ControlMaster auto
    ControlPath ~/.ssh/master-%r@%h:%p
    ServerAliveInterval 80

    Host tahoe1
      HostName tahoe1.com
      Compression yes
      ]]

    assert.are.same({
      tahoe1 = {
        parsed_config = {
          Compression = "yes",
          ControlMaster = "auto",
          ControlPath = "~/.ssh/master-%r@%h:%p",
          HostName = "tahoe1.com",
          ServerAliveInterval = "80",
        },
        post_process_from_hosts = {},
        source_file = "LITERAL_STRING",
      },
    }, parser:parse_config_string(raw_ssh_config):get_config())
  end)
end)
