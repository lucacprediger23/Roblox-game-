"""Packs the scripts in src/ into a Roblox place file you can open in Studio.

Usage:  python3 tools/build_place.py
Output: build/StealASquishyEgg.rbxlx
"""

import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import sys
# usage: build_place.py [project_dir] [output_name]
if len(sys.argv) > 1:
    ROOT = os.path.abspath(sys.argv[1])
OUT = os.path.join(ROOT, "build", sys.argv[2] if len(sys.argv) > 2 else "StealASquishyEgg.rbxlx")

_ref = 0


def ref():
    global _ref
    _ref += 1
    return "RBX%08X" % _ref


def script_item(path):
    filename = os.path.basename(path)
    base = filename[: -len(".lua")]
    if base.endswith(".server"):
        cls, name = "Script", base[: -len(".server")]
    elif base.endswith(".client"):
        cls, name = "LocalScript", base[: -len(".client")]
    else:
        cls, name = "ModuleScript", base
    with open(path, encoding="utf-8") as f:
        source = f.read()
    if "]]>" in source:
        raise ValueError(path + " contains ']]>' which breaks CDATA")
    return (
        '<Item class="%s" referent="%s"><Properties>'
        '<string name="Name">%s</string>'
        '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>'
        "</Properties></Item>" % (cls, ref(), escape(name), source)
    )


def folder_of_scripts(class_name, name, src_dir):
    children = "".join(
        script_item(os.path.join(src_dir, f))
        for f in sorted(os.listdir(src_dir))
        if f.endswith(".lua")
    )
    return (
        '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string></Properties>%s</Item>'
        % (class_name, ref(), escape(name), children)
    )


def service(class_name, inner="", props=""):
    return (
        '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>%s</Properties>%s</Item>'
        % (class_name, ref(), class_name, props, inner)
    )


def main():
    src = os.path.join(ROOT, "src")
    body = "".join(
        [
            service("Workspace", props='<bool name="StreamingEnabled">false</bool>'),
            service("ReplicatedStorage", folder_of_scripts("Folder", "Shared", os.path.join(src, "shared"))),
            service("ServerScriptService", folder_of_scripts("Folder", "Server", os.path.join(src, "server"))),
            service(
                "StarterPlayer",
                folder_of_scripts("StarterPlayerScripts", "StarterPlayerScripts", os.path.join(src, "client")),
            ),
        ]
    )
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        "%s</roblox>" % body
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
