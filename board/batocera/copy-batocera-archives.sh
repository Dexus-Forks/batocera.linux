#!/bin/bash -e

# PWD = source dir
# BASE_DIR = build dir
# BUILD_DIR = base dir/build
# HOST_DIR = base dir/host
# BINARIES_DIR = images dir
# TARGET_DIR = target dir

# XU4 SD/EMMC CARD
#
#       1      31      63          719     1231    1263
# +-----+-------+-------+-----------+--------+-------+----------+--------------+
# | MBR |  bl1  |  bl2  |   uboot   |  tzsw  |       |   BOOT   |     FREE     |
# +-----+-------+-------+-----------+--------+-------+----------+--------------+
#      512     15K     31K         359K     615K    631K       1.2G
#
# http://odroid.com/dokuwiki/doku.php?id=en:xu3_partition_table
# https://github.com/hardkernel/u-boot/blob/odroidxu3-v2012.07/sd_fuse/hardkernel/sd_fusing.sh

xu4_fusing() {
    BINARIES_DIR=$1
    BATOCERAIMG=$2

    # fusing
    signed_bl1_position=1
    bl2_position=31
    uboot_position=63
    tzsw_position=719
    env_position=1231

    echo "BL1 fusing"
    dd if="${BINARIES_DIR}/bl1.bin.hardkernel"    of="${BATOCERAIMG}" seek=$signed_bl1_position conv=notrunc || return 1

    echo "BL2 fusing"
    dd if="${BINARIES_DIR}/bl2.bin.hardkernel"    of="${BATOCERAIMG}" seek=$bl2_position        conv=notrunc || return 1

    echo "u-boot fusing"
    dd if="${BINARIES_DIR}/u-boot.bin.hardkernel" of="${BATOCERAIMG}" seek=$uboot_position      conv=notrunc || return 1

    echo "TrustZone S/W fusing"
    dd if="${BINARIES_DIR}/tzsw.bin.hardkernel"   of="${BATOCERAIMG}" seek=$tzsw_position       conv=notrunc || return 1

    echo "u-boot env erase"
    dd if=/dev/zero of="${BATOCERAIMG}" seek=$env_position count=32 bs=512 conv=notrunc || return 1
}

# C2 SD CARD
#
#       1       97         1281
# +-----+-------+-----------+--------+--------------+
# | MBR |  bl1  |   uboot   |  BOOT  |     FREE     |
# +-----+-------+-----------+--------+--------------+
#      512     48K         640K
#
# http://odroid.com/dokuwiki/doku.php?id=en:c2_building_u-boot

c2_fusing() {
    BINARIES_DIR=$1
    BATOCERAIMG=$2

    # fusing
    signed_bl1_position=1
    signed_bl1_skip=0
    uboot_position=97

    echo "BL1 fusing"
    dd if="${BINARIES_DIR}/bl1.bin.hardkernel" of="${BATOCERAIMG}" seek=$signed_bl1_position skip=$signed_bl1_skip conv=notrunc || return 1

    echo "u-boot fusing"
    dd if="${BINARIES_DIR}/u-boot.bin"         of="${BATOCERAIMG}" seek=$uboot_position                            conv=notrunc || return 1
}

BATOCERA_BINARIES_DIR="${BINARIES_DIR}/batocera"
BATOCERA_TARGET_DIR="${TARGET_DIR}/batocera"

if [ -d "${BATOCERA_BINARIES_DIR}" ]; then
    rm -rf "${BATOCERA_BINARIES_DIR}"
fi

mkdir -p "${BATOCERA_BINARIES_DIR}"

# XU4, RPI0, RPI1, RPI2 or RPI3
BATOCERA_TARGET=$(grep -E "^BR2_PACKAGE_BATOCERA_TARGET_[A-Z_0-9]*=y$" "${BR2_CONFIG}" | sed -e s+'^BR2_PACKAGE_BATOCERA_TARGET_\([A-Z_0-9]*\)=y$'+'\1'+)

echo -e "\n----- Generating images/batocera files -----\n"

case "${BATOCERA_TARGET}" in
    RPI0|RPI1|RPI2|RPI3)
	# boot.tar.xz
	cp -f "${BINARIES_DIR}/"*.dtb "${BINARIES_DIR}/rpi-firmware"
	rm -rf "${BINARIES_DIR}/rpi-firmware/boot"   || exit 1
	mkdir -p "${BINARIES_DIR}/rpi-firmware/boot" || exit 1
	cp "board/batocera/rpi/config.txt" "${BINARIES_DIR}/rpi-firmware/config.txt"   || exit 1
	cp "board/batocera/rpi/cmdline.txt" "${BINARIES_DIR}/rpi-firmware/cmdline.txt" || exit 1

	KERNEL_VERSION=$(grep -E "^BR2_LINUX_KERNEL_VERSION=" "${BR2_CONFIG}" | sed -e s+'^BR2_LINUX_KERNEL_VERSION="\(.*\)"$'+'\1'+)
	"${BUILD_DIR}/linux-${KERNEL_VERSION}/scripts/mkknlimg" "${BINARIES_DIR}/zImage" "${BINARIES_DIR}/rpi-firmware/boot/linux"
	cp "${BINARIES_DIR}/initrd.gz" "${BINARIES_DIR}/rpi-firmware/boot" || exit 1
	cp "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/rpi-firmware/boot/batocera.update" || exit 1
	echo "creating boot.tar.xz"
	tar -cJf "${BATOCERA_BINARIES_DIR}/boot.tar.xz" -C "${BINARIES_DIR}/rpi-firmware" "." ||
	    { echo "ERROR : unable to create boot.tar.xz" && exit 1 ;}

	# batocera.img
	# rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
	mv "${BINARIES_DIR}/rpi-firmware/boot/batocera.update" "${BINARIES_DIR}/rpi-firmware/boot/batocera" || exit 1
	GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
	BATOCERAIMG="${BATOCERA_BINARIES_DIR}/batocera.img"
	rm -rf "${GENIMAGE_TMP}" || exit 1
	cp "board/batocera/rpi/genimage.cfg" "${BINARIES_DIR}/genimage.cfg.tmp" || exit 1
	FILES=$(find "${BINARIES_DIR}/rpi-firmware" -type f | sed -e s+"^${BINARIES_DIR}/rpi-firmware/\(.*\)$"+"file \1 \{ image = 'rpi-firmware/\1' }"+ | tr '\n' '@')
	cat "${BINARIES_DIR}/genimage.cfg.tmp" | sed -e s+'@files'+"${FILES}"+ | tr '@' '\n' > "${BINARIES_DIR}/genimage.cfg" || exit 1
	rm -f "${BINARIES_DIR}/genimage.cfg.tmp" || exit 1
	echo "generating image"
	genimage --rootpath="${TARGET_DIR}" --inputpath="${BINARIES_DIR}" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
	rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
	sync || exit 1
	;;

    XU4)
	# dirty boot binary files
	for F in bl1.bin.hardkernel bl2.bin.hardkernel tzsw.bin.hardkernel u-boot.bin.hardkernel
	do
	    cp "${BUILD_DIR}/uboot-odroid-xu4-odroidxu3-v2012.07/sd_fuse/hardkernel/${F}" "${BINARIES_DIR}" || exit 1
	done

	# /boot
	rm -rf "${BINARIES_DIR}/boot"         || exit 1
	mkdir -p "${BINARIES_DIR}/boot/boot"  || exit 1
	cp "board/batocera/xu4/boot.ini"     "${BINARIES_DIR}/boot/boot.ini"        	 || exit 1
	cp "${BINARIES_DIR}/zImage"          "${BINARIES_DIR}/boot/boot/linux"      	 || exit 1
	cp "${BINARIES_DIR}/uInitrd"         "${BINARIES_DIR}/boot/boot/uInitrd"    	 || exit 1

	# develop mode : use ext2 instead of squashfs
	ROOTFSEXT2=0
	grep -qE "^BR2_TARGET_ROOTFS_EXT2=y$" "${BR2_CONFIG}" && ROOTFSEXT2=1
	if test "${ROOTFSEXT2}" = 1
	then
	    cp "${BINARIES_DIR}/rootfs.ext2" "${BINARIES_DIR}/boot/boot/batocera.update" || exit 1
	else
	    cp "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/boot/boot/batocera.update" || exit 1
	fi
	cp "${BINARIES_DIR}/exynos5422-odroidxu4.dtb" "${BINARIES_DIR}/boot/boot/exynos5422-odroidxu4.dtb" || exit 1
	cp "${BINARIES_DIR}/recalbox-boot.conf" "${BINARIES_DIR}/boot/recalbox-boot.conf"                  || exit 1

	# boot.tar.xz
	echo "creating boot.tar.xz"
	(cd "${BINARIES_DIR}/boot" && tar -cJf "${BATOCERA_BINARIES_DIR}/boot.tar.xz" boot.ini boot recalbox-boot.conf) || exit 1

	# batocera.img
	# rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
	mv "${BINARIES_DIR}/boot/boot/batocera.update" "${BINARIES_DIR}/boot/boot/batocera" || exit 1
	GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
	BATOCERAIMG="${BATOCERA_BINARIES_DIR}/batocera.img"
	rm -rf "${GENIMAGE_TMP}" || exit 1
	cp "board/batocera/xu4/genimage.cfg" "${BINARIES_DIR}" || exit 1
	echo "generating image"
	genimage --rootpath="${TARGET_DIR}" --inputpath="${BINARIES_DIR}/boot" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
	rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
	xu4_fusing "${BINARIES_DIR}" "${BATOCERAIMG}" || exit 1
	sync || exit 1
	;;

    LEGACYXU4)
	# dirty boot binary files
	for F in bl1.bin.hardkernel bl2.bin.hardkernel tzsw.bin.hardkernel u-boot.bin.hardkernel
	do
	    cp "${BUILD_DIR}/uboot-odroid-xu4-odroidxu3-v2012.07/sd_fuse/hardkernel/${F}" "${BINARIES_DIR}" || exit 1
	done

	# /boot
	rm -rf "${BINARIES_DIR}/boot"         || exit 1
	mkdir -p "${BINARIES_DIR}/boot/boot"  || exit 1
	cp "board/batocera/legacyxu4/boot.ini" "${BINARIES_DIR}/boot/boot.ini"        	 || exit 1
	cp "${BINARIES_DIR}/zImage"            "${BINARIES_DIR}/boot/boot/linux"      	 || exit 1
	cp "${BINARIES_DIR}/uInitrd"           "${BINARIES_DIR}/boot/boot/uInitrd"    	 || exit 1

	# develop mode : use ext2 instead of squashfs
	ROOTFSEXT2=0
	grep -qE "^BR2_TARGET_ROOTFS_EXT2=y$" "${BR2_CONFIG}" && ROOTFSEXT2=1
	if test "${ROOTFSEXT2}" = 1
	then
	    cp "${BINARIES_DIR}/rootfs.ext2" "${BINARIES_DIR}/boot/boot/batocera.update" || exit 1
	else
	    cp "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/boot/boot/batocera.update" || exit 1
	fi
	cp "${BINARIES_DIR}/exynos5422-odroidxu3.dtb" "${BINARIES_DIR}/boot/boot/exynos5422-odroidxu3.dtb" || exit 1
	cp "${BINARIES_DIR}/recalbox-boot.conf" "${BINARIES_DIR}/boot/recalbox-boot.conf"                  || exit 1

	# boot.tar.xz
	echo "creating boot.tar.xz"
	(cd "${BINARIES_DIR}/boot" && tar -cJf "${BATOCERA_BINARIES_DIR}/boot.tar.xz" boot.ini boot recalbox-boot.conf) || exit 1

	# batocera.img
	# rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
	mv "${BINARIES_DIR}/boot/boot/batocera.update" "${BINARIES_DIR}/boot/boot/batocera" || exit 1
	GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
	BATOCERAIMG="${BATOCERA_BINARIES_DIR}/batocera.img"
	rm -rf "${GENIMAGE_TMP}" || exit 1
	cp "board/batocera/legacyxu4/genimage.cfg" "${BINARIES_DIR}" || exit 1
	echo "generating image"
	genimage --rootpath="${TARGET_DIR}" --inputpath="${BINARIES_DIR}/boot" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
	rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
	xu4_fusing "${BINARIES_DIR}" "${BATOCERAIMG}" || exit 1
	sync || exit 1
	;;

    C2)
	# boot
	rm -rf ${BINARIES_DIR}/boot        || exit 1
	mkdir -p ${BINARIES_DIR}/boot/boot || exit 1
	cp board/batocera/c2/boot-logo.bmp.gz ${BINARIES_DIR}/boot   || exit 1
	cp "board/batocera/c2/boot.ini"       ${BINARIES_DIR}/boot   || exit 1
	cp "${BINARIES_DIR}/recalbox-boot.conf" "${BINARIES_DIR}/boot/recalbox-boot.conf" || exit 1
	cp "${BINARIES_DIR}/Image" "${BINARIES_DIR}/boot/boot/linux" || exit 1
	cp "${BINARIES_DIR}/meson64_odroidc2.dtb" "${BINARIES_DIR}/boot/boot" || exit 1
	cp "${BINARIES_DIR}/uInitrd"              "${BINARIES_DIR}/boot/boot" || exit 1
	cp "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/boot/boot/batocera.update" || exit 1

	# boot.tar.xz
	echo "creating boot.tar.xz"
	(cd "${BINARIES_DIR}/boot" && tar -cJf "${BATOCERA_BINARIES_DIR}/boot.tar.xz" boot.ini boot recalbox-boot.conf boot-logo.bmp.gz) || exit 1

	# batocera.img
        # rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
        mv "${BINARIES_DIR}/boot/boot/batocera.update" "${BINARIES_DIR}/boot/boot/batocera" || exit 1
	GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
	BATOCERAIMG="${BATOCERA_BINARIES_DIR}/batocera.img"
	rm -rf "${GENIMAGE_TMP}" || exit 1
	cp "board/batocera/c2/genimage.cfg" "${BINARIES_DIR}" || exit 1
	echo "generating image"
	genimage --rootpath="${TARGET_DIR}" --inputpath="${BINARIES_DIR}/boot" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
	rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
	c2_fusing "${BINARIES_DIR}" "${BATOCERAIMG}" || exit 1
	sync || exit 1
	;;

    S905)
	MKIMAGE=${HOST_DIR}/bin/mkimage
	BOARD_DIR="board/batocera/s905"
	# boot
	rm -rf ${BINARIES_DIR}/boot        || exit 1
	mkdir -p ${BINARIES_DIR}/boot/boot || exit 1
	cp ${BOARD_DIR}/boot-logo.bmp.gz ${BINARIES_DIR}/boot   || exit 1
	$MKIMAGE -C none -A arm64 -T script -d ${BOARD_DIR}/s905_autoscript.txt ${BINARIES_DIR}/boot/s905_autoscript
	$MKIMAGE -C none -A arm64 -T script -d ${BOARD_DIR}/aml_autoscript.txt ${BINARIES_DIR}/boot/aml_autoscript
	cp ${BOARD_DIR}/aml_autoscript.zip ${BINARIES_DIR}/boot     || exit 1
	cp "${BINARIES_DIR}/recalbox-boot.conf" "${BINARIES_DIR}/boot/recalbox-boot.conf" || exit 1
	cp "${BOARD_DIR}/README.txt" "${BINARIES_DIR}/boot/README.txt" || exit 1
	for DTB in gxbb_p200_2G.dtb  gxbb_p200.dtb  gxl_p212_1g.dtb  gxl_p212_2g.dtb all_merged.dtb
	do
	    cp "${BINARIES_DIR}/${DTB}" "${BINARIES_DIR}/boot/boot" || exit 1
	done

	cp "${BINARIES_DIR}/Image"           "${BINARIES_DIR}/boot/boot/linux"           || exit 1
	cp "${BINARIES_DIR}/uInitrd"         "${BINARIES_DIR}/boot/boot/uInitrd"    	 || exit 1
	cp "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/boot/boot/batocera.update" || exit 1

	# boot.tar.xz
	echo "creating boot.tar.xz"
	(cd "${BINARIES_DIR}/boot" && tar -cJf "${BATOCERA_BINARIES_DIR}/boot.tar.xz"  boot recalbox-boot.conf boot-logo.bmp.gz aml_autoscript.zip aml_autoscript s905_autoscript) || exit 1

	# batocera.img
        # rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
        mv "${BINARIES_DIR}/boot/boot/batocera.update" "${BINARIES_DIR}/boot/boot/batocera" || exit 1
	GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
	BATOCERAIMG="${BATOCERA_BINARIES_DIR}/batocera.img"
	rm -rf "${GENIMAGE_TMP}" || exit 1
	cp "${BOARD_DIR}/genimage.cfg" "${BINARIES_DIR}/genimage.cfg" || exit 1
	echo "generating image"
	genimage --rootpath="${TARGET_DIR}" --inputpath="${BINARIES_DIR}/boot" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
	rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
	sync || exit 1
	;;

    S912)
	MKIMAGE=${HOST_DIR}/bin/mkimage
	MKBOOTIMAGE=${HOST_DIR}/bin/mkbootimg
	BOARD_DIR="board/batocera/s912"
	# boot
	rm -rf ${BINARIES_DIR}/boot        || exit 1
	mkdir -p ${BINARIES_DIR}/boot/boot || exit 1
	cp ${BOARD_DIR}/boot-logo.bmp.gz ${BINARIES_DIR}/boot   || exit 1
	$MKIMAGE -C none -A arm64 -T script -d ${BOARD_DIR}/s905_autoscript.txt ${BINARIES_DIR}/boot/s905_autoscript
	$MKIMAGE -C none -A arm64 -T script -d ${BOARD_DIR}/aml_autoscript.txt ${BINARIES_DIR}/boot/aml_autoscript
	cp ${BOARD_DIR}/aml_autoscript.zip ${BINARIES_DIR}/boot     || exit 1
	cp "${BINARIES_DIR}/recalbox-boot.conf" "${BINARIES_DIR}/boot/recalbox-boot.conf" || exit 1
	cp "${BINARIES_DIR}/all_merged.dtb" "${BINARIES_DIR}/dtb.img" || exit 1
	$MKBOOTIMAGE --kernel "${BINARIES_DIR}/Image" --ramdisk "${BINARIES_DIR}/initrd" --second "${BINARIES_DIR}/dtb.img" --output "${BINARIES_DIR}/linux" || exit 1
       cp "${BINARIES_DIR}/linux" "${BINARIES_DIR}/boot/boot/linux" || exit 1

	cp "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/boot/boot/batocera.update" || exit 1

	# boot.tar.xz
	echo "creating boot.tar.xz"
	(cd "${BINARIES_DIR}/boot" && tar -cJf "${BATOCERA_BINARIES_DIR}/boot.tar.xz"  boot recalbox-boot.conf boot-logo.bmp.gz aml_autoscript.zip aml_autoscript s905_autoscript) || exit 1

	# batocera.img
        # rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
        mv "${BINARIES_DIR}/boot/boot/batocera.update" "${BINARIES_DIR}/boot/boot/batocera" || exit 1
	GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
	BATOCERAIMG="${BATOCERA_BINARIES_DIR}/batocera.img"
	rm -rf "${GENIMAGE_TMP}" || exit 1
	cp "${BOARD_DIR}/genimage.cfg" "${BINARIES_DIR}/genimage.cfg" || exit 1
	echo "generating image"
	genimage --rootpath="${TARGET_DIR}" --inputpath="${BINARIES_DIR}/boot" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
	rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
	sync || exit 1
	;;

    X86|X86_64)
	# /boot
	rm -rf ${BINARIES_DIR}/boot || exit 1
	mkdir -p ${BINARIES_DIR}/boot/grub || exit 1
	cp "board/batocera/grub2/grub.cfg" ${BINARIES_DIR}/boot/grub/grub.cfg || exit 1
	cp "${BINARIES_DIR}/bzImage" "${BINARIES_DIR}/boot/linux" || exit 1
	cp "${BINARIES_DIR}/initrd.gz" "${BINARIES_DIR}/boot" || exit 1
	cp "${BINARIES_DIR}/rootfs.squashfs" "${BINARIES_DIR}/boot/batocera.update" || exit 1

	# get UEFI files
	mkdir -p "${BINARIES_DIR}/EFI/BOOT" || exit 1
	cp "${BINARIES_DIR}/bootx64.efi" "${BINARIES_DIR}/EFI/BOOT" || exit 1
	cp "board/batocera/grub2/grub.cfg" "${BINARIES_DIR}/EFI/BOOT" || exit 1

	# boot.tar.xz
        # it must include the squashfs version with .update to not erase the current squashfs while running
	echo "creating ${BATOCERA_BINARIES_DIR}/boot.tar.xz"
	(cd "${BINARIES_DIR}" && tar -cJf "${BATOCERA_BINARIES_DIR}/boot.tar.xz" EFI boot recalbox-boot.conf) || exit 1

	# batocera.img
	# rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
	mv "${BINARIES_DIR}/boot/batocera.update" "${BINARIES_DIR}/boot/batocera" || exit 1
	GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
	BATOCERAIMG="${BATOCERA_BINARIES_DIR}/batocera.img"
	rm -rf "${GENIMAGE_TMP}" || exit 1
	cp "board/batocera/grub2/genimage.cfg" "${BINARIES_DIR}" || exit 1
	cp "${HOST_DIR}/usr/lib/grub/i386-pc/boot.img" "${BINARIES_DIR}" || exit 1
	echo "creating ${BATOCERA_BINARIES_DIR}/batocera.img"
	genimage --rootpath="${TARGET_DIR}" --inputpath="${BINARIES_DIR}" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
	rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
	sync || exit 1
	;;
    ROCKPRO64)
        # /boot
        rm -rf "${BINARIES_DIR}/boot"            || exit 1
        mkdir -p "${BINARIES_DIR}/boot/boot"     || exit 1
	mkdir -p "${BINARIES_DIR}/boot/extlinux" || exit 1
        cp "${BINARIES_DIR}/Image"                 "${BINARIES_DIR}/boot/boot/linux"                || exit 1
        cp "${BINARIES_DIR}/initrd.gz"             "${BINARIES_DIR}/boot/boot/initrd.gz"            || exit 1
        cp "${BINARIES_DIR}/rootfs.squashfs"       "${BINARIES_DIR}/boot/boot/batocera.update"      || exit 1
        cp "${BINARIES_DIR}/rk3399-rockpro64.dtb"  "${BINARIES_DIR}/boot/boot/rk3399-rockpro64.dtb" || exit 1
        cp "${BINARIES_DIR}/recalbox-boot.conf"    "${BINARIES_DIR}/boot/recalbox-boot.conf"        || exit 1
	cp "board/batocera/rockpro64/extlinux.conf" ${BINARIES_DIR}/boot/extlinux                   || exit 1
        # boot.tar.xz
        echo "creating boot.tar.xz"
        (cd "${BINARIES_DIR}/boot" && tar -cJf "${BATOCERA_BINARIES_DIR}/boot.tar.xz" extlinux boot recalbox-boot.conf) || exit 1

	# blobs
	for F in idbloader.img trust.img uboot.img
	do
	    cp "${BINARIES_DIR}/${F}" "${BINARIES_DIR}/boot/${F}" || exit 1
	done

        # batocera.img
        # rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
        mv "${BINARIES_DIR}/boot/boot/batocera.update" "${BINARIES_DIR}/boot/boot/batocera" || exit 1
        GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
        BATOCERAIMG="${BATOCERA_BINARIES_DIR}/batocera.img"
        rm -rf "${GENIMAGE_TMP}" || exit 1
        cp "board/batocera/rockpro64/genimage.cfg" "${BINARIES_DIR}" || exit 1
        echo "generating image"
        genimage --rootpath="${TARGET_DIR}" --inputpath="${BINARIES_DIR}/boot" --outputpath="${BATOCERA_BINARIES_DIR}" --config="${BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
        rm -f "${BATOCERA_BINARIES_DIR}/boot.vfat" || exit 1
        sync || exit 1
        ;;
*)
	echo "Outch. Unknown target ${BATOCERA_TARGET} (see copy-batocera-archives.sh)" >&2
	bash
	exit 1
esac

# common

# renaming
SUFFIXVERSION=$(cat "${TARGET_DIR}/usr/share/batocera/batocera.version" | sed -e s+'^\([0-9\.]*\).*$'+'\1'+) # xx.yy version
SUFFIXTARGET=$(echo "${BATOCERA_TARGET}" | tr A-Z a-z)
SUFFIXDATE=$(date +%Y%m%d)
SUFFIXIMG="-${SUFFIXVERSION}-${SUFFIXTARGET}-${SUFFIXDATE}"
mv "${BATOCERA_BINARIES_DIR}/batocera.img" "${BATOCERA_BINARIES_DIR}/batocera${SUFFIXIMG}.img" || exit 1

cp "${TARGET_DIR}/usr/share/batocera/batocera.version" "${BATOCERA_BINARIES_DIR}" || exit 1


# gzip image
gzip "${BATOCERA_BINARIES_DIR}/batocera${SUFFIXIMG}.img" || exit 1

#
for FILE in "${BATOCERA_BINARIES_DIR}/boot.tar.xz" "${BATOCERA_BINARIES_DIR}/batocera${SUFFIXIMG}.img.gz"
do
    echo "creating ${FILE}.md5"
    CKS=$(md5sum "${FILE}" | sed -e s+'^\([^ ]*\) .*$'+'\1'+)
    echo "${CKS}" > "${FILE}.md5"
done

# pcsx2 package
if grep -qE "^BR2_PACKAGE_PCSX2=y$" "${BR2_CONFIG}"
then
    echo "building the pcsx2 package..."
    ./board/batocera/doPcsx2package.sh "${TARGET_DIR}" "${BINARIES_DIR}/pcsx2" "${BATOCERA_BINARIES_DIR}" || exit 1
fi

exit 0
