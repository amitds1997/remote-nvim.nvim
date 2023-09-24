local assert = require("luassert")
local spy = require("luassert.spy")
local stub = require("luassert.stub")

describe("Base executor", function()
  local Executor = require("remote-nvim.providers.executor")
  local succ_job_command = "echo SUCCESS"
  local failing_job_command = "ehco FAILURE"

  local base_executor
  before_each(function()
    base_executor = Executor("example-host", "")
    stub(base_executor, "upload")
    stub(base_executor, "download")
    stub(base_executor, "run_command")
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

  describe("should return correct exit code", function()
    it("when job succeeds", function()
      base_executor:run_executor_job(succ_job_command)
      assert.equals(0, base_executor:last_job_status())
    end)

    it("when job fails", function()
      base_executor:run_executor_job(failing_job_command)
      assert.equals(127, base_executor:last_job_status())
    end)
  end)

  it("should error out if no job is running and job cancel gets called", function()
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

  it("should match the job output", function()
    base_executor:run_executor_job(succ_job_command)
    assert.equals("SUCCESS", table.concat(base_executor:job_stdout(), ""))
  end)

  describe("should generate the correct number of output lines", function()
    it("for standard output", function()
      base_executor:run_executor_job("echo '1\n2\n3\n4'")
      assert.equals(4, #base_executor:job_stdout())
    end)

    it("for output containing extra new lines at end", function()
      base_executor:run_executor_job("echo '1\n2\n3\n4\n\n'")
      assert.equals(4, #base_executor:job_stdout())
    end)

    it("not trimming away empty lines in job output", function()
      base_executor:run_executor_job("echo '1\n2\n\n3\n4\n'")
      assert.equals(5, #base_executor:job_stdout())
    end)
  end)
end)
