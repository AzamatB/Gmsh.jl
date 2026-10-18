"""Reproduce the pinned Julia binding from the official Gmsh generator."""
from pathlib import Path
import argparse
import hashlib
import io
import re
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

VERSION = "4.15.2"
URL = f"https://gmsh.info/src/gmsh-{VERSION}-source.tgz"
SHA256 = "be3f66f225d27ba9fa014f07e83169285da8a051b0e8ab7103d88066b39bdd3e"
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--archive", type=Path, help="Use a downloaded archive instead of fetching it")
parser.add_argument("--check", action="store_true", help="Verify the checked-in generated binding")
args = parser.parse_args()
if args.archive:
    archive = args.archive.read_bytes()
else:
    with urllib.request.urlopen(URL, timeout=60) as response:
        archive = response.read()
assert hashlib.sha256(archive).hexdigest() == SHA256, "Unexpected upstream source archive"
with tempfile.TemporaryDirectory(prefix="gmsh-julia-generator-") as directory:
    work = Path(directory)
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as source:
        prefix = f"gmsh-{VERSION}-source/"
        for relative in ("CMakeLists.txt", "api/gen.py", "api/GenApi.py"):
            entry = source.getmember(prefix + relative)
            target = work / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.extractfile(entry).read())
    subprocess.run(["patch", "-p1", "-i", str(ROOT / "gen/qualify_julia_errors.patch")], cwd=work, check=True)
    (work / "doc/texinfo").mkdir(parents=True)
    subprocess.run([sys.executable, "gen.py"], cwd=work / "api", check=True)
    generated = (work / "api/gmsh.jl").read_text()
# Apply the existing Yggdrasil adaptation: bind to gmsh_jll's unchanged native library.
generated = re.sub(r"^(import Libdl|const lib.*)$", r"#\1", generated, flags=re.M)
generated = re.sub(r"^module gmsh$", "module gmsh\nusing gmsh_jll: libgmsh\nconst lib = libgmsh", generated, flags=re.M)
# Keep the checked-in generated source free of trailing documentation whitespace.
generated = "\n".join(line.rstrip() for line in generated.split("\n"))
output = ROOT / "src/gmsh_api.jl"
if args.check:
    assert output.read_text() == generated, "Generated Julia API is out of date"
else:
    output.write_text(generated)
print(hashlib.sha256(generated.encode()).hexdigest(), output)
