The checked-in Julia API is generated from the official Gmsh 4.15.2 source archive, with the two-line upstream generator patch in `qualify_julia_errors.patch`. The patch qualifies generated error calls as `Base.error`, so an API output named `error` cannot shadow the exception function. API signatures and native binaries are unchanged.

The binding uses the same gmsh_jll library adaptation as Yggdrasil's G/gmsh recipe, then normalizes trailing documentation whitespace. The package bounds gmsh_jll to the matching API version. The generated source retains upstream copyright and license notices; the upstream license is preserved in `GMSH_LICENSE.txt`.

Reproduce or verify the file with Python 3 and the `patch` utility:

```sh
python3 gen/generate_api.py
python3 gen/generate_api.py --check
```

An already downloaded source archive can be supplied with `--archive`; its SHA-256 is verified in either mode. The logger regression injects a deterministic C ABI callback into the exact generated wrapper body, so the error path is exercised without exhausting memory or requiring a C compiler. It preserves the successful string return as a positive control.
