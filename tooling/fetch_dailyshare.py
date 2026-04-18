import requests
import json
import time
import os

CONTAINER = "iCloud.com.batu.ones"
TOKEN = os.environ.get("CLOUDKIT_TOKEN", "14e45a95a555a34dc5ae81c50319bcb949d49591ddba314e4084118395e0b762")
ENVIRONMENT = "production"
DATABASE = "public"

BASE_URL = f"https://api.apple-cloudkit.com/database/1/{CONTAINER}/{ENVIRONMENT}/{DATABASE}"

headers = {
    "Content-Type": "application/json"
}

def fetch_all_records():
    all_records = []
    cursor = None
    page = 1

    while True:
        print(f"Sayfa {page} çekiliyor...")

        body = {
            "query": {
                "recordType": "DailyShare"
            },
            "resultsLimit": 200
        }

        if cursor:
            body["continuationMarker"] = cursor

        response = requests.post(
            f"{BASE_URL}/records/query",
            params={"ckAPIToken": TOKEN},
            headers=headers,
            json=body
        )

        if response.status_code != 200:
            print(f"Hata: {response.status_code}")
            print(response.text)
            break

        data = response.json()
        records = data.get("records", [])
        all_records.extend(records)
        print(f"  → {len(records)} kayıt alındı (toplam: {len(all_records)})")

        if data.get("moreComing"):
            cursor = data.get("continuationMarker")
        else:
            break

        page += 1
        time.sleep(0.3)

    return all_records

def flatten_record(r):
    fields = r.get("fields", {})
    flat = {
        "recordName": r.get("recordName"),
        "createdAt": r.get("created", {}).get("timestamp"),
        "modifiedAt": r.get("modified", {}).get("timestamp"),
    }
    for key, val in fields.items():
        flat[key] = val.get("value")
    return flat

if __name__ == "__main__":
    print(f"Container: {CONTAINER}")
    print(f"Environment: {ENVIRONMENT}\n")

    raw_records = fetch_all_records()

    if not raw_records:
        print("Hiç kayıt bulunamadı.")
    else:
        flat_records = [flatten_record(r) for r in raw_records]

        output_path = "dailyshare.json"
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(flat_records, f, ensure_ascii=False, indent=2, default=str)

        print(f"\nToplam {len(flat_records)} kayıt kaydedildi → {output_path}")

        moods = {}
        for r in flat_records:
            m = r.get("moodColor") or r.get("mood") or "unknown"
            moods[m] = moods.get(m, 0) + 1

        if moods:
            print("\nRuh hali dağılımı:")
            for mood, count in sorted(moods.items(), key=lambda x: -x[1]):
                print(f"  {mood}: {count}")
