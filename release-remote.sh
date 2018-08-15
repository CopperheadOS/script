#!/bin/bash

KEY_DIR=keys/$1
OUT=out/release-$1-$BUILD_NUMBER

source device/common/clear-factory-images-variables.sh

get_radio_image() {
  grep -Po "require version-$1=\K.+" vendor/$2/vendor-board-info.txt | tr '[:upper:]' '[:lower:]'
}

if [[ $1 == bullhead ]]; then
  BOOTLOADER=$(get_radio_image bootloader lge/$1)
  RADIO=$(get_radio_image baseband lge/$1)
  PREFIX=aosp_
elif [[ $1 == angler ]]; then
  BOOTLOADER=$(get_radio_image bootloader huawei/$1)
  RADIO=$(get_radio_image baseband huawei/$1)
  PREFIX=aosp_
elif [[ $1 == marlin || $1 == sailfish || $1 == taimen || $1 == walleye ]]; then
  BOOTLOADER=$(get_radio_image bootloader google_devices/$1)
  RADIO=$(get_radio_image baseband google_devices/$1)
  PREFIX=aosp_
elif [[ $1 == hikey || $1 == hikey960 ]]; then
  :
else
  user_error
fi

BUILD=$BUILD_NUMBER
VERSION=$(grep -Po "export BUILD_ID=\K.+" build/core/build_id.mk | tr '[:upper:]' '[:lower:]')
DEVICE=$1
PRODUCT=$1

mkdir -p $OUT || exit 1

TARGET_FILES=$DEVICE-target_files-$BUILD.zip

if [[ $DEVICE != hikey* ]]; then
  if [[ $DEVICE != taimen && $DEVICE != walleye ]]; then
    VERITY_SWITCHES=(--replace_verity_public_key "$KEY_DIR/verity_key.pub" --replace_verity_private_key "$KEY_DIR/verity"
                     --replace_verity_keyid "$KEY_DIR/verity.x509.pem")
  else
    VERITY_SWITCHES=(--avb_vbmeta_key "$KEY_DIR/avb.pem" --avb_vbmeta_algorithm SHA256_RSA2048
                     --avb_boot_key "$KEY_DIR/avb.pem" --avb_boot_algorithm SHA256_RSA2048
                     --avb_dtbo_key "$KEY_DIR/avb.pem" --avb_dtbo_algorithm SHA256_RSA2048
                     --avb_system_key "$KEY_DIR/avb.pem" --avb_system_algorithm SHA256_RSA2048
                     --avb_vendor_key "$KEY_DIR/avb.pem" --avb_vendor_algorithm SHA256_RSA2048
                    )
  fi
fi

if [[ $DEVICE == bullhead ]]; then
  EXTRA_OTA=(-b device/lge/bullhead/update-binary)
fi

build/tools/releasetools/sign_target_files_apks -o -d "$KEY_DIR" "${VERITY_SWITCHES[@]}" \
  $2 $OUT/$TARGET_FILES || exit 1

cp $OUT/$TARGET_FILES $OUT/$TARGET_FILES.bak

if [[ $DEVICE != hikey* ]]; then
  build/tools/releasetools/ota_from_target_files --block -k "$KEY_DIR/releasekey" "${EXTRA_OTA[@]}" $OUT/$TARGET_FILES \
    $OUT/$DEVICE-ota_update-$BUILD.zip || exit 1
fi

build/tools/releasetools/img_from_target_files -n $OUT/$TARGET_FILES \
  $OUT/$DEVICE-img-$BUILD.zip || exit 1

cd $OUT || exit 1

if [[ $DEVICE == hikey* ]]; then
  source ../../device/linaro/hikey/factory-images/generate-factory-images-$DEVICE.sh
else
  source ../../device/common/generate-factory-images-common.sh
fi

mv $TARGET_FILES.bak $TARGET_FILES
mv $DEVICE-$VERSION-factory.tar $DEVICE-factory-$BUILD_NUMBER.tar
rm -f $DEVICE-factory-$BUILD_NUMBER.tar.xz
xz -v --lzma2=dict=512MiB,lc=3,lp=0,pb=2,mode=normal,nice=64,mf=bt4,depth=0 $DEVICE-factory-$BUILD_NUMBER.tar
