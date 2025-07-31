#!/bin/bash
ip -br a | awk '$1 ~ /^eth[0-9]+$/ {split($3, a, "/"); print a[1], $1}' | sort -k2 | awk '{printf "%s ", $1}' | sed 's/ $//'
