using TestItemRunner

if haskey(ENV, "RUNNING_IN_GITHUB_CI") && ENV["RUNNING_IN_GITHUB_CI"] == "true"
    @info "Github CI environment detected"
    @run_package_tests filter = ti -> !(:skipci in ti.tags) verbose = true
else
    @info "Running tests locally"
    @run_package_tests verbose = true
end