import json
import sys

from requests_html import HTMLSession

ELECTIONS = {
    "251": "General Election",
}


def get_races(html):
    return {
        o.attrs["value"].strip() or "0": o.text.strip()
        for o in html.find("#race option")
    }


if __name__ == "__main__":
    session = HTMLSession()
    election_metadata = {
        "251": {"label": "General Election", "races": {}},
    }
    for election in ELECTIONS.keys():
        res = session.get(
            f"https://chicagoelections.gov/en/election-results.asp?election={election}"
        )
        election_metadata[election]["races"] = get_races(res.html)
    json.dump(election_metadata, sys.stdout)
