# Prevent warnings in our test suite.
Code.put_compiler_option(:warnings_as_errors, true)

# Silence our logging since tests should only log when something exceptional occurs.
Logger.configure(level: :info)
Logger.configure_backend(:console, level: :warn)

# Setup our environment.
{:ok, _} = Application.ensure_all_started(:hardhat)

# Run unit and integration tests.
ExUnit.start(capture_log: false, exclude: [:skip, :broken, :benchmark])
