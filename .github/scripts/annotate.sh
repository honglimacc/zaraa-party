#!/usr/bin/env bash
# Usage: annotate.sh <title> <file> <regex>
# Menampilkan baris yang cocok sebagai anotasi (maks 4 anotasi x 12 baris) agar mudah dibaca.
title="$1"; file="$2"; re="$3"
grep -E "$re" "$file" | head -48 | awk -v t="$title" '
  { buf = buf (buf ? "%0A" : "") $0; n++ }
  n % 12 == 0 { print "::error title=" t "::" buf; buf = "" }
  END { if (buf != "") print "::error title=" t "::" buf }'
