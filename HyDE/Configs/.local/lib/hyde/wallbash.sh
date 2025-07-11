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
        ;;
    -l | --light)
        sortMode="light"
        ;;
    *)
        break
        ;;
    esac
    shift
done

#// set variables

wallbashImg="${1}"
wallbashOut="${2:-"${wallbashImg}"}.dcol"

#// input image validation

if [ -z "${wallbashImg}" ] || [ ! -f "${wallbashImg}" ]; then
    echo "Error: Input file not found!"
    exit 1
fi

#// Setup cache directories
cacheDir="${cacheDir:-$XDG_CACHE_HOME/hyde}"
thmDir="${thmDir:-$cacheDir/thumbs}"
mkdir -p "${cacheDir}/${thmDir}"

#// Map colorProfile to palette arg for matugen
case "$colorProfile" in
    "vibrant")
        paletteArg="--palette vibrant"
        ;;
    "pastel")
        paletteArg="--palette pastel"
        ;;
    "mono")
        paletteArg="--palette neutral"
        ;;
    *)
        paletteArg="--palette default"
        ;;
esac

#// Map sortMode to mode arg for matugen
case "$sortMode" in
    "dark")
        modeArg="--mode dark"
        ;;
    "light")
        modeArg="--mode light"
        ;;
    *)
        modeArg="--mode auto"
        ;;
esac

echo -e "wallbash ${colorProfile} profile :: ${sortMode} :: Using matugen :: \"${wallbashOut}\""

#// Get the directory of the current script
scriptDir="$(dirname "$(readlink -f "$0")")"
matugenScript="${scriptDir}/matugen_to_dcol.py"

if [ ! -f "$matugenScript" ]; then
    echo "Error: matugen_to_dcol.py not found at $matugenScript"
    exit 1
fi

#// Run the Python script with the appropriate arguments
python3 "$matugenScript" "$wallbashImg" $paletteArg $modeArg

exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "Error: Failed to generate colors using matugen"
    exit $exit_code
fi

exit 0