using Gmsh

# Execute the generated wrapper with a deterministic C ABI callback. Only the
# native-call target changes; the error branch and returned output stay intact.
module LoggerErrorPathProbe
using Gmsh
const fail = Ref{Cint}(1)
const message = UInt8[codeunits("known native message"); 0]
function native_get_last_error(output::Ptr{Ptr{Cchar}}, ierr::Ptr{Cint})::Cvoid
    unsafe_store!(ierr, fail[])
    unsafe_store!(output, fail[] == 0 ? Ptr{Cchar}(pointer(message)) : Ptr{Cchar}(C_NULL))
    return
end
const NATIVE_CALL = @cfunction(native_get_last_error, Cvoid, (Ptr{Ptr{Cchar}}, Ptr{Cint}))
const wrappers = collect(eachmatch(r"(?ms)^function getLastError\(\)\n.*?^end$",
                                  read(Gmsh.gmsh_jll.gmsh_api, String)))
length(wrappers) == 1 || Base.error("expected one generated getLastError wrapper")
const body = only(wrappers).match
const target = "(:gmshLoggerGetLastError, gmsh.lib)"
count(target, body) == 1 || Base.error("unexpected generated native-call target")
Base.include_string(Gmsh._qualify_api_errors, @__MODULE__,
    replace(body, target => "NATIVE_CALL"), "generated_getLastError_abi_probe.jl")
end

@testset "generated logger native error path" begin
    probe = LoggerErrorPathProbe
    probe.fail[] = 1
    failure = try probe.getLastError(); nothing catch e; e end
    @test failure isa ErrorException
    @test failure.msg == "Could not get last error"
    probe.fail[] = 0
    @test probe.getLastError() == "known native message"
    probe.fail[] = 2
    @test_throws ErrorException probe.getLastError()

    # Qualifying the call must not rename an output or touch an existing
    # qualified call. Reapplying the loader transformation is harmless.
    ex = :(function sample(); error("failure"); error = "output"; error; end)
    fixed = Gmsh._qualify_api_errors(deepcopy(ex))
    @test fixed.args[2].args[end] === :error
    @test Gmsh._qualify_api_errors(deepcopy(fixed)) == fixed
    qualified = :(Base.error("failure"))
    @test Gmsh._qualify_api_errors(deepcopy(qualified)) == qualified
end
