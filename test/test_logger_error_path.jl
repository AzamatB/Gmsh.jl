using Test
# Keep the generated body unchanged except for its native-call target. The C ABI
# callback deterministically drives ierr without an OOM or a broken Gmsh process.
module LoggerErrorPathProbe
const fail = Ref{Cint}(1)
const message = UInt8[codeunits("known native message");0]
function native_get_last_error(output::Ptr{Ptr{Cchar}}, ierr::Ptr{Cint})::Cvoid
    unsafe_store!(ierr,fail[])
    unsafe_store!(output,fail[]==0 ? Ptr{Cchar}(pointer(message)) : Ptr{Cchar}(C_NULL))
    return
end
const NATIVE_CALL=@cfunction(native_get_last_error,Cvoid,(Ptr{Ptr{Cchar}},Ptr{Cint}))
const api_source=read(joinpath(@__DIR__,"..","src","gmsh_api.jl"),String)
const matches=collect(eachmatch(r"(?ms)^function getLastError\(\)\n.*?^end$",api_source))
length(matches)==1 || Base.error("expected one generated getLastError wrapper")
const body=only(matches).match
const target="(:gmshLoggerGetLastError, gmsh.lib)"
count(target,body)==1 || Base.error("unexpected generated native-call target")
include_string(@__MODULE__,replace(body,target=>"NATIVE_CALL"),"generated_getLastError_abi_probe.jl")
end
@testset "logger native error path" begin
    probe=LoggerErrorPathProbe
    probe.fail[]=1
    failure=try probe.getLastError();nothing catch e;e end
    @test failure isa ErrorException
    @test failure.msg == "Could not get last error"
    probe.fail[]=0
    @test probe.getLastError() == "known native message"
    probe.fail[]=2
    @test_throws ErrorException probe.getLastError()
end
