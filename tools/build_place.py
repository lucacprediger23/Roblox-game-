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


import re
import glob

SHARED = []


def assets_folder():
    """Merges every assets/*.rbxmx (models saved from Studio) into ReplicatedStorage.Assets."""
    files = sorted(glob.glob(os.path.join(ROOT, "assets", "**", "*.rbxmx"), recursive=True))
    if not files:
        return ""
    items = []
    for n, path in enumerate(files):
        with open(path, encoding="utf-8") as f:
            xml = f.read()
        # shared strings (mesh data) go at the top level of the place
        m = re.search(r"<SharedStrings>(.*?)</SharedStrings>", xml, re.S)
        if m:
            SHARED.append(m.group(1))
            xml = xml[: m.start()] + xml[m.end():]
        # keep only the <Item> elements inside <roblox>
        start = xml.find("<Item")
        end = xml.rfind("</roblox>")
        body = xml[start:end]
        # make referents unique per file
        body = re.sub(r'referent="([^"]+)"', lambda m: 'referent="A%d_%s"' % (n, m.group(1)), body)
        body = re.sub(r"<Ref name=\"([^\"]+)\">(RBX[^<]+)</Ref>", lambda m: '<Ref name="%s">A%d_%s</Ref>' % (m.group(1), n, m.group(2)), body)
        items.append(body)
    return '<Item class="Folder" referent="%s"><Properties><string name="Name">Assets</string></Properties>%s</Item>' % (ref(), "".join(items))


def shared_strings():
    """One <SharedStrings> block with each md5 only once."""
    seen = {}
    for chunk in SHARED:
        for m in re.finditer(r'<SharedString md5="([^"]+)"\s*(?:/>|>.*?</SharedString>)', chunk, re.S):
            seen.setdefault(m.group(1), m.group(0))
    if not seen:
        return ""
    return "<SharedStrings>%s</SharedStrings>" % "".join(seen.values())


def main():
    src = os.path.join(ROOT, "src")
    body = "".join(
        [
            service("Workspace", props='<bool name="StreamingEnabled">false</bool>'),
            # Future lighting: real light from lamps and neon, shiny reflections
            service(
                "Lighting",
                props='<token name="Technology">4</token><bool name="GlobalShadows">true</bool>'
                '<bool name="Outlines">false</bool><token name="LightingStyle">0</token>',
            ),
            # the modern, realistic material set (the old one looks cartoony)
            service("MaterialService", props='<bool name="Use2022MaterialsXml">true</bool>'),
            service("ReplicatedStorage", folder_of_scripts("Folder", "Shared", os.path.join(src, "shared")) + assets_folder()),
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
        "%s%s</roblox>" % (body, shared_strings())
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
