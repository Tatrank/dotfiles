#!/usr/bin/env bash
#|---/ /+---------------------------------------------+---/ /|#
#|--/ /-| Script to generate color palette from image |--/ /-|#
#|-/ /--| Prasanth Rangan                             |-/ /--|#
#|/ /---+---------------------------------------------+/ /---|#

#// accent color profile

colorProfile="default"
wallbashCurve="32 50\n42 46\n49 40\n56 39\n64 38\n76 37\n90 33\n94 29\n100 20"
sortMode="auto"

while [ $# -gt 0 ]; do
    case "$1" in
    -v | --vibrant)
        colorProfile="vibrant"
        wallbashCurve="18 99\n32 97\n48 95\n55 90\n70 80\n80 70\n88 60\n94 40\n99 24"
        ;;
    -p | --pastel)
        colorProfile="pastel"
        wallbashCurve="10 99\n17 66\n24 49\n39 41\n51 37\n58 34\n72 30\n84 26\n99 22"
        ;;
    -m | --mono)
        colorProfile="mono"
        wallbashCurve="10 0\n17 0\n24 0\n39 0\n51 0\n58 0\n72 0\n84 0\n99 0"
        ;;
    -c | --custom)
        shift
        if [ -n "${1}" ] && [[ "${1}" =~ ^([0-9]+[[:space:]][0-9]+\\n){8}[0-9]+[[:space:]][0-9]+$ ]]; then
            colorProfile="custom"
            wallbashCurve="${1}"
        else
            echo "Error: Custom color curve format is incorrect ${1}"
            exit 1
        fi
        ;;
    -d | --dark)
        sortMode="dark"
        colSort=""
        ;;
    -l | --light)
        sortMode="light"
        colSort="-r"
        ;;
    *)
        break
        ;;
    esac
    shift
done

#// set variables

wallbashImg="${1}"
wallbashColors=4
wallbashFuzz=70
wallbashRaw="${2:-"${wallbashImg}"}.mpc"
wallbashOut="${2:-"${wallbashImg}"}.dcol"
wallbashCache="${2:-"${wallbashImg}"}.cache"
matugenCache="${2:-"${wallbashImg}"}.matugen.json"

#// color modulations

pryDarkBri=116
pryDarkSat=110
pryDarkHue=88
pryLightBri=100
pryLightSat=100
pryLightHue=114
txtDarkBri=188
txtLightBri=16

#// input image validation

if [ -z "${wallbashImg}" ] || [ ! -f "${wallbashImg}" ]; then
    echo "Error: Input file not found!"
    exit 1
fi

# Check if matugen is available
if ! command -v matugen &> /dev/null; then
    echo "Error: matugen is not installed or not in PATH"
    exit 1
fi

echo -e "wallbash ${colorProfile} profile :: ${sortMode} :: Colors ${wallbashColors} :: \"${wallbashOut}\""
cacheDir="${cacheDir:-$XDG_CACHE_HOME/hyde}"
thmDir="${thmDir:-$cacheDir/thumbs}"
mkdir -p "${cacheDir}/${thmDir}"
: >"${wallbashOut}"

#// define functions

rgb_negative() {
    local inCol=$1
    local r=${inCol:0:2}
    local g=${inCol:2:2}
    local b=${inCol:4:2}
    local r16=$((16#$r))
    local g16=$((16#$g))
    local b16=$((16#$b))
    r=$(printf "%02X" $((255 - r16)))
    g=$(printf "%02X" $((255 - g16)))
    b=$(printf "%02X" $((255 - b16)))
    echo "${r}${g}${b}"
}

rgba_convert() {
    local inCol=$1
    local r=${inCol:0:2}
    local g=${inCol:2:2}
    local b=${inCol:4:2}
    local r16=$((16#$r))
    local g16=$((16#$g))
    local b16=$((16#$b))
    printf "rgba(%d,%d,%d,1)\n" "$r16" "$g16" "$b16"
}

# Function to extract colors from matugen JSON output
extract_matugen_colors() {
    local json_file="$1"
    local color_type="$2"  # primary, secondary, tertiary, etc.
    
    # Extract hex color without # prefix
    jq -r ".colors.${color_type} // empty" "$json_file" | sed 's/^#//'
}

# Function to get brightness using a simple calculation
calc_brightness() {
    local hex_color="$1"
    local r=$((16#${hex_color:0:2}))
    local g=$((16#${hex_color:2:2}))
    local b=$((16#${hex_color:4:2}))
    # Using relative luminance formula
    local brightness=$(echo "scale=3; ($r * 0.299 + $g * 0.587 + $b * 0.114) / 255" | bc -l)
    # Return 0 if dark (< 0.5), 1 if light
    if (( $(echo "$brightness < 0.5" | bc -l) )); then
        return 0  # dark
    else
        return 1  # light
    fi
}

# Function to convert HSL to hex
hsl_to_hex() {
    local h=$1 s=$2 l=$3
    # Use a simple conversion - you might want to use a more robust method
    python3 -c "
import colorsys
h, s, l = $h/360.0, $s/100.0, $l/100.0
r, g, b = colorsys.hls_to_rgb(h, l, s)
print('%02x%02x%02x' % (int(r*255), int(g*255), int(b*255)))
"
}

#// generate colors using matugen

echo "Generating colors with matugen..."

# Generate color palette using matugen
if [ "${sortMode}" == "light" ]; then
    matugen_scheme="--mode light"
else
    matugen_scheme="--mode dark"
fi

# Generate matugen color palette and save to JSON
matugen image "${wallbashImg}" ${matugen_scheme} --json hex > "${matugenCache}"

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate colors with matugen"
    exit 1
fi

# Extract primary colors from matugen output
readarray -t dcolHex < <(
    jq -r '.colors | to_entries[] | select(.key | test("^(primary|secondary|tertiary|error)$")) | .value' "${matugenCache}" | \
    sed 's/^#//' | head -n ${wallbashColors}
)

# If we don't have enough colors, supplement with surface colors
if [ ${#dcolHex[@]} -lt ${wallbashColors} ]; then
    readarray -t surface_colors < <(
        jq -r '.colors | to_entries[] | select(.key | test("surface")) | .value' "${matugenCache}" | \
        sed 's/^#//' | head -n $((wallbashColors - ${#dcolHex[@]}))
    )
    dcolHex+=("${surface_colors[@]}")
fi

#// auto-detect sort mode if not specified
if [ "${sortMode}" == "auto" ]; then
    if calc_brightness "${dcolHex[0]}"; then
        sortMode="light"
        colSort="-r"
    else
        sortMode="dark"
        colSort=""
    fi
fi

echo "dcol_mode=\"${sortMode}\"" >>"${wallbashOut}"

# Sort colors if needed
if [ -n "${colSort}" ]; then
    # Sort by brightness for light mode
    mapfile -t sorted_colors < <(
        for color in "${dcolHex[@]}"; do
            brightness=$(python3 -c "
r, g, b = int('$color'[0:2], 16), int('$color'[2:4], 16), int('$color'[4:6], 16)
print(f'{(r * 0.299 + g * 0.587 + b * 0.114):.3f} $color')
            ")
            echo "$brightness"
        done | sort -rn | awk '{print $2}'
    )
    dcolHex=("${sorted_colors[@]}")
fi

#// Check if image is grayscale
greyCheck=$(jq -r '.colors.primary' "${matugenCache}" | python3 -c "
import sys
color = input().replace('#', '')
r, g, b = int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16)
max_diff = max(abs(r-g), abs(g-b), abs(r-b))
print(1 if max_diff < 30 else 0)  # If color difference is small, it's grayscale
")

if [ "$greyCheck" == "1" ]; then
    wallbashCurve="10 0\n17 0\n24 0\n39 0\n51 0\n58 0\n72 0\n84 0\n99 0"
fi

#// loop for derived colors

for ((i = 0; i < wallbashColors; i++)); do

    #// generate missing primary colors
    if [ -z "${dcolHex[i]}" ]; then
        if calc_brightness "${dcolHex[i - 1]}"; then
            modBri=$pryLightBri
            modSat=$pryLightSat
            modHue=$pryLightHue
        else
            modBri=$pryDarkBri
            modSat=$pryDarkSat
            modHue=$pryDarkHue
        fi

        echo -e "dcol_pry$((i + 1)) :: regen missing color"
        # Use python to generate missing color with HSL modulation
        dcolHex[i]=$(python3 -c "
import colorsys
prev_color = '${dcolHex[i - 1]}'
r, g, b = int(prev_color[0:2], 16)/255.0, int(prev_color[2:4], 16)/255.0, int(prev_color[4:6], 16)/255.0
h, l, s = colorsys.rgb_to_hls(r, g, b)
# Apply modulations (simplified)
l = min(1.0, l * ${modBri}/100.0)
s = min(1.0, s * ${modSat}/100.0)
h = (h + ${modHue}/360.0) % 1.0
r, g, b = colorsys.hls_to_rgb(h, l, s)
print('%02x%02x%02x' % (int(r*255), int(g*255), int(b*255)))
")
    fi

    echo "dcol_pry$((i + 1))=\"${dcolHex[i]}\"" >>"${wallbashOut}"
    echo "dcol_pry$((i + 1))_rgba=\"$(rgba_convert "${dcolHex[i]}")\"" >>"${wallbashOut}"

    #// generate primary text colors
    nTxt=$(rgb_negative "${dcolHex[i]}")

    if calc_brightness "${dcolHex[i]}"; then
        modBri=$txtLightBri
    else
        modBri=$txtDarkBri
    fi

    tcol=$(python3 -c "
import colorsys
neg_color = '${nTxt}'
r, g, b = int(neg_color[0:2], 16)/255.0, int(neg_color[2:4], 16)/255.0, int(neg_color[4:6], 16)/255.0
h, l, s = colorsys.rgb_to_hls(r, g, b)
l = min(1.0, l * ${modBri}/100.0)
s = 0.1  # 10% saturation
r, g, b = colorsys.hls_to_rgb(h, l, s)
print('%02x%02x%02x' % (int(r*255), int(g*255), int(b*255)))
")
    echo "dcol_txt$((i + 1))=\"${tcol}\"" >>"${wallbashOut}"
    echo "dcol_txt$((i + 1))_rgba=\"$(rgba_convert "${tcol}")\"" >>"${wallbashOut}"

    #// generate accent colors
    xHue=$(python3 -c "
import colorsys
color = '${dcolHex[i]}'
r, g, b = int(color[0:2], 16)/255.0, int(color[2:4], 16)/255.0, int(color[4:6], 16)/255.0
h, l, s = colorsys.rgb_to_hls(r, g, b)
print(int(h * 360))
")
    acnt=1

    echo -e "${wallbashCurve}" | sort -n ${colSort:+"$colSort"} | while read -r xBri xSat; do
        acol=$(hsl_to_hex "${xHue}" "${xSat}" "${xBri}")
        echo "dcol_$((i + 1))xa${acnt}=\"${acol}\"" >>"${wallbashOut}"
        echo "dcol_$((i + 1))xa${acnt}_rgba=\"$(rgba_convert "${acol}")\"" >>"${wallbashOut}"
        ((acnt++))
    done

done

#// cleanup temp cache
rm -f "${wallbashRaw}" "${wallbashCache}" "${matugenCache}"