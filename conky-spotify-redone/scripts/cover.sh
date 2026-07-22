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

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CURRENT_DIR="$SCRIPT_DIR/../current"
COVERS_DIR="$SCRIPT_DIR/../covers"

# Temporary file for downloaded album art
TEMP_FILE=$(mktemp /tmp/conky-spotify-cover.XXXXXX)

# Ensure required directories exist
mkdir -p "$COVERS_DIR"
mkdir -p "$CURRENT_DIR"

# Create empty.png from empty.jpg if it doesn't exist
if [ ! -f "$CURRENT_DIR/empty.png" ]; then
    if [ -f "$SCRIPT_DIR/../empty.jpg" ]; then
        convert "$SCRIPT_DIR/../empty.jpg" "$CURRENT_DIR/empty.png"
    fi
fi

# Read current track ID and fetch new ID
id_current=$(cat "$CURRENT_DIR/current.txt" 2>/dev/null || echo "")
id_new=$("$SCRIPT_DIR/id.sh")

# Check if Spotify is running through DBus
dbus=$(busctl --user list 2>/dev/null | grep "spotify")

if [ -z "$dbus" ]; then

    # Spotify is not running
    if [ -f "$CURRENT_DIR/empty.png" ]; then
        cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    fi

    echo "" > "$CURRENT_DIR/current.txt"

else

    # Spotify is running
    echo "$id_new" > "$CURRENT_DIR/current.txt"

    # Extract image name from Spotify track ID
    imgname=$(echo "$id_new" | cut -d '/' -f5)

    # Check if album art is already cached
    if [ -f "$COVERS_DIR/${imgname}.png" ]; then

        cp "$COVERS_DIR/${imgname}.png" "$CURRENT_DIR/current.png"

    else

        # Get album art URL
        imgurl=$("$SCRIPT_DIR/imgurl.sh")

        if [ -n "$imgurl" ]; then

            # Download album art
            if timeout 5 wget -q -O "$TEMP_FILE" "$imgurl"; then

                # Convert downloaded image to PNG
                convert "$TEMP_FILE" "$CURRENT_DIR/current.png"

                # Validate PNG
                if file "$CURRENT_DIR/current.png" | grep -q "PNG image data"; then

                    # Cache PNG
                    cp "$CURRENT_DIR/current.png" \
                       "$COVERS_DIR/${imgname}.png"

                else

                    # Invalid image
                    if [ -f "$CURRENT_DIR/empty.png" ]; then
                        cp "$CURRENT_DIR/empty.png" \
                           "$CURRENT_DIR/current.png"
                    fi

                fi

            else

                # Download failed
                if [ -f "$CURRENT_DIR/empty.png" ]; then
                    cp "$CURRENT_DIR/empty.png" \
                       "$CURRENT_DIR/current.png"
                fi

            fi

        else

            # No image URL
            if [ -f "$CURRENT_DIR/empty.png" ]; then
                cp "$CURRENT_DIR/empty.png" \
                   "$CURRENT_DIR/current.png"
            fi

        fi

    fi

fi

# Clean temporary file
rm -f "$TEMP_FILE"

# Keep only the newest 10 cached PNG files
find "$COVERS_DIR/" \
    -maxdepth 1 \
    -type f \
    -name "*.png" \
    -printf "%T@ %p\n" |
    sort -nr |
    awk 'NR>10 {print $2}' |
    xargs -r rm -f
