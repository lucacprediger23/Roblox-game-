"""Pulls models made in Studio out of a saved place file into an assets/*.rbxmx file.

Usage: python3 tools/extract_assets.py <saved.rbxlx> <FolderNameInWorkspace> <out.rbxmx> [NewFolderName]

Example: python3 tools/extract_assets.py saved.rbxlx GeneratedCars d2d/assets/cars.rbxmx Cars
The folder keeps its children; meshes keep their asset ids, so they load in the game.
"""

import sys
import xml.etree.ElementTree as ET


def main():
    src, folder_name, out = sys.argv[1], sys.argv[2], sys.argv[3]
    new_name = sys.argv[4] if len(sys.argv) > 4 else folder_name
    tree = ET.parse(src)
    root = tree.getroot()

    def name_of(item):
        props = item.find("Properties")
        if props is None:
            return None
        for p in props:
            if p.get("name") == "Name":
                return p.text
        return None

    found = None
    for item in root.iter("Item"):
        if item.get("class") == "Folder" and name_of(item) == folder_name:
            found = item
            break
    if found is None:
        sys.exit("folder %s not found" % folder_name)

    # rename the folder
    for p in found.find("Properties"):
        if p.get("name") == "Name":
            p.text = new_name

    # keep the shared strings (mesh data) that the folder uses
    used = set()
    for el in found.iter("SharedString"):
        if el.text:
            used.add(el.text.strip())
    shared_out = ET.Element("SharedStrings")
    shared = root.find("SharedStrings")
    if shared is not None:
        for s in shared:
            if s.get("md5") in used:
                shared_out.append(s)

    out_root = ET.Element("roblox", {"version": "4"})
    out_root.append(found)
    if len(shared_out):
        out_root.append(shared_out)
    ET.ElementTree(out_root).write(out, encoding="utf-8", xml_declaration=False)
    count = len([c for c in found if c.tag == "Item"])
    print("wrote %s with %d models, %d shared strings" % (out, count, len(shared_out)))


if __name__ == "__main__":
    main()
