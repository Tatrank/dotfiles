#!/usr/bin/env bash
#|---/ /+---------------------------------------------+---/ /|#
#|--/ /-| Script to generate color palette from image |--/ /-|#
#|-/ /--| Uses matugen for generation & a Python      |-/ /--|#
#|/ /---+ wrapper for dcol compatibility.             +/ /---|#

# This script is now a wrapper for matugen_to_dcol.py to maintain
# compatibility with the existing HyDE theming system. It parses
# legacy arguments and passes them to the new Python script.

#// Parse legacy arguments for the new system
matugen_args=()
while [ $# -gt 0 ]; do
    case "$1" in
    -v | --vibrant)
        matugen_args+=("--palette" "vibrant")
        ;;
    -p | --pastel)
        matugen_args+=("--palette" "pastel")
        ;;
    -m | --mono)
        matugen_args+=("--palette" "neutral")
        ;;
    -d | --dark)
        matugen_args+=("--mode" "dark")
        ;;
    -l | --light)
        matugen_args+=("--mode" "light")
        ;;
    -c | --custom)
        echo "Warning: Custom color curves (-c) are deprecated with matugen and will be ignored." >&2
        shift # Ignore the curve argument
        ;;
    *)
        # Stop parsing at the first non-option argument (the image path)
        break
        ;;
    esac
    shift
done

#// set variables
wallbashImg="${1}"
wallbashOut="${2:-"${wallbashImg}"}.dcol"
scrDir=$(dirname "$(realpath "$0")")
converter_script="${scrDir}/matugen_to_dcol.py"

#// input image validation
if [ -z "${wallbashImg}" ] || [ ! -f "${wallbashImg}" ]; then
    echo "Error: Input file not found: ${wallbashImg}" >&2
    exit 1
fi

if ! command -v matugen &>/dev/null; then
    echo "Error: matugen command not found. Please install matugen." >&2
    exit 1
fi

if [ ! -f "${converter_script}" ]; then
    echo "Error: Conversion script not found: ${converter_script}" >&2
    exit 1
fi

#// Generate colors using the new system and write to output file
echo "Generating dcol palette with matugen for: ${wallbashImg}" >&2
if python3 "${converter_script}" "${wallbashImg}" "${matugen_args[@]}" >"${wallbashOut}"; then
    echo "Successfully created ${wallbashOut}" >&2
else
    echo "Error: Failed to generate dcol file." >&2
    # Clean up the potentially incomplete output file
    rm -f "${wallbashOut}"
    exit 1
fi