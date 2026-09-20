#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

command -v whiskers >/dev/null 2>&1 || {
    echo >&2 "Whiskers is required but it's not installed."
    exit 1
}

for file in ./templates/*.svg.tera; do
    echo "Templating $file"
    whiskers "$file"
done

command -v inkscape >/dev/null 2>&1 || {
    echo >&2 "Inkscape is not installed. Will not convert SVGs to PNGs."
    exit 0
}

echo "Converting SVGs to PNGs"
inkscape output/svg/*/*.svg --export-type=png
for dir in output/svg/*; do
    if [ ! -d "$dir" ]; then
        continue
    fi
    
    flavor=$(basename "$dir")
    mkdir -p "output/png/$flavor"
    mv "$dir"/*.png "output/png/$flavor/"
done

command -v exiftool >/dev/null 2>&1 || {
    echo >&2 "ExifTool is not installed. Will not tag PNGs with SHA256 of source SVG."
    exit 0
}

echo "Tagging PNGs with SHA256 of source SVG"
for file in output/png/*/*.png; do
    svg="output/svg/$(basename "$(dirname "$file")")/$(basename "$file" .png).svg"
    hash=$(sha256sum "$svg" | awk '{print $1}')
    exiftool -overwrite_original -Comment="$hash" "$file"
done
