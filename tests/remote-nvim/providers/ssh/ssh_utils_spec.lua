local assert = require("luassert.assert")
local utils = require("remote-nvim.providers.ssh.ssh_utils")

describe("Hostnames should be correctly adjusted for patterns", function()
  it("with * wildcard", function()
    assert.equals(".*github.com", utils.adjust_hostname_to_pattern("*github.com"))
    assert.equals(".*github.*com", utils.adjust_hostname_to_pattern("*github.*com"))
  end)

  it("with ? wildcard", function()
    assert.equals(".?github.com", utils.adjust_hostname_to_pattern("?github.com"))
    assert.equals(".?.?github.?com", utils.adjust_hostname_to_pattern("??github.?com"))
  end)

  it("when no wildcards are present", function()
    assert.equals("github..com", utils.adjust_hostname_to_pattern("github..com"))
  end)
end)

it("Hostnames containing wildcards are correctly detected", function()
  assert.is_true(utils.hostname_contains_wildcard("github?com"))
  assert.is_true(utils.hostname_contains_wildcard("!github.com"))
  assert.is_true(utils.hostname_contains_wildcard("github*com"))
  assert.is_true(utils.hostname_contains_wildcard("gith?b*com"))
  assert.is_false(utils.hostname_contains_wildcard("github.com"))
end)

it("Host name matches pattern is correctly determined", function()
  assert.is_true(utils.matches_host_name_pattern("tahoe1", "tahoe?"))
  assert.is_true(utils.matches_host_name_pattern("tahoe1", "*"))
  assert.is_false(utils.matches_host_name_pattern("tahoe1", "!tahoe?"))
  assert.is_true(utils.matches_host_name_pattern("tahoe1", "tah*"))
  assert.is_false(utils.matches_host_name_pattern("tahoe1", "!*"))
  assert.is_true(utils.matches_host_name_pattern("www", "www.github.com"))
  assert.is_false(utils.matches_host_name_pattern("www.github.com", "www"))
end)

describe("SSH config line is correctly processed", function()
  local directive, value
  before_each(function()
    directive = nil
    value = nil
  end)

  it("when there are a lot of spaces", function()
    directive, value = utils.process_line("     Host      magic      ")
    assert.equals("Host", directive)
    assert.equals("magic", value)
  end)

  it("when line is nil or empty", function()
    directive, value = utils.process_line(nil)
    assert.is_nil(directive)
    assert.is_nil(value)

    directive, value = utils.process_line("")
    assert.is_nil(directive)
    assert.is_nil(value)
  end)

  it("when line is just a comment", function()
    directive, value = utils.process_line("# This is a comment")
    assert.is_nil(directive)
    assert.is_nil(value)
  end)

  it("when line contains comment", function()
    directive, value = utils.process_line("Host ma?qa*# This is a comment")
    assert.equals("Host", directive)
    assert.equals("ma?qa*", value)
  end)
end)
