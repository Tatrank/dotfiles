#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1091
#|---/ /+--------------------------------+---/ /|#
#|--/ /-| Script to restore hyde configs |--/ /-|#
#|-/ /--| Prasanth Rangan                |-/ /--|#
#|/ /---+--------------------------------+/ /---|#

deploy_list() {

    while read -r lst; do

        if [ "$(awk -F '|' '{print NF}' <<<"${lst}")" -ne 5 ]; then
            continue
        fi
        # Skip lines that start with '#' or any space followed by '#'
        if [[ "${lst}" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        ovrWrte=$(awk -F '|' '{print $1}' <<<"${lst}")
        bkpFlag=$(awk -F '|' '{print $2}' <<<"${lst}")
        pth=$(awk -F '|' '{print $3}' <<<"${lst}")
        pth=$(eval echo "${pth}")
        cfg=$(awk -F '|' '{print $4}' <<<"${lst}")
        pkg=$(awk -F '|' '{print $5}' <<<"${lst}")

        while read -r pkg_chk; do
            if ! pkg_installed "${pkg_chk}"; then
                echo -e "\033[0;33m[skip]\033[0m ${pth}/${cfg} as dependency ${pkg_chk} is not installed..."
                continue 2
            fi
        done < <(echo "${pkg}" | xargs -n 1)

        echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
            if [[ -z "${pth}" ]]; then continue; fi
            tgt="${pth/#$HOME/}"
            crnt_cfg="${pth}/${cfg_chk}"

            if { [ -d "${crnt_cfg}" ] || [ -f "${crnt_cfg}" ]; } && [ "${bkpFlag}" == "Y" ]; then

                if [ ! -d "${BkpDir}${tgt}" ]; then
                    [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${BkpDir}${tgt}"
                fi

                if [ "${ovrWrte}" == "Y" ]; then
                    [[ ${flg_DryRun} -ne 1 ]] && mv "${crnt_cfg}" "${BkpDir}${tgt}"
                else

                    [[ ${flg_DryRun} -ne 1 ]] && cp -r "${crnt_cfg}" "${BkpDir}${tgt}"
                fi
                echo -e "\033[0;34m[backup]\033[0m ${crnt_cfg} --> ${BkpDir}${tgt}..."
            fi

            if [ ! -d "${pth}" ]; then
                [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${pth}"
            fi

            if [ ! -f "${crnt_cfg}" ]; then
                [[ ${flg_DryRun} -ne 1 ]] && cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                echo -e "\033[0;32m[restore]\033[0m ${pth} <-- ${CfgDir}${tgt}/${cfg_chk}..."
            elif [ "${ovrWrte}" == "Y" ]; then
                [[ ${flg_DryRun} -ne 1 ]] && cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                echo -e "\033[0;33m[overwrite]\033[0m ${pth} <-- ${CfgDir}${tgt}/${cfg_chk}..."
            else
                echo -e "\033[0;33m[preserve]\033[0m Skipping ${crnt_cfg} to preserve user setting..."
            fi

            # Set executable permissions for scripts in bin and lib directories
            if [[ "${crnt_cfg}" == *".local/bin/"* || "${crnt_cfg}" == *".local/lib/hyde/"* ]]; then
                if [ -f "${crnt_cfg}" ] && [ "${flg_DryRun}" -ne 1 ]; then
                    chmod +x "${crnt_cfg}"
                    print_log -g "[permission]" -b " :: " "Made ${cfg_chk} executable."
                fi
            fi
        done

    done <<<"$(cat "${CfgLst}")"
}

deploy_psv() {
    print_log -g "[file extension]" -b " :: " "File: ${CfgLst}"
    while read -r lst; do

        # Skip lines that do not have exactly 4 columns
        if [ "$(awk -F '|' '{print NF}' <<<"${lst}")" -ne 4 ]; then
            if [[ "${lst}" =~ ^\  ]]; then
                echo ""
                print_log -b "${lst}"
            fi
            continue
        fi
        # Skip lines that start with '#' or any space followed by '#'
        if [[ "${lst}" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        ctlFlag=$(awk -F '|' '{print $1}' <<<"${lst}")
        pth=$(awk -F '|' '{print $2}' <<<"${lst}")
        pth=$(eval "echo ${pth}")
        cfg=$(awk -F '|' '{print $3}' <<<"${lst}")
        pkg=$(awk -F '|' '{print $4}' <<<"${lst}")

        # Check if ctlFlag is not one of the values 'O', 'R', 'B', 'S', or 'P'
        if [[ "${ctlFlag}" = "I" ]]; then
            print_log -r "[ignore] :: " "${pth}/${cfg}"
            continue 2
        fi

        while read -r pkg_chk; do
            if ! pkg_installed "${pkg_chk}"; then
                print_log -y "[skip] " -r "missing" -b " :: " -y "missing dependency" -g " '${pkg_chk}'" -r " --> " "${pth}/${cfg}"
                continue 2
            fi
        done < <(echo "${pkg}" | xargs -n 1)

        echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
            if [[ -z "${pth}" ]]; then continue; fi

            tgt="${pth//${HOME}/}"
            crnt_cfg="${pth}/${cfg_chk}"

            if [ ! -e "${CfgDir}${tgt}/${cfg_chk}" ] && [ "${ctlFlag}" != "B" ]; then
                print_log -y "[skip]" -b "no source" "${CfgDir}${tgt}/${cfg_chk} does not exist"
                continue
            fi

            [[ ! -d "${pth}" ]] && [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${pth}"

            if [ -e "${crnt_cfg}" ]; then
                [[ ! -d "${BkpDir}${tgt}" ]] && [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${BkpDir}${tgt}"

                case "${ctlFlag}" in
                "B")
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${crnt_cfg}" "${BkpDir}${tgt}"
                    print_log -g "[copy backup]" -b " :: " "${crnt_cfg} --> ${BkpDir}${tgt}..."
                    ;;
                "O")
                    [ "${flg_DryRun}" -ne 1 ] && mv "${crnt_cfg}" "${BkpDir}${tgt}"
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                    print_log -r "[move to backup]" " > " -r "[overwrite]" -b " :: " "${pth}" -r " <-- " "${CfgDir}${tgt}/${cfg_chk}"
                    ;;
                "S")
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${crnt_cfg}" "${BkpDir}${tgt}"
                    [ "${flg_DryRun}" -ne 1 ] && cp -rf "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                    print_log -g "[copy to backup]" " > " -y "[sync]" -b " :: " "${pth}" -r " <--  " "${CfgDir}${tgt}/${cfg_chk}"
                    ;;
                "P")
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${crnt_cfg}" "${BkpDir}${tgt}"
                    if ! [ "${flg_DryRun}" -ne 1 ] && cp -rn "${CfgDir}${tgt}/${cfg_chk}" "${pth}" 2>/dev/null; then
                        print_log -g "[copy to backup]" " > " -y "[populate]" -b " :: " "${pth}${tgt}/${cfg_chk}"
                    else
                        print_log -g "[copy to backup]" " > " -y "[preserved]" -b " :: " "${pth}" + 208 " <--  " "${CfgDir}${tgt}/${cfg_chk}"
                    fi
                    ;;
                esac
            else
                if [ "${ctlFlag}" != "B" ]; then
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                    print_log -y "[*populate*]" -b " :: " "${pth}" -r " <--  " "${CfgDir}${tgt}/${cfg_chk}"
                fi
            fi

            # Set executable permissions for scripts in bin and lib directories
            if [[ "${crnt_cfg}" == *".local/bin/"* || "${crnt_cfg}" == *".local/lib/hyde/"* ]]; then
                if [ -f "${crnt_cfg}" ] && [ "${flg_DryRun}" -ne 1 ]; then
                    chmod +x "${crnt_cfg}"
                    print_log -g "[permission]" -b " :: " "Made ${cfg_chk} executable."
                fi
            fi

        done

    done <"${1}"
}

# shellcheck disable=SC2034
log_section="deploy"
flg_DryRun=${flg_DryRun:-0}

scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

[ -f "${scrDir}/restore_cfg.lst" ] && defaultLst="restore_cfg.lst"
[ -f "${scrDir}/restore_cfg.psv" ] && defaultLst="restore_cfg.psv"
[ -f "${scrDir}/restore_cfg.json" ] && defaultLst="restore_cfg.json"
[ -f "${scrDir}/${USER}-restore_cfg.psv" ] && defaultLst="$USER-restore_cfg.psv"

CfgLst="${1:-"${scrDir}/${defaultLst}"}"
CfgDir="${2:-${cloneDir}/Configs}"
ThemeOverride="${3:-}"

if [ ! -f "${CfgLst}" ] || [ ! -d "${CfgDir}" ]; then
    echo "ERROR: '${CfgLst}' or '${CfgDir}' does not exist..."
    exit 1
fi

BkpDir="${HOME}/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')${ThemeOverride}"

if [ -d "${BkpDir}" ]; then
    echo "ERROR: ${BkpDir} exists!"
    exit 1
else
    [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${BkpDir}"
fi

file_extension="${CfgLst##*.}"
echo ""
print_log -g "[file extension]" -b " :: " "${file_extension}"
case "${file_extension}" in
"lst")
    deploy_list "${CfgLst}"
    ;;
"psv")
    deploy_psv "${CfgLst}"
    ;;
json)
    deploy_json "${CfgLst}"
    ;;
esac
echo ""
