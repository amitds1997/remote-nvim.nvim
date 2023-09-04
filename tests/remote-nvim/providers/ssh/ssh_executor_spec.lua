local stub = require("luassert.stub")

describe("SSH Executor", function()
  local SSHExecutor = require("remote-nvim.providers.ssh.ssh_executor")
  local host = "remote-host"
  local conn_opts = ""
  local other_conn_opts = "-p 2310"

  local executor
  local other_executor
  before_each(function()
    executor = SSHExecutor(host, conn_opts)
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
end)
