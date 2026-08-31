#!/usr/bin/env python3
"""Bundle the map modules + a mock Roblox API into one runnable Luau file.

The Luau CLI has no filesystem access, so the only way to actually EXECUTE the
map builders outside Studio is to concatenate everything into a single script.
Requires are rewritten to a registry lookup keyed on the last path component
(`require(ReplicatedStorage.Shared.Config.Balance)` -> `__require("Balance")`).
"""
import json
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

MODULES = {
    "Balance":  SRC / "ReplicatedStorage/Shared/Config/Balance.luau",
    "Palettes": SRC / "ReplicatedStorage/Shared/Config/Palettes.luau",
    "Rivals":   SRC / "ReplicatedStorage/Shared/Config/Rivals.luau",
    "Ranks":    SRC / "ReplicatedStorage/Shared/Config/Ranks.luau",
    "Floors":   SRC / "ReplicatedStorage/Shared/Config/Floors.luau",
    "Format":   SRC / "ReplicatedStorage/Shared/Util/Format.luau",
    "Gear":      SRC / "ReplicatedStorage/Shared/Config/Gear.luau",
    "Interns":   SRC / "ReplicatedStorage/Shared/Config/Interns.luau",
    "Severance": SRC / "ReplicatedStorage/Shared/Config/Severance.luau",
    "Sanitize":  SRC / "ReplicatedStorage/Shared/Util/Sanitize.luau",
    # The multiplier stack: pure math, no DataModel access, so it runs headless.
    "Stack":     SRC / "ServerScriptService/Server/Economy/Stack.luau",
    # The startup path itself: builds every floor into workspace.
}
# The outdoor world.
FLOOR_IDS = []  # the old indoor floors are gone; kept empty for the script tree
for _name, _rel in {
    "Stages":       "ReplicatedStorage/Shared/Config/Stages.luau",
    "Surfaces":     "ReplicatedStorage/Shared/Config/Surfaces.luau",
    "TrainingBags": "ReplicatedStorage/Shared/Config/TrainingBags.luau",
    "Skins":        "ReplicatedStorage/Shared/Config/Skins.luau",
    "Eggs":         "ReplicatedStorage/Shared/Config/Eggs.luau",
    "OutdoorKit":   "ServerScriptService/Server/World/OutdoorKit.luau",
    "StageDecor":   "ServerScriptService/Server/World/StageDecor.luau",
    "StageBuilder": "ServerScriptService/Server/World/StageBuilder.luau",
    "Hub":          "ServerScriptService/Server/World/Hub.luau",
    "WorldService": "ServerScriptService/Server/World/WorldService.luau",
}.items():
    MODULES[_name] = SRC / _rel


# Vendored packages + the rest of the server, so the whole boot can run.
for _name, _rel in {
    "Trove":       "ReplicatedStorage/Packages/Trove.luau",
    "Signal":      "ReplicatedStorage/Packages/Signal.luau",
    "t":           "ReplicatedStorage/Packages/t.luau",
    "ProfileStore": "ServerScriptService/Packages/ProfileStore.luau",
    "Types":       "ReplicatedStorage/Shared/Types.luau",
    "Sounds":      "ReplicatedStorage/Shared/Config/Sounds.luau",
    "Monetization": "ReplicatedStorage/Shared/Config/Monetization.luau",
    "Net":         "ServerScriptService/Server/Net/Net.luau",
    "Migrations":  "ServerScriptService/Server/Data/Migrations.luau",
    "DataService": "ServerScriptService/Server/Data/DataService.luau",
    "ProductivityService": "ServerScriptService/Server/Economy/ProductivityService.luau",
    "ShopService": "ServerScriptService/Server/Economy/ShopService.luau",
    "RestructureService": "ServerScriptService/Server/Economy/RestructureService.luau",
    "InternService": "ServerScriptService/Server/Economy/InternService.luau",
    "MonetizationService": "ServerScriptService/Server/Economy/MonetizationService.luau",
    "RankService": "ServerScriptService/Server/Progression/RankService.luau",
    "LeaderboardService": "ServerScriptService/Server/Boards/LeaderboardService.luau",
    "TrainingService": "ServerScriptService/Server/Economy/TrainingService.luau",
    "SkinService": "ServerScriptService/Server/Economy/SkinService.luau",
    "StageService": "ServerScriptService/Server/Stages/StageService.luau",
}.items():
    MODULES[_name] = SRC / _rel


def _instance_tree(root: pathlib.Path, var: str) -> str:
    """Emit Luau that mirrors a src/ directory as Folders + ModuleScripts.

    Services walk these paths on the way to a require (`ReplicatedStorage.Shared
    .Config.Balance`). The require itself is rewritten, but the walk still has to
    resolve, so the shape has to be real rather than a permissive stub.
    """
    lines = []
    counter = [0]

    def walk(directory: pathlib.Path, parent_var: str):
        for entry in sorted(directory.iterdir()):
            counter[0] += 1
            handle = f"n{counter[0]}"
            if entry.is_dir():
                lines.append(f'\tlocal {handle} = Instance.new("Folder"); {handle}.Name = "{entry.name}"; {handle}.Parent = {parent_var}')
                walk(entry, handle)
            elif entry.suffix == ".luau" and not entry.name.endswith((".server.luau", ".client.luau")):
                name = entry.name[: -len(".luau")]
                lines.append(f'\tlocal {handle} = Instance.new("ModuleScript"); {handle}.Name = "{name}"; {handle}.Parent = {parent_var}')

    walk(root, var)
    return "\n".join(lines)

REQUIRE_RE = re.compile(r"require\(\s*([A-Za-z_][A-Za-z0-9_.]*)\s*\)")


def rewrite(source: str) -> str:
    # require(a.b.C) -> __require("C")
    source = REQUIRE_RE.sub(lambda m: '__require("%s")' % m.group(1).split(".")[-1], source)
    # `export type` is illegal inside a function body, and we wrap every module.
    source = source.replace("export type ", "type ")
    # Service handles resolve through the mock `game`.
    source = re.sub(r"game:GetService\(", "__game:GetService(", source)
    return source


def build(test_body: str) -> str:
    out = ["--!nonstrict", "-- GENERATED by tools/build_harness.py — do not edit.", ""]

    mock = (ROOT / "tools/roblox_mock.luau").read_text()
    # Keep the mock's remote list in lockstep with the real project file, or a
    # newly declared remote fails Net.bind only in the harness.
    project = json.loads((ROOT / "default.project.json").read_text())
    remote_names = [
        k for k in project["tree"]["ReplicatedStorage"]["Remotes"] if not k.startswith("$")
    ]
    mock = re.sub(
        r"local REMOTE_NAMES = \{[^}]*\}",
        "local REMOTE_NAMES = { %s }" % ", ".join('"%s"' % n for n in remote_names),
        mock,
    )
    out.append("local __mock = (function()\n%s\nend)()\n" % mock)
    for name in ("Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2", "Enum", "Instance"):
        out.append(f"local {name} = __mock.{name}")
    out.append("local __game = __mock.game")
    out.append("local typeof = __mock.typeof")
    out.append("local workspace = __mock.workspace")
    out.append("local task = __mock.task")
    # Vendored code reads bare `game.PlaceId`, not just game:GetService().
    out.append("local game = __game")
    # `warn` is a Roblox global; the CLI has no such thing.
    out.append('local function warn(...) print("[warn]", ...) end\n')
    out.append("-- Instance trees mirroring the Rojo layout, so path walks resolve.")
    out.append("do\n\tlocal rs = __game:GetService(\"ReplicatedStorage\")")
    out.append(_instance_tree(SRC / "ReplicatedStorage", "rs"))
    out.append("end")
    out.append("do\n\tlocal sss = __game:GetService(\"ServerScriptService\")")
    out.append(_instance_tree(SRC / "ServerScriptService", "sss"))
    out.append("end\n")

    out.append("local __registry = {}")
    out.append("local __loaded = {}")
    out.append("""
local function __require(name)
	-- Accept a mock ModuleScript as well as a registry key: MapService looks
	-- its floor modules up as Instances via FindFirstChild.
	if type(name) == "table" then name = name.Name end
	if __loaded[name] ~= nil then return __loaded[name] end
	local factory = __registry[name]
	if factory == nil then error("harness: no module registered as '" .. name .. "'") end
	local result = factory()
	__loaded[name] = result
	return result
end

-- Bare `require` (e.g. passed as a value to pcall) resolves through the
-- registry too, the way it would inside Roblox.
local require = __require
""")

    # A minimal instance tree mirroring the Rojo layout, so modules that walk
    # `script.Parent...` (MapService looking up Server/World/Floors) resolve.
    out.append("""
local __scriptTree = {}
do
	local world = Instance.new("Folder"); world.Name = "World"
	local worldScript = Instance.new("ModuleScript"); worldScript.Name = "WorldService"; worldScript.Parent = world
	__scriptTree.WorldService = worldScript
end
local function __scriptFor(name)
	return __scriptTree[name] or Instance.new("ModuleScript")
end
""")

    for name, path in MODULES.items():
        if not path.exists():
            sys.exit(f"missing module: {path}")
        out.append('__registry["%s"] = function()\nlocal script = __scriptFor("%s")\n%s\nend\n'
                   % (name, name, rewrite(path.read_text())))

    out.append(test_body)
    return "\n".join(out)


if __name__ == "__main__":
    body = pathlib.Path(sys.argv[1]).read_text()
    dest = pathlib.Path(sys.argv[2])
    dest.write_text(build(body))
    print(f"wrote {dest} ({dest.stat().st_size // 1024} KB)")
