#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <tag> <SHA256SUMS>" >&2
  echo "example: $0 v1.1.6 ./SHA256SUMS" >&2
  exit 2
fi

tag="$1"
sums_file="$2"
version="${tag#v}"
formula="Formula/nornicdb.rb"

if [[ ! -f "$sums_file" ]]; then
  echo "SHA256SUMS file not found: $sums_file" >&2
  exit 2
fi

if [[ ! -f "$formula" ]]; then
  echo "formula not found: $formula" >&2
  exit 2
fi

darwin_arm64_sha="$(awk '$2 == "nornicdb-darwin-arm64.tar.gz" {print $1}' "$sums_file")"
darwin_amd64_sha="$(awk '$2 == "nornicdb-darwin-amd64.tar.gz" {print $1}' "$sums_file")"

if [[ -z "$darwin_arm64_sha" || -z "$darwin_amd64_sha" ]]; then
  echo "missing darwin sha256 entries in $sums_file" >&2
  exit 1
fi

tmp="$(mktemp)"
awk \
  -v version="$version" \
  -v arm="$darwin_arm64_sha" \
  -v amd="$darwin_amd64_sha" '
    /version "/ {
      sub(/version "[^"]+"/, "version \"" version "\"")
    }
    /on_arm do/ {
      in_arm = 1
      in_amd = 0
    }
    /on_intel do/ {
      in_arm = 0
      in_amd = 1
    }
    /sha256 "/ && in_arm == 1 {
      sub(/sha256 "[^"]+"/, "sha256 \"" arm "\"")
    }
    /sha256 "/ && in_amd == 1 {
      sub(/sha256 "[^"]+"/, "sha256 \"" amd "\"")
    }
    { print }
  ' "$formula" > "$tmp"

mv "$tmp" "$formula"
echo "Updated $formula to $tag"
