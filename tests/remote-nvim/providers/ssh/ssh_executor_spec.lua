local assert = require("luassert.assert")
local stub = require("luassert.stub")

describe("SSH Executor", function()
  local SSHExecutor = require("remote-nvim.providers.ssh.ssh_executor")
  local host = "remote-host"
  local conn_opts = ""
  local other_conn_opts = "-p 2310"
  local prompts = {
    {
      match = "password:",
      type = "secret",
      input_prompt = "Enter password: ",
      value_type = "static",
      value = "",
    },
    {
      match = "continue connecting (yes/no/[fingerprint])?",
      type = "plain",
      input_prompt = "Do you want to continue connection (yes/no)? ",
      value_type = "dynamic",
      value = "",
    },
  }

  local executor, other_executor, executor_run_job_stub, other_executor_run_job_stub
  before_each(function()
    executor = SSHExecutor(host, conn_opts)
    executor._ssh_prompts = prompts
    executor_run_job_stub = stub(executor, "run_executor_job")

    other_executor = SSHExecutor(host, other_conn_opts)
    other_executor_run_job_stub = stub(other_executor, "run_executor_job")
  end)

  describe("should correctly generate scp connection options", function()
    it("and append recursive flag mandatorily", function()
      assert.equals("-r", executor.scp_conn_opts)
    end)

    it("by correcting port option if passed", function()
      assert.equals("-P 2310 -r", other_executor.scp_conn_opts)
    end)
  end)

  describe("should run upload job with correct arguments", function()
    it("for default port SCP", function()
      executor:upload("local-path", "remote-path")
      local scp_command = "scp -r local-path remote-host:remote-path"
      assert.stub(executor_run_job_stub).was.called_with(executor, scp_command, { exit_cb = nil })
    end)

    it("for specified port SCP", function()
      other_executor:upload("local-path", "remote-path")
      local other_scp_command = "scp -P 2310 -r local-path remote-host:remote-path"
      assert.stub(other_executor_run_job_stub).was.called_with(other_executor, other_scp_command, { exit_cb = nil })
    end)
  end)

  describe("should run download job with correct arguments", function()
    it("for default port SCP", function()
      executor:download("remote-path", "local-path")
      local scp_command = "scp -r remote-host:remote-path local-path"
      assert.stub(executor_run_job_stub).was.called_with(executor, scp_command, { exit_cb = nil })
    end)

    it("for specified port SCP", function()
      other_executor:download("remote-path", "local-path")
      local other_scp_command = "scp -P 2310 -r remote-host:remote-path local-path"
      assert.stub(other_executor_run_job_stub).was.called_with(other_executor, other_scp_command, { exit_cb = nil })
    end)
  end)

  describe("should correctly run command job with correct arguments", function()
    it("for simple commands", function()
      executor:run_command("uname")
      local ssh_command = "ssh remote-host 'uname'"
      assert.stub(executor_run_job_stub).was.called_with(executor, ssh_command, { exit_cb = nil })
    end)

    it("for commands that require shell escaping", function()
      executor:run_command("echo '12'")
      local ssh_command = [[ssh remote-host 'echo '\''12'\''']]
      assert.stub(executor_run_job_stub).was.called_with(executor, ssh_command, { exit_cb = nil })
    end)
  end)

  describe("should parse job output correctly to handle prompts", function()
    local pp

    before_each(function()
      pp = stub(executor, "_process_prompt")
      executor:reset()
    end)

    it("when prompt match is passed in a single call", function()
      executor:process_stdout({ "pass", "word:" })
      assert.stub(pp).was.called_with(executor, prompts[1])
    end)

    it("when prompt match is passed over multiple calls", function()
      executor:process_stdout({ "p" })
      assert.stub(pp).was_not.called_with(executor, prompts[1])
      executor:process_stdout({ "assword:" })
      assert.stub(pp).was.called_with(executor, prompts[1])
    end)

    it("when prompt match contains special characters", function()
      executor:process_stdout({ "continue connecting (yes/no/[fingerprint])?" })
      assert.stub(pp).was.called_with(executor, prompts[2])
    end)
  end)

  describe("should correctly handle prompt", function()
    local pi = stub(require("remote-nvim.providers.utils"), "get_input")
    pi.returns("test")
    local chan_send = stub(vim.api, "nvim_chan_send")

    before_each(function()
      executor:reset()
      pi:clear()
      chan_send:clear()
    end)

    it("of static type", function()
      executor:_process_prompt(prompts[1])
      assert.stub(pi).was.called_with(prompts[1].input_prompt, prompts[1].type)
      assert.equals(executor._job_prompt_responses[prompts[1].match], "test")
      assert.stub(chan_send).was.called_with(executor._job_id, "test\n")
    end)

    it("of type dynamic", function()
      executor:_process_prompt(prompts[2])
      assert.stub(pi).was.called_with(prompts[2].input_prompt, prompts[2].type)
      assert.not_equals(executor._job_prompt_responses[prompts[2].match], "test")
      assert.stub(chan_send).was.called_with(executor._job_id, "test\n")
    end)
  end)

  describe("should correctly handle cached values", function()
    local pi = stub(require("remote-nvim.providers.utils"), "get_input")
    pi.returns("test")
    stub(vim.api, "nvim_chan_send")

    before_each(function()
      executor = SSHExecutor(host, conn_opts)
      pi:clear()
    end)

    it("on job success", function()
      executor:process_stdout({ prompts[1].match })
      executor:process_job_completion(0)
      assert.equals(executor._job_prompt_responses[prompts[1].match], "test")
      assert.equals(executor._ssh_prompts[1].value, executor._job_prompt_responses[prompts[1].match])
    end)

    it("on job failure", function()
      executor:process_stdout({ prompts[1].match })
      executor:process_job_completion(127)
      assert.equals(executor._job_prompt_responses[prompts[1].match], "test")
      assert.not_equals(executor._ssh_prompts[1].value, executor._job_prompt_responses[prompts[1].match])
    end)
  end)
end)
