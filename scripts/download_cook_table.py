import sys

import requests

# Create a crosswalk of overlapping IDs
CROSSWALK = {
    "18": "19",  # US House 7th
    "19": "21",  # US House 9th
    "24": "27",  # IL State Senate 10th
    "25": "28",  # IL State Senate 11th
    "44": "44",  # IL State Rep, 19th, same but coincidence
    "45": "45",  # IL State Rep, 20th, same but coincidence
    "59": "58",  # IL State Rep, 35th
    "63": "71",  # IL State Rep, 55th
    "64": "77",  # IL State Rep, 78th
    "65": "80",  # MWRD
    "66": "81",  # State's Attorney
    "67": "82",  # Clerk
    "68": "83",  # Board of Review 1st
}


def get_cook_race_id(race_id):
    # Judges are in same order, so increment to match
    if int(race_id) >= 103 and int(race_id) <= 164:
        return str(int(race_id) + 17)
    # Add 9 as prefix for races with overlapping IDs
    if len(race_id) >= 3 and race_id[0] == "9":
        return race_id[1:]
    return CROSSWALK.get(race_id, race_id)


if __name__ == "__main__":
    _, race_id = sys.argv
    res = requests.get(
        "https://results1120.cookcountyclerkil.gov/Detail.aspx",
        params={
            "eid": "110320",
            "rid": get_cook_race_id(race_id),
            "vfor": "1",
            "twpftr": "0",
        },
    )
    sys.stdout.write(res.text)
