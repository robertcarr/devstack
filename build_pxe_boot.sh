#!/bin/bash -e
# build_pxe_boot.sh - Create a PXE boot environment
#
# build_pxe_boot.sh [-k kernel-version] destdir
#
# Assumes syslinux is installed
# Assumes devstack files are in `pwd`/pxe
# Only needs to run as root if the destdir permissions require it

KVER=`uname -r`
if [ "$1" = "-k" ]; then
    KVER=$2
    shift;shift
fi

DEST_DIR=${1:-/tmp}/tftpboot
PXEDIR=${PXEDIR:-/var/cache/devstack/pxe}
OPWD=`pwd`
PROGDIR=`dirname $0`

mkdir -p $DEST_DIR/pxelinux.cfg
cd $DEST_DIR
for i in memdisk menu.c32 pxelinux.0; do
	cp -p /usr/lib/syslinux/$i $DEST_DIR
done

DEFAULT=$DEST_DIR/pxelinux.cfg/default
cat >$DEFAULT <<EOF
default menu.c32
prompt 0
timeout 0

MENU TITLE PXE Boot Menu

EOF

# Setup devstack boot
mkdir -p $DEST_DIR/ubuntu
if [ ! -d $PXEDIR ]; then
    mkdir -p $PXEDIR
fi
if [ ! -r $PXEDIR/vmlinuz-${KVER} ]; then
    sudo chmod 644 /boot/vmlinuz-${KVER}
    if [ ! -r /boot/vmlinuz-${KVER} ]; then
        echo "No kernel found"
    else
        cp -p /boot/vmlinuz-${KVER} $PXEDIR
    fi
fi
cp -p $PXEDIR/vmlinuz-${KVER} $DEST_DIR/ubuntu
if [ ! -r $PXEDIR/stack-initrd.gz ]; then
    cd $OPWD
    sudo $PROGDIR/build_pxe_ramdisk.sh $PXEDIR/stack-initrd.gz
fi
cp -p $PXEDIR/stack-initrd.gz $DEST_DIR/ubuntu
cat >>$DEFAULT <<EOF

LABEL devstack
    MENU LABEL ^devstack
    MENU DEFAULT
    KERNEL ubuntu/vmlinuz-$KVER
    APPEND initrd=ubuntu/stack-initrd.gz ramdisk_size=2109600 root=/dev/ram0
EOF

# Get Ubuntu
if [ -d $PXEDIR -a -r $PXEDIR/natty-base-initrd.gz ]; then
    cp -p $PXEDIR/natty-base-initrd.gz $DEST_DIR/ubuntu
    cat >>$DEFAULT <<EOF

LABEL ubuntu
    MENU LABEL ^Ubuntu Natty
    KERNEL ubuntu/vmlinuz-$KVER
    APPEND initrd=ubuntu/natty-base-initrd.gz ramdisk_size=419600 root=/dev/ram0
EOF
fi

# Local disk boot
cat >>$DEFAULT <<EOF

LABEL local
    MENU LABEL ^Local disk
    MENU DEFAULT
    LOCALBOOT 0
EOF
