#!/bin/bash
# Full application names, consistently lowercase.
app_label() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}
