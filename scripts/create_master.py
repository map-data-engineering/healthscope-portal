import csv, os

COUNTRIES = {
    "Zambia": {
        "fac": "docs/data/Zambia/zambia_standardized.csv",
        "svc": "docs/data/Zambia/zambia_services.csv",
        "out_src": "data/Zambia/zambia_master.csv",
        "out_docs": "docs/data/Zambia/zambia_master.csv"
    },
    "Tanzania": {
        "fac": "docs/data/tanzania/tanzania_standardized.csv",
        "svc": "docs/data/tanzania/hf_services.csv",
        "out_src": "data/tanzania/tanzania_master.csv",
        "out_docs": "docs/data/tanzania/tanzania_master.csv"
    },
    "Kenya": {
        "fac": "docs/data/Kenya/kenya_standardized.csv",
        "svc": "docs/data/Kenya/kenya_services.csv",
        "out_src": "data/Kenya/kenya_master.csv",
        "out_docs": "docs/data/Kenya/kenya_master.csv"
    },
    "Malawi": {
        "fac": "docs/data/Malawi/malawi_standardized.csv",
        "svc": "docs/data/Malawi/malawi_services.csv",
        "out_src": "data/Malawi/malawi_master.csv",
        "out_docs": "docs/data/Malawi/malawi_master.csv"
    }
}

FAC_COLS = ["facility_name", "facility_code", "facility_type", "facility_ownership",
            "latitude", "longitude", "admin1", "status"]
SVC_COLS = ["service_category", "service_group", "service_detail"]
MASTER_COLS = FAC_COLS + SVC_COLS

for country, paths in COUNTRIES.items():
    fac_map = {}
    with open(paths["fac"], encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            code = row.get("facility_code", "").strip()
            if code:
                fac_map[code] = {c: row.get(c, "") for c in FAC_COLS}

    fac_with_svc = set()
    rows_written = 0

    for out_path in [paths["out_src"], paths["out_docs"]]:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(paths["svc"], encoding="utf-8", errors="replace") as fin, \
             open(out_path, "w", newline="", encoding="utf-8") as fout:
            reader = csv.DictReader(fin)
            writer = csv.DictWriter(fout, fieldnames=MASTER_COLS)
            writer.writeheader()
            count = 0
            for svc_row in reader:
                code = svc_row.get("facility_code", "").strip()
                if code in fac_map:
                    merged = dict(fac_map[code])
                    merged["service_category"] = svc_row.get("service_category", "")
                    merged["service_group"] = svc_row.get("service_group", "")
                    merged["service_detail"] = svc_row.get("service_detail", "")
                    writer.writerow(merged)
                    fac_with_svc.add(code)
                    count += 1
            for code, fac in fac_map.items():
                if code not in fac_with_svc:
                    merged = dict(fac)
                    merged["service_category"] = ""
                    merged["service_group"] = ""
                    merged["service_detail"] = ""
                    writer.writerow(merged)
                    count += 1
            rows_written = count

    fac_without = len(fac_map) - len(fac_with_svc)
    print(f"{country}: {rows_written} rows | {len(fac_with_svc)} facilities with services, {fac_without} without")
