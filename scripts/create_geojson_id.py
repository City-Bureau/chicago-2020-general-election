import json
import sys

if __name__ == "__main__":
    data = json.load(sys.stdin)
    for f in data["features"]:
        f["properties"]["id"] = str(f["properties"]["WARD"]).zfill(2) + str(
            f["properties"]["PRECINCT"]
        ).zfill(3)
    json.dump(data, sys.stdout)
