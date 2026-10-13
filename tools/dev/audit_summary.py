"""Groups the findings of layout_audit JSON files by screen and kind (dev tool, D370).

usage: python tools/dev/audit_summary.py sandbox/audit/a.json [more.json ...] [--kind=small_text] [--sev=warn]
"""
import collections
import json
import sys

kinds = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--kind=")]
sevs = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--sev=")]
for path in [a for a in sys.argv[1:] if not a.startswith("--")]:
    d = json.load(open(path))
    print("== %s errors=%d warns=%d" % (path, d["errors"], d["warns"]))
    for s in d["screens"]:
        c = collections.Counter()
        ex = {}
        for f in s["findings"]:
            if kinds and f["kind"] not in kinds:
                continue
            if sevs and f["sev"] not in sevs:
                continue
            key = (f["sev"], f["kind"])
            c[key] += 1
            ex.setdefault(key, "%s %s %s" % (f["node"].split("/")[-1], f["rect"], f["detail"]))
        if c:
            print("-- %s" % s["screen"])
            for key, n in sorted(c.items()):
                print("   %s %-16s x%-3d e.g. %s" % (key[0], key[1], n, ex[key][:150]))
