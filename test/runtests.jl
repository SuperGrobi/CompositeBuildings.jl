using TestItemRunner


if haskey(ENV, "RUNNING_IN_GITHUB_CI") && ENV["RUNNING_IN_GITHUB_CI"]
    @run_package_tests filter = ti -> !(:skipci in ti.tags) verbose = true
else
    @run_package_tests verbose = true
end