#!/bin/bash
export BUILD_DATETIME=""
export BUILD_DEVICE=""
export BUILD_ENV_SEQUENCE_NUMBER=""
export BUILD_ID=""
export BUILD_NUMBER=""
export BUILD_INCLUDE_UPDATER=""
export OFFICIAL_BUILD=""
MODIFY_BUILD_ID=0
MODIFY_PROP_MAX=0
SET_COMBO=0
MODIFY_UPDATE_URL=""

copperhead_sh__usage () {
    while [ $# -gt 0 ]; do echo "$1" >&2; shift; done
    echo "usage: source $(basename ${BASH_SOURCE[0]}) [options]"
    echo
    echo "options:"
    echo "    -t epoch     set BUILD_DATETIME"
    echo "    -d device    set BUILD_DEVICE"
    echo "    -s number    set BUILD_ENV_SEQUENCE_NUMBER"
    echo "    -i id        set BUILD_ID"
    echo "    -n Y.M.D.P   set BUILD_NUMBER"
    echo "    -u           set BUILD_INCLUDE_UPDATER"
    echo "    -U url       modify updater endpoint (implies -u)"
    echo "    -b           modify build/make/core/build_id.mk"
    echo "    -P           modify PROP_VALUE_MAX to 196"
    echo "    -c           set choosecombo"
    echo "    -O           set OFFICIAL_BUILD (implies -u)"
    return 1
}

trap "unset -f -n copperhead_sh__usage" RETURN EXIT

if [ "${BASH_SOURCE[0]}" == "${0}" ]
then
    copperhead_sh__usage "bash the source luke, don't execute"
    exit 1
fi

while [ $# -gt 0 ]
do
    case "$1" in
        "-h"|"--help")
            copperhead_sh__usage
            return 1
            ;;
        "-t"|"--datetime")
            if [ -n "$2" ]
            then
                export BUILD_DATETIME="$2"
                echo "export BUILD_DATETIME=${BUILD_DATETIME}"
                shift
            else
                copperhead_sh__usage "-t requires a value"
                return 1
            fi
            ;;
        "-d"|"--device")
            if [ -n "$2" ]
            then
                export BUILD_DEVICE="$2"
                echo "export BUILD_DEVICE=${BUILD_DEVICE}"
                shift
            else
                copperhead_sh__usage "-d requires a value"
                return 1
            fi
            ;;
        "-s"|"--sequence")
            if [ -n "$2" ]
            then
                export BUILD_ENV_SEQUENCE_NUMBER="$2"
                echo "export BUILD_ENV_SEQUENCE_NUMBER=${BUILD_ENV_SEQUENCE_NUMBER}"
                shift
            else
                copperhead_sh__usage "-s requires a value"
                return 1
            fi
            ;;
        "-i"|"--id")
            if [ -n "$2" ]
            then
                export BUILD_ID="$2"
                echo "export BUILD_ID=${BUILD_ID}"
                shift
            else
                copperhead_sh__usage "-i requires a value"
                return 1
            fi
            ;;
        "-n"|"--number")
            if [ -n "$2" ]
            then
                export BUILD_NUMBER="$2"
                echo "export BUILD_NUMBER=${BUILD_NUMBER}"
                shift
            else
                copperhead_sh__usage "-n requires a value"
                return 1
            fi
            ;;
        "-u"|"--updater")
            export BUILD_INCLUDE_UPDATER=true
            echo "export BUILD_INCLUDE_UPDATER=${BUILD_INCLUDE_UPDATER}"
            ;;
        "-U"|"--update-url")
            if [ -z "$2" ]
            then
                copperhead_sh__usage "-U requires a URL"
                return 1
            fi
            MODIFY_UPDATE_URL="$(echo "$2" | perl -pe 's!/??$!/!')"
            export BUILD_INCLUDE_UPDATER=true
            echo "export BUILD_INCLUDE_UPDATER=${BUILD_INCLUDE_UPDATER}"
            ;;
        "-b"|"--build_id_mk")
            MODIFY_BUILD_ID=1
            ;;
        "-P"|"--prop_max")
            MODIFY_PROP_MAX=1
            ;;
        "-c"|"--setcombo")
            SET_COMBO=1
            ;;
        "-O"|"--official")
            export OFFICIAL_BUILD=true
            echo "export OFFICIAL_BUILD=${OFFICIAL_BUILD}"
            export BUILD_INCLUDE_UPDATER=true
            echo "export BUILD_INCLUDE_UPDATER=${BUILD_INCLUDE_UPDATER}"
            ;;
    esac
    shift
done

# include the AOSP environment
source build/envsetup.sh

export LC_COLLATE=C
export LANG=C
export _JAVA_OPTIONS=-XX:-UsePerfData
export DISPLAY_BUILD_NUMBER=true
echo "${PATH}" | grep -q "${PWD}/script/bin"
[ $? -ne 0 ] && export PATH="$PWD/script/bin:$PATH"

if [ -z "${BUILD_NUMBER}" ]
then
    if [ -f out/build_number.txt ]
    then
        export BUILD_NUMBER=$(cat out/build_number.txt 2>/dev/null)
    elif [ -n "${BUILD_ENV_SEQUENCE_NUMBER}" ]
    then
        export BUILD_NUMBER=$(date --utc +%Y.%m.%d.${BUILD_ENV_SEQUENCE_NUMBER})
    else
        export BUILD_NUMBER=$(date --utc +%Y.%m.%d.%H)
    fi
    echo "export BUILD_NUMBER=${BUILD_NUMBER}"
fi

if [ -z "${BUILD_DATETIME}" ]
then
    if [ -f out/build_date.txt ]
    then
        export BUILD_DATETIME=$(cat out/build_date.txt)
    else
        export -n BUILD_DATETIME
    fi
    echo "export BUILD_DATETIME=${BUILD_DATETIME}"
fi

export BUILD_TAG="refs/tags/${BUILD_ID}.${BUILD_NUMBER}"
echo "export BUILD_TAG=${BUILD_TAG}"

if [ $SET_COMBO -eq 1 ]
then
    choosecombo release aosp_${BUILD_DEVICE} user
fi

if [ $MODIFY_BUILD_ID -eq 1 ]
then
    grep -q "export BUILD_ID=${BUILD_ID}" \
         build/core/build_id.mk
    if [ $? -ne 0 ]
    then
        echo "Updating: build/core/build_id.mk"
        perl -i -pe \
             "s~export BUILD_ID=\S+~export BUILD_ID=${BUILD_ID}~" \
             build/core/build_id.mk
    else
        echo "Skipping: build/core/build_id.mk"
    fi
fi

if [ $MODIFY_PROP_MAX -eq 1 ]
then
    grep -q "PROP_VALUE_MAX = 195" \
         build/tools/post_process_props.py
    if [ $? -ne 0 ]
    then
        echo "Updating: build/tools/post_process_props.py"
        perl -i -pe \
             "s~PROP_VALUE_MAX = \d+~PROP_VALUE_MAX = 195~" \
             build/tools/post_process_props.py
    else
        echo "Skipping: build/tools/post_process_props.py"
    fi

    grep -q "#define PROP_VALUE_MAX  196" \
         bionic/libc/include/sys/system_properties.h
    if [ $? -ne 0 ]
    then
        echo "Updating: bionic/libc/include/sys/system_properties.h"
        perl -i -pe \
             "s~PROP_VALUE_MAX  \d+~PROP_VALUE_MAX 196~" \
             bionic/libc/include/sys/system_properties.h
    else
        echo "Skipping: bionic/libc/include/sys/system_properties.h"
    fi

    grep -q "kPropertyValueMax = 196u" \
         frameworks/native/cmds/installd/installd_deps.h
    if [ $? -ne 0 ]
    then
        echo "Updating: frameworks/native/cmds/installd/installd_deps.h"
        perl -i -pe \
             "s~kPropertyValueMax = \d+u~kPropertyValueMax = 196u~" \
             frameworks/native/cmds/installd/installd_deps.h
    else
        echo "Skipping: frameworks/native/cmds/installd/installd_deps.h"
    fi

    grep -q "char ssrvalue\[PROPERTY_VALUE_MAX\]" \
         hardware/qcom/bt/msm8992/libbt-vendor/src/hci_smd.c
    if [ $? -ne 0 ]
    then
        echo "Updating: hardware/qcom/bt/msm8992/libbt-vendor/src/hci_smd.c"
        perl -i -pe \
             "s~char ssrvalue\[\d+\]~char ssrvalue[PROPERTY_VALUE_MAX]~" \
             hardware/qcom/bt/msm8992/libbt-vendor/src/hci_smd.c
    else
        echo "Skipping: hardware/qcom/bt/msm8992/libbt-vendor/src/hci_smd.c"
    fi
fi

if [ -n "${MODIFY_UPDATE_URL}" ]
then
    grep -q "${MODIFY_UPDATE_URL}" packages/apps/Updater/res/values/config.xml
    if [ $? -ne 0 ]
    then
        echo "Modifying: packages/apps/Updater/res/values/config.xml"
        echo "Using Updater URL: ${MODIFY_UPDATE_URL}"
        perl -i -pe "s@https://release.copperhead.co/@${MODIFY_UPDATE_URL}@g" \
             packages/apps/Updater/res/values/config.xml
    else
        echo "Skipping: packages/apps/Updater/res/values/config.xml"
    fi
fi

if [ -f "external/chromium/prebuilt/arm64/MonochromePublic.apk" ]
then
    echo "Found: external/chromium/prebuilt/arm64/MonochromePublic.apk"
else
    echo "ERROR: Missing external/chromium/prebuilt/arm64/MonochromePublic.apk" 1>&2
fi

chrt -b -p 0 $$
export -p | egrep '\s(OFFICIAL|BUILD)_' | sed -e 's/declare -x //'

return 0
