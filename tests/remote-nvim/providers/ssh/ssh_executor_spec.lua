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

  local executor
  local other_executor
  before_each(function()
    executor = SSHExecutor(host, conn_opts)
    executor._ssh_prompts = prompts
    stub(executor, "run_executor_job")

    other_executor = SSHExecutor(host, other_conn_opts)
    stub(other_executor, "run_executor_job")
  end)

  it("should correctly set the scp connection options", function()
    -- Appends recursive flag to scp options
    assert.equals("-r", executor.scp_conn_opts)

    -- Corrects port option even if other conn opts are present
    assert.equals("-P 2310 -r", other_executor.scp_conn_opts)
  end)

  it("should run upload job with correct arguments", function()
    executor:upload("local-path", "remote-path")
    local scp_command = "scp -r local-path remote-host:remote-path"
    assert.stub(executor.run_executor_job).was.called_with(executor, scp_command, nil)

    other_executor:upload("local-path", "remote-path")
    local other_scp_command = "scp -P 2310 -r local-path remote-host:remote-path"
    assert.stub(other_executor.run_executor_job).was.called_with(other_executor, other_scp_command, nil)
  end)

  it("should run download job with correct arguments", function()
    executor:download("remote-path", "local-path")
    local scp_command = "scp -r remote-host:remote-path local-path"
    assert.stub(executor.run_executor_job).was.called_with(executor, scp_command, nil)

    other_executor:download("remote-path", "local-path")
    local other_scp_command = "scp -P 2310 -r remote-host:remote-path local-path"
    assert.stub(other_executor.run_executor_job).was.called_with(other_executor, other_scp_command, nil)
  end)

  it("should correctly run command job with correct arguments", function()
    -- Simple command works
    executor:run_command("uname")
    local ssh_command = "ssh remote-host 'uname'"
    assert.stub(executor.run_executor_job).was.called_with(executor, ssh_command, nil)

    -- Shell escaping works
    executor:run_command("echo '12'")
    ssh_command = [[ssh remote-host 'echo '\''12'\''']]
    assert.stub(executor.run_executor_job).was.called_with(executor, ssh_command, nil)
  end)

  it("should parse job output correctly to handle prompts", function()
    local pp = stub(executor, "_process_prompt")

    -- Match in a single call is parsed correctly
    executor:process_stdout({ "pass", "word:" })
    assert.stub(pp).was.called_with(executor, prompts[1])
    executor:reset()
    pp:clear()

    -- Partial matches over multiple calls are passed correctly
    executor:process_stdout({ "p" })
    assert.stub(pp).was_not.called_with(executor, prompts[1])
    executor:process_stdout({ "assword:" })
    assert.stub(pp).was.called_with(executor, prompts[1])
    executor:reset()
    pp:clear()

    -- Special characters are handled correctly
    executor:process_stdout({ "continue connecting (yes/no/[fingerprint])?" })
    assert.stub(pp).was.called_with(executor, prompts[2])
  end)

  it("should given a prompt handle it correctly", function()
    local pi = stub(require("remote-nvim.providers.ssh.ssh_utils"), "get_user_input")
    pi.returns("test")
    local chan_send = stub(vim.api, "nvim_chan_send")

    -- For a static prompt, gather input, cache value and send it back to the job
    executor:_process_prompt(prompts[1])
    assert.stub(pi).was.called_with(prompts[1].input_prompt, prompts[1].type)
    assert.equals(executor._job_prompt_responses[prompts[1].match], "test")
    assert.stub(chan_send).was.called_with(executor._job_id, "test\n")
    executor:reset()
    pi:clear()
    chan_send:clear()

    -- For dynamic prompt, gather input, send it back to the job without caching it
    executor:_process_prompt(prompts[2])
    assert.stub(pi).was.called_with(prompts[2].input_prompt, prompts[2].type)
    assert.not_equals(executor._job_prompt_responses[prompts[2].match], "test")
    assert.stub(chan_send).was.called_with(executor._job_id, "test\n")
  end)

  it("should save cached values as responses for static prompts on job success", function()
    local pi = stub(require("remote-nvim.providers.ssh.ssh_utils"), "get_user_input")
    pi.returns("test")
    stub(vim.api, "nvim_chan_send")

    -- On job failure, the value is not saved
    executor:process_stdout({ prompts[1].match })
    executor:process_job_completion(127)
    assert.equals(executor._job_prompt_responses[prompts[1].match], "test")
    assert.not_equals(executor._ssh_prompts[1].value, executor._job_prompt_responses[prompts[1].match])
    executor:reset()
    pi:clear()

    -- On job success, the value is saved
    executor:process_stdout({ prompts[1].match })
    executor:process_job_completion(0)
    assert.equals(executor._job_prompt_responses[prompts[1].match], "test")
    assert.equals(executor._ssh_prompts[1].value, executor._job_prompt_responses[prompts[1].match])
  end)
end)
