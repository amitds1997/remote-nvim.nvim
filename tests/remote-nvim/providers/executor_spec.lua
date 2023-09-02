local spy = require("luassert.spy")

describe("Base executor", function()
  local Executor = require("remote-nvim.providers.executor")
  local succ_job_command = "echo SUCCESS"
  local failing_job_command = "ehco FAILURE"

  local base_executor
  before_each(function()
    base_executor = Executor("example-host", "")
    base_executor.upload = function(...) end
    base_executor.download = function(...) end
    base_executor.run_command = function(...) end
  end)

  it("should fail if job status is called before running job", function()
    assert.error_matches(function()
      base_executor:last_job_status()
    end, "No jobs running")
  end)

  it("should call the specified callback on job completion", function()
    local cb = spy.new(function() end)
    base_executor:run_executor_job(succ_job_command, cb)
    assert.spy(cb).was_called()
  end)

  it("should return correct exit code", function()
    base_executor:run_executor_job(succ_job_command)
    assert.equals(0, base_executor:last_job_status())

    base_executor:run_executor_job(failing_job_command)
    assert.equals(127, base_executor:last_job_status())
  end)

  it("should fail if no job is running and cancel gets called", function()
    assert.error_matches(function()
      base_executor:cancel_running_job()
    end, "No running job to be cancelled")
  end)

  it("should cancel running job correctly", function()
    local co = coroutine.create(function()
      base_executor:run_executor_job("sleep 10")
    end)
    coroutine.resume(co)
    assert.equals(1, base_executor:cancel_running_job())
  end)

  it("should generate the correct output", function()
    base_executor:run_executor_job(succ_job_command)
    assert.equals("SUCCESS", table.concat(base_executor:job_stdout(), ""))
  end)

  it("should have the correct number of output lines", function()
    base_executor:run_executor_job("echo '1\n2\n3\n4'")
    assert.equals(4, #base_executor:job_stdout())

    -- In case there are additional new lines at end, we trim them
    base_executor:run_executor_job("echo '1\n2\n3\n4\n\n'")
    assert.equals(4, #base_executor:job_stdout())

    -- If there are multiple new lines in the middle, they are not counted in line count
    base_executor:run_executor_job("echo '1\n2\n\n3\n4\n'")
    assert.equals(5, #base_executor:job_stdout())
  end)
end)
