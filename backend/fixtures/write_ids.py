import json

with open("units.json", "r") as f:
    content = json.load(f)


rewrite = []
for idx, item in enumerate(content, start=1):
    item.pop("id", "None")
    item.pop("pk", "None")
    item["fields"]["id"] = idx
    rewrite.append(item)


with open("units.json", "w") as f:
    json.dump(rewrite, f)
