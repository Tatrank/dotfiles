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

# Function to get brightness using Python
calc_brightness() {
    local hex_color="$1"
    local brightness=$(python3 -c "
hex_color = '$hex_color'
r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255
print(1 if brightness >= 0.5 else 0)
")
    return $brightness  # Return 0 if dark, 1 if light
}

# Function to convert HSL to hex
hsl_to_hex() {
    local h=$1 s=$2 l=$3
    python3 -c "
import colorsys
h, s, l = $h/360.0, $s/100.0, $l/100.0
r, g, b = colorsys.hls_to_rgb(h, l, s)
print('%02x%02x%02x' % (int(r*255), int(g*255), int(b*255)))
"
}

# Function to validate hex color
is_valid_hex() {
    local color="$1"
    if [[ "$color" =~ ^[0-9a-fA-F]{6}$ ]]; then
        return 0  # valid
    else
        return 1  # invalid
    fi
}

#// generate colors using matugen

echo "Generating colors with matugen..."

# Generate color palette using matugen - determine which scheme to use
if [ "${sortMode}" == "light" ]; then
    color_scheme="light"
else
    color_scheme="dark"
fi

# Generate matugen color palette and save to JSON
matugen image "${wallbashImg}" --json hex > "${matugenCache}"

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate colors with matugen"
    exit 1
fi

# Check that the JSON has the expected structure
if ! jq -e ".colors.${color_scheme}" "${matugenCache}" >/dev/null; then
    echo "Error: Matugen didn't generate the expected JSON structure with ${color_scheme} scheme"
    echo "JSON contents:"
    jq -C . "${matugenCache}" | head -n 20
    exit 1
fi

# Extract colors with semantic meaning directly from matugen
echo "Extracting semantic colors from matugen..."

# Write mode to output file
echo "dcol_mode=\"${sortMode}\"" >> "${wallbashOut}"

declare -A color_mapping=(
    # Primary colors (pry) - Use surface colors for backgrounds, primary/secondary for accents
    ["dcol_pry1"]=""                 
    ["dcol_pry2"]=""         
    ["dcol_pry3"]=""                    
    ["dcol_pry4"]=""                  
    
    # Text colors (txt) - Use corresponding on_* colors for guaranteed contrast
    ["dcol_txt1"]=""
    ["dcol_txt2"]=""
    ["dcol_txt3"]=""
    ["dcol_txt4"]=""
    
    # Accent colors for surface/background (group 1)
    ["dcol_1xa1"]=""
    ["dcol_1xa2"]=""
    ["dcol_1xa3"]=""
    ["dcol_1xa4"]=""
    ["dcol_1xa5"]=""
    ["dcol_1xa6"]=""
    ["dcol_1xa7"]=""
    ["dcol_1xa8"]=""
    ["dcol_1xa9"]=""
    
    # Accent colors for containers (group 2)
    ["dcol_2xa1"]=""
    ["dcol_2xa2"]=""
    ["dcol_2xa3"]=""
    ["dcol_2xa4"]=""
    ["dcol_2xa5"]=""
    ["dcol_2xa6"]=""
    ["dcol_2xa7"]=""
    ["dcol_2xa8"]=""
    ["dcol_2xa9"]=""
    
    # Accent colors for primary accent (group 3)
    ["dcol_3xa1"]=""
    ["dcol_3xa2"]=""
    ["dcol_3xa3"]=""
    ["dcol_3xa4"]=""
    ["dcol_3xa5"]=""
    ["dcol_3xa6"]=""
    ["dcol_3xa7"]=""
    ["dcol_3xa8"]=""
    ["dcol_3xa9"]=""
    
    # Accent colors for secondary accent (group 4)
    ["dcol_4xa1"]=""
    ["dcol_4xa2"]=""
    ["dcol_4xa3"]=""
    ["dcol_4xa4"]=""
    ["dcol_4xa5"]=""
    ["dcol_4xa6"]=""
    ["dcol_4xa7"]=""
    ["dcol_4xa8"]=""
    ["dcol_4xa9"]=""
)


# Create an empty dcol array to store extracted colors
declare -A dcol=()

# Extract colors from JSON based on mapping
for var_name in "${!color_mapping[@]}"; do
    matugen_key="${color_mapping[$var_name]}"
    color_value=$(jq -r ".colors.${color_scheme}.${matugen_key} // empty" "${matugenCache}" | sed 's/^#//')
    
    # If color exists and is valid, store it
    if [[ -n "$color_value" && "$color_value" =~ ^[0-9a-fA-F]{6}$ ]]; then
        dcol[$var_name]=$color_value
        echo "Extracted $var_name: $color_value (from ${matugen_key})"
    fi
done

# Handle cases where primary colors are missing by using appropriate fallbacks
for i in {1..4}; do
    pry_var="dcol_pry$i"
    txt_var="dcol_txt$i"
    
    # If primary color is missing, try fallbacks based on your mapping
    if [ -z "${dcol[$pry_var]}" ]; then
        case $i in
            1) # surface fallbacks
                fallbacks=("surface" "background" "surface_container")
                ;;
            2) # secondary fallbacks
                fallbacks=("secondary" "blue" "cyan")
                ;;
            3) # tertiary fallbacks
                fallbacks=("tertiary" "magenta" "yellow")
                ;;
            4) # primary fallbacks
                fallbacks=("primary" "surface_tint" "primary_container")
                ;;
        esac
        
        # Try each fallback
        for fallback in "${fallbacks[@]}"; do
            color_value=$(jq -r ".colors.${color_scheme}.${fallback} // empty" "${matugenCache}" | sed 's/^#//')
            if [[ -n "$color_value" && "$color_value" =~ ^[0-9a-fA-F]{6}$ ]]; then
                dcol[$pry_var]=$color_value
                echo "Using fallback for $pry_var: $color_value (from ${fallback})"
                break
            fi
        done
        
        # If still missing, use smart defaults
        if [ -z "${dcol[$pry_var]}" ]; then
            case $i in
                1) dcol[$pry_var]="202020" ;;  # Dark surface
                2) dcol[$pry_var]="4a9eff" ;;  # Blue secondary
                3) dcol[$pry_var]="ff6b9d" ;;  # Pink tertiary
                4) dcol[$pry_var]="6c5ce7" ;;  # Purple primary
            esac
            echo "Using default color for $pry_var: ${dcol[$pry_var]}"
        fi
    fi
    
    # If text color is missing, try fallbacks based on your mapping
    if [ -z "${dcol[$txt_var]}" ]; then
        case $i in
            1) # on_surface fallbacks
                fallbacks=("on_surface" "on_background" "foreground")
                ;;
            2) # on_secondary fallbacks
                fallbacks=("on_secondary" "on_blue" "on_cyan")
                ;;
            3) # on_tertiary fallbacks
                fallbacks=("on_tertiary" "on_magenta" "on_yellow")
                ;;
            4) # on_primary fallbacks
                fallbacks=("on_primary" "on_primary_container" "on_surface")
                ;;
        esac
        
        # Try each fallback
        for fallback in "${fallbacks[@]}"; do
            color_value=$(jq -r ".colors.${color_scheme}.${fallback} // empty" "${matugenCache}" | sed 's/^#//')
            if [[ -n "$color_value" && "$color_value" =~ ^[0-9a-fA-F]{6}$ ]]; then
                dcol[$txt_var]=$color_value
                echo "Using fallback for $txt_var: $color_value (from ${fallback})"
                break
            fi
        done
        
        # If still missing, generate it from the primary color
        if [ -z "${dcol[$txt_var]}" ]; then
            nTxt=$(rgb_negative "${dcol[$pry_var]}")
            if calc_brightness "${dcol[$pry_var]}"; then
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
            dcol[$txt_var]=$tcol
            echo "Generated text color for $txt_var: $tcol"
        fi
    fi
    
    # Write the primary and text colors to output
    echo "${pry_var}=\"${dcol[$pry_var]}\"" >> "${wallbashOut}"
    echo "${pry_var}_rgba=\"$(rgba_convert "${dcol[$pry_var]}")\"" >> "${wallbashOut}"
    echo "${txt_var}=\"${dcol[$txt_var]}\"" >> "${wallbashOut}"
    echo "${txt_var}_rgba=\"$(rgba_convert "${dcol[$txt_var]}")\"" >> "${wallbashOut}"
    
    # Handle accent colors - generate them based on the primary color for this group
    for j in {1..9}; do
        xa_var="dcol_${i}xa${j}"
        if [ -z "${dcol[$xa_var]}" ]; then
            # Generate accent color based on the primary color for this group
            base_color="${dcol[$pry_var]}"
            
            # Extract hue from base color
            xHue=$(python3 -c "
import colorsys
color = '$base_color'
r, g, b = int(color[0:2], 16)/255.0, int(color[2:4], 16)/255.0, int(color[4:6], 16)/255.0
h, l, s = colorsys.rgb_to_hls(r, g, b)
print(int(h * 360))
            ")
            
            # Read the brightness/saturation values from the curve
            readarray -t curve_values < <(echo -e "${wallbashCurve}" | sort -n ${colSort:+"$colSort"})
            if (( j <= ${#curve_values[@]} )); then
                read -r xBri xSat <<< "${curve_values[j-1]}"
                acol=$(hsl_to_hex "${xHue}" "${xSat}" "${xBri}")
                dcol[$xa_var]=$acol
                echo "Generated accent color for $xa_var: $acol (based on ${pry_var})"
            else
                # Default if we run out of curve values
                dcol[$xa_var]=${dcol[$pry_var]}
                echo "Using default accent color for $xa_var: ${dcol[$pry_var]}"
            fi
        fi
        
        # Write accent color to output
        echo "${xa_var}=\"${dcol[$xa_var]}\"" >> "${wallbashOut}"
        echo "${xa_var}_rgba=\"$(rgba_convert "${dcol[$xa_var]}")\"" >> "${wallbashOut}"
    done
done

#// cleanup temp cache
rm -f "${wallbashRaw}" "${wallbashCache}" "${matugenCache}"

echo "Color extraction complete. Colors saved to ${wallbashOut}"