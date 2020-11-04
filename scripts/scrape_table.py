import csv
import sys

from requests_html import HTML


def get_candidates(html):
    headers = [v.text for v in html.find("table", first=True).find("b")][1:]
    return [h for h in headers if "%" not in h]


def process_table(table, candidates):
    ward = int(table.find("thead th b, tr td b", first=True).text.split()[-1])
    rows = []
    for row in table.find("tr"):
        row_values = get_row_values(row, ward, candidates)
        if row_values:
            rows.append(row_values)
    return rows


def get_row_values(row, ward, candidates):
    values = [v.text.strip() for v in row.find("td")]
    if len(values) == 0 or any(
        w in values[0].lower() for w in ["total", "precinct", "ward"]
    ):
        return
    vote_values = [int(v.replace(",", "")) for v in values[2:] if "%" not in v]
    pct_values = [float(v.replace("%", "")) for v in values[2:] if "%" in v]
    return {
        "id": f"{str(ward).zfill(2)}{values[0].zfill(3)}",
        "ward": ward,
        "precinct": int(values[0]),
        "total": int(values[1].replace(",", "")),
        **dict(zip(candidates, vote_values)),
        **dict(zip([f"{c} Percent" for c in candidates], pct_values)),
    }


if __name__ == "__main__":
    with open(sys.argv[1], "rb") as f:
        html = HTML(html=f.read())
    candidates = get_candidates(html)
    columns = (
        ["id", "ward", "precinct", "total"]
        + candidates
        + [f"{c} Percent" for c in candidates]
    )
    writer = csv.DictWriter(sys.stdout, fieldnames=columns)
    writer.writeheader()
    for table in html.find("table")[1:]:
        writer.writerows(process_table(table, candidates))
