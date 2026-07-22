#!/bin/bash
# Conky-Spotify Integration
# Copyright (C) 2014 Madh93
# Modified by @wim66 April 25, 2025
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Determine the script's directory
#
# Compatibility fix for ImageMagick 6
# Modified by @sebah1924

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CURRENT_DIR="$SCRIPT_DIR/../current"
COVERS_DIR="$SCRIPT_DIR/../covers"
TEMP_FILE=$(mktemp /tmp/conky-spotify-cover.XXXXXX)

mkdir -p "$CURRENT_DIR" "$COVERS_DIR"

cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# Comprobar que existe la imagen de respaldo
if [ ! -f "$CURRENT_DIR/empty.png" ]; then
    echo "ERROR: Falta $CURRENT_DIR/empty.png"
    exit 1
fi

# Comprobar que Spotify está ejecutándose
if ! busctl --user list 2>/dev/null | grep -q "spotify"; then
    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    : > "$CURRENT_DIR/current.txt"
    exit 0
fi

# Obtener ID de la canción
id_new=$("$SCRIPT_DIR/id.sh" 2>/dev/null)

if [ -z "$id_new" ]; then
    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    : > "$CURRENT_DIR/current.txt"
    exit 0
fi

echo "$id_new" > "$CURRENT_DIR/current.txt"

# Obtener nombre único de la portada
imgname=$(echo "$id_new" | cut -d '/' -f5)

if [ -z "$imgname" ]; then
    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    exit 0
fi

# Si ya existe la portada en caché, usarla
if [ -f "$COVERS_DIR/${imgname}.png" ]; then
    cp "$COVERS_DIR/${imgname}.png" "$CURRENT_DIR/current.png"
    exit 0
fi

# Obtener URL de la portada
imgurl=$("$SCRIPT_DIR/imgurl.sh" 2>/dev/null)

if [ -z "$imgurl" ]; then
    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    exit 0
fi

# Descargar portada
if ! timeout 10 wget -q -O "$TEMP_FILE" "$imgurl"; then
    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    exit 0
fi

# Convertir a PNG
if ! convert "$TEMP_FILE" "$CURRENT_DIR/current.png" 2>/dev/null; then
    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    exit 0
fi

# Comprobar que el PNG es válido
if ! file "$CURRENT_DIR/current.png" | grep -q "PNG image data"; then
    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    exit 0
fi

# Guardar en caché
cp "$CURRENT_DIR/current.png" "$COVERS_DIR/${imgname}.png"

# Mantener solamente las 10 portadas más recientes
find "$COVERS_DIR" \
    -maxdepth 1 \
    -type f \
    -name "*.png" \
    -printf "%T@ %p\n" 2>/dev/null |
    sort -nr |
    awk 'NR>10 {print $2}' |
    xargs -r rm -f

