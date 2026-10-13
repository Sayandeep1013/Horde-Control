"""Prints the findings of one or more layout_audit JSON files (dev tool, D370).

usage: python tools/dev/audit_report.py sandbox/audit/a.json [more.json] [--warn] [--screen=name]
"""
import json
import sys

show_warn = "--warn" in sys.argv
only = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--screen=")]
for path in [a for a in sys.argv[1:] if not a.startswith("--")]:
    d = json.load(open(path))
    print("== %s size=%s errors=%d warns=%d" % (path, d["size"], d["errors"], d["warns"]))
    for s in d["screens"]:
        if only and s["screen"] not in only:
            continue
        fs = [f for f in s["findings"] if show_warn or f["sev"] == "error"]
        if not fs:
            continue
        print("-- %s (canvas %s safe %s) errors=%d warns=%d" % (s["screen"], s["canvas"], s["safe"], s["errors"], s["warns"]))
        for f in fs:
            print("   %-5s %-16s %s %s %s | %s | '%s'" % (f["sev"], f["kind"], f["node"], f["rect"], f["class"], f["detail"], f["text"]))
