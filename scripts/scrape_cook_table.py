import csv
import re
import sys

from requests_html import HTML


def get_township_ward_precinct(precinct_str):
    ward = ""
    if " Ward" not in precinct_str:
        *township_list, precinct = precinct_str.split(" ")
    else:
        *township_list, _, ward, _, precinct = precinct_str.split(" ")
    township = " ".join([w for w in township_list if w not in ["Ward", "Precinct"]])
    if ward:
        precinct_id = f"{township.upper()} {ward}-{precinct}"
    else:
        precinct_id = f"{township.upper()} {precinct}"
    return [precinct_id, township, ward, precinct]


def process_table(table, turnout=False):
    candidates = [th.text.strip() for th in table.find("th")][3:-1]
    headers = (
        ["id", "township", "ward", "precinct", "registered", "ballots"]
        + candidates
        + ["total"]
    )
    rows = []
    for row in table.find("tr[align='right']")[:-1]:
        row_values = []
        for idx, cell in enumerate(row.find("td")):
            if idx == 0:
                row_values.extend(get_township_ward_precinct(cell.text.strip()))
                continue
            row_values.append(int(re.sub(r"\D", "", cell.text)))
        row_dict = dict(zip(headers, row_values))
        for candidate in candidates:
            if row_dict["total"] == 0:
                row_dict[f"{candidate} Percent"] = 0.0
            else:
                row_dict[f"{candidate} Percent"] = round(
                    (row_dict[candidate] / row_dict["total"]) * 100, 2
                )
        if turnout:
            row_dict["turnout"] = round(
                (row_dict["ballots"] / row_dict["registered"]) * 100, 2
            )
        rows.append(row_dict)
    return rows


if __name__ == "__main__":
    with open(sys.argv[1], "rb") as f:
        html = HTML(html=f.read())
    include_turnout = sys.argv[1].split("/")[-1].split(".")[0] == "0"

    rows = []
    for table in html.find(".results-precinct-container table"):
        rows.extend(process_table(table, turnout=include_turnout))

    if len(rows) > 0:
        writer = csv.DictWriter(sys.stdout, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
