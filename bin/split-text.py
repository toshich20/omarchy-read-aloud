#!/usr/bin/env python3
import re
import sys

limit = int(sys.argv[1]) if len(sys.argv) > 1 else 450
limit = max(limit, 200)
text = sys.stdin.read().strip()
if not text:
    sys.exit(0)

parts = re.split(r"(?<=[.!?…。！？])\s+", text)
chunks = []
current = ""

for part in parts:
    while len(part) > limit:
        if current:
            chunks.append(current)
            current = ""
        cut = part.rfind(" ", 0, limit)
        if cut < limit // 2:
            cut = limit
        chunks.append(part[:cut].strip())
        part = part[cut:].lstrip()
    addition = part.strip()
    if not addition:
        continue
    if current and len(current) + len(addition) + 1 > limit:
        chunks.append(current)
        current = addition
    else:
        current = (current + " " + addition).strip() if current else addition

if current:
    chunks.append(current)

out = sys.stdout.buffer
for chunk in chunks:
    out.write(chunk.encode("utf-8") + b"\0")
