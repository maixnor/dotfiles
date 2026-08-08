#!/usr/bin/env python3
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime

# Monatsnamen-Übersetzung
MONTH_MAP = {
    "Jan": "Januar", "Feb": "Februar", "Mar": "März", "Apr": "April",
    "May": "Mai", "Jun": "Juni", "Jul": "Juli", "Aug": "August",
    "Sep": "September", "Oct": "Oktober", "Nov": "November", "Dec": "Dezember"
}

def fetch_log_from_server(server="wb.maixnor.com", path="/var/www/cloud.maixnor.com/log.txt"):
    """Holt log.txt vom Remote-Server via SSH."""
    cmd = ["ssh", server, f"cat {path}"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Fehler beim Abrufen des Logs via SSH: {e}", file=sys.stderr)
        sys.exit(1)

def parse_logs(log_content, start_date_filter=datetime(2026, 7, 16)):
    """Analysiert Log-Inhalte, filtert 404-Anfragen und Einträge vor dem 16. Juli 2026 heraus."""
    per_date_data = defaultdict(lambda: defaultdict(list))
    
    lines = log_content.strip().splitlines()
    
    total_raw_lines = len(lines)
    excluded_404_count = 0
    excluded_date_count = 0
    valid_count = 0

    for line in lines:
        if not line.strip():
            continue

        # Auf 404-Status prüfen
        if " 404 " in line or "code 404" in line or " 404 -" in line:
            excluded_404_count += 1
            continue

        # Zeitstempel/Datum extrahieren
        date_match = re.search(r'\[(\d{2}/[A-Za-z]{3}/\d{4})[:\s](\d{2}:\d{2}:\d{2})\]', line)
        if not date_match:
            date_match = re.search(r'\[(\d{2}/[A-Za-z]{3}/\d{4})', line)
        
        date_str = date_match.group(1) if date_match else "Unbekanntes Datum"
        
        # Startdatum-Filter (16. Juli 2026)
        try:
            parsed_dt = datetime.strptime(date_str, "%d/%b/%Y")
            if parsed_dt < start_date_filter:
                excluded_date_count += 1
                continue
        except Exception:
            pass

        # IP-Adresse extrahieren
        ip_match = re.search(r'IP:\s*([^\s,]+)', line)
        ip_address = ip_match.group(1) if ip_match else "Unbekannte IP"

        # User-Agent extrahieren
        ua_match = re.search(r'User-Agent:\s*(.*?), Request:', line)
        user_agent = ua_match.group(1).strip() if ua_match else "Unbekannt"

        entry = {
            "time": date_match.group(2) if date_match and len(date_match.groups()) > 1 else "",
            "ip": ip_address,
            "user_agent": user_agent,
            "raw": line
        }

        per_date_data[date_str][ip_address].append(entry)
        valid_count += 1

    return per_date_data, total_raw_lines, excluded_404_count, excluded_date_count, valid_count

def format_date_german(d_str):
    """Formatiert '16/Jul/2026' in '16. Juli 2026'."""
    try:
        parts = d_str.split('/')
        day = parts[0]
        month_de = MONTH_MAP.get(parts[1], parts[1])
        year = parts[2]
        return f"{day}. {month_de} {year}"
    except Exception:
        return d_str

def generate_markdown_report(per_date_data, total_lines, excluded_404, excluded_date, valid_count):
    """Erstellt einen deutschen Markdown-Bericht in chronologischer Reihenfolge (Alt nach Neu)."""
    md = []
    md.append("# 📊 Tracking-Service Protokoll-Bericht")
    md.append(f"*Erstellt am: {datetime.now().strftime('%d.%m.%Y um %H:%M:%S Uhr')}*\n")
    
    md.append("## 📈 Zusammenfassung")
    md.append(f"- **Gesamtzahl verarbeiteter Log-Einträge:** `{total_lines}`")
    md.append(f"- **Ausgefilterte 404-Fehleranfragen:** `{excluded_404}`")
    md.append(f"- **Ausgefilterte Einträge vor dem 16. Juli:** `{excluded_date}`")
    md.append(f"- **Gültige Anfragen (ab 16. Juli):** `{valid_count}`")
    
    all_ips = set()
    for ips in per_date_data.values():
        all_ips.update(ips.keys())
    
    md.append(f"- **Einzigartige IP-Adressen insgesamt:** `{len(all_ips)}`\n")
    md.append("---\n")

    md.append("## 📅 Tägliche IP-Aufschlüsselung (Chronologisch)\n")

    if not per_date_data:
        md.append("_Keine gültigen Anfragen für den ausgewählten Zeitraum gefunden._\n")
        return "\n".join(md)

    def date_key(d_str):
        try:
            return datetime.strptime(d_str, "%d/%b/%Y")
        except Exception:
            return datetime.min

    # Sortierung: Alt nach Neu
    sorted_dates = sorted(per_date_data.keys(), key=date_key, reverse=False)

    for date_str in sorted_dates:
        ip_dict = per_date_data[date_str]
        total_day_requests = sum(len(entries) for entries in ip_dict.values())
        formatted_date = format_date_german(date_str)
        
        md.append(f"### 🗓️ Datum: `{formatted_date}`")
        md.append(f"**Gültige Anfragen:** `{total_day_requests}` | **Einzigartige IPs:** `{len(ip_dict)}`\n")
        md.append("| IP-Adresse | Anzahl Anfragen | Haupt-User-Agent |")
        md.append("| :--- | :---: | :--- |")

        # IPs nach Anzahl der Anfragen absteigend sortieren
        sorted_ips = sorted(ip_dict.items(), key=lambda item: len(item[1]), reverse=True)

        for ip, entries in sorted_ips:
            count = len(entries)
            uas = list(set(e["user_agent"] for e in entries if e["user_agent"] != "Unbekannt" and e["user_agent"] != "Unknown"))
            ua_str = uas[0] if uas else "Unbekannt"
            if len(ua_str) > 75:
                ua_str = ua_str[:72] + "..."

            md.append(f"| `{ip}` | `{count}` | {ua_str} |")

        md.append("\n")

    return "\n".join(md)

def main():
    log_content = ""
    if len(sys.argv) > 1 and sys.argv[1] != "--ssh":
        with open(sys.argv[1], "r", encoding="utf-8", errors="ignore") as f:
            log_content = f.read()
    else:
        log_content = fetch_log_from_server()

    per_date_data, total_lines, excluded_404, excluded_date, valid_count = parse_logs(log_content)
    report_md = generate_markdown_report(per_date_data, total_lines, excluded_404, excluded_date, valid_count)

    output_path = "tracking_report.md"
    if len(sys.argv) > 2:
        output_path = sys.argv[2]

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(report_md)

    print(f"Bericht erfolgreich erstellt -> {output_path}")

if __name__ == "__main__":
    main()
