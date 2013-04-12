#!/bin/bash
##
# Creates a SPARK AMI
#
# Requirements:
#
#   - Run on a Debian Squeeze box on EC2
#   - AWS Toolbox installed and configured
#     (https://github.com/jakajancar/aws-toolbox)
#
# Notes:
#
#   - only enables HTTP, relies on load balancer to handle HTTPS termination
#
# Sources:
#
#   - http://ec2-downloads.s3.amazonaws.com/user_specified_kernels.pdf
#   - https://github.com/tomheady/ec2debian/wiki/64bit-ebs-ami-pvgrub
#   - https://forums.aws.amazon.com/thread.jspa?messageID=223527
##

# Error handling
set -eu -o pipefail
APP_ROOT=$(dirname $(dirname $(dirname $(readlink -e $0))))

fail() {
    echo "$(basename $0): error: $1" >&2
    exit 1
}

MODULE_NAME="build-ami"
MODULE_DESCRIPTION="Create Amazon AWS AMI"

base-ami-hash() {
    cd "$AMI_ROOT"
    find ./ -exec sh -c "if [ -f '{}' ]; then cat '{}'; else echo '{}'; fi" \; | md5sum | cut -d' ' -f1
}

# Paths
AMI_ROOT=$APP_ROOT/ami/root

# Options, positional params and env vars
EC2_REGION=us-east-1
EC2_ARCH=x86_64
BATCH=0
BASE_IMAGE_CACHE_DIR=
AMI_ID_FILE=
S3_BUCKET=celtra-test-ami
SPARK_VERSION="v0.6.2"
VERSION=2

while getopts ":hr:a:B:bc:o:" opt; do
    case $opt in
        h)
            cat <<EOF
Usage: $0 [OPTION...] [image-suffix]

Creates and uploads an AMI image for the application server.

Options:
  -h                show this help
  -r <region>       EC2 region (default: us-east-1)
  -a <arch>         EC2 architecture, x86_64 or i386 (default: x86_64)
  -b                batch mode (no interactive prompts)
  -c <path>         directory in which to cache base images
  -o <file>         write ami-id to file
  -B <bucket>       where to save AMI, defaults to celtra-ami

Environment vars:
  TMPDIR            temporary directory (default: /tmp)
EOF
            exit 0
            ;;
        r) EC2_REGION=$OPTARG ;;
        a) EC2_ARCH=$OPTARG ;;
        b) BATCH=1 ;;
        B) S3_BUCKET=$OPTARG ;;
        c) BASE_IMAGE_CACHE_DIR=$OPTARG ;;
        o) AMI_ID_FILE=$OPTARG ;;
       \?) fail "invalid option: -$OPTARG" ;;
        :) fail "option -$OPTARG requires an argument." ;;
    esac
done
shift $((OPTIND-1))
IMAGE_SUFFIX=${1:-}
TMPDIR=${TMPDIR:-/tmp}

# Create temporary directory
TMPDIR="$TMPDIR/$(basename $0).$$"
mkdir $TMPDIR
cleanup() {
    umount -dl $TMPDIR/chroot 2>/dev/null || true
    rm -rf $TMPDIR 2>/dev/null
}
trap cleanup EXIT

# Check requirements
for tool in apt-get mkfs.ext3 chroot ec2-bundle-image ec2-upload-bundle ec2-register git
do
    which $tool >/dev/null || fail "\`$tool' is not installed or not in PATH."
done

if [ "$USER" != "root" ]
then
    echo "Run as root/sudo or it just won't work"
    exit 1
fi

# Decide on image name (pattern: appserver-x86_64-r1234M_20110719121201-suffix)
#  - base
IMAGE_NAME="spark-0.6.2"

#  - revision
#VERSION="$( cd $APP_ROOT; git rev-parse HEAD | cut -b 1-10 )"
#VERSION=$(base-ami-hash)
#if [ $(cd $APP_ROOT; git status --porcelain | wc -l) -ne 0 ]
#then
#    VERSION+="_$(date +%Y%m%d%H%I%S)"
#    echo "Working copy has modifications (version will be '$VERSION'):"
#    echo
#    (cd "$APP_ROOT"; git status)
#    echo
#    
#    if [ $BATCH != 1 ]
#    then
#        echo "Continue? (ctrl-c to cancel)"
#        read
#    fi
#fi
IMAGE_NAME+="-$VERSION"

#  - suffix
if [ "x$IMAGE_SUFFIX" != "x" ]
then
    IMAGE_NAME+="-$IMAGE_SUFFIX"
fi

# Real stuff

echo "Creating image $IMAGE_NAME in $EC2_REGION"
echo "---------------------------------------------------------------------------"

START=$(date +%s)

CHROOT="$TMPDIR/chroot/"
mkdir -p $CHROOT
function c() {
    env -i TERM=$TERM PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" $(which chroot) $CHROOT "$@"
}

#
# Create base image if it doesn't exist.
#
# If BASE_IMAGE_CACHE_DIR is not set, just build it in the TMPDIR.
#
# Warning:
# Only stuff from install/ should be used here, not from the rest of the working
# copy, or caching will not work correctly!
#

BASE_IMAGE_PATH="${BASE_IMAGE_CACHE_DIR:-$TMPDIR}/base-$(base-ami-hash).img"
if [ -e $BASE_IMAGE_PATH ]
then
    echo "Using an existing base image."
else
    echo "Preparing a new base image:"
    
    echo "  - Allocating space..."
    touch $BASE_IMAGE_PATH.inprogress # here to emit error, since dd is silenced
    dd if=/dev/zero of=$BASE_IMAGE_PATH.inprogress bs=1M count=2048 >/dev/null 2>&1
    
    echo "  - Formatting..."
    mkfs.ext3 -q -F $BASE_IMAGE_PATH.inprogress
    
    echo "  - Mounting..."
    mount -o loop $BASE_IMAGE_PATH.inprogress $CHROOT
    
    echo "  - Installing base OS..."
    export DEBIAN_FRONTEND=noninteractive
    
    debootstrap \
        --arch amd64 \
        --include=locales \
        --exclude=isc-dhcp-client,isc-dhcp-common,dhcp3-client \
        squeeze $CHROOT http://ftp.us.debian.org/debian \
        >/dev/null
    
    echo "  - Copying over config files and scripts..."
    tar -C "$AMI_ROOT" --owner=root --group=root --exclude .git --exclude '*~' -cf - . | tar -C $CHROOT -xpf -
    
    echo "  - Generating locales..."
    c locale-gen >/dev/null
    
    echo "  - Enabling init scripts..."
    c insserv ec2-get-credentials
    c insserv ec2-set-hostname
    c insserv firstboot-setup
    c insserv spark
    
    echo "  - Mounting /proc, /sys and /dev/pts..."
    c mount /proc
    c mount /sys
    c mount -t devpts none /dev/pts
    
    echo "  - Updating and upgrading base packages..."
    c apt-get -yqq update
    c apt-get -yqq dist-upgrade >/dev/null
    
    echo "  - Installing packages..."
    PACKAGES=""
    PACKAGES+=" linux-image-xen-amd64 dhcpcd resolvconf openssh-server"                                             # base
    PACKAGES+=" sudo joe less zip unzip host iptraf curl vim"                                                       # admin tools
    PACKAGES+=" psmisc strace lsof ntp sun-java6-jdk"                                                               # more admin tools

    # Prevent launch of servers during apt-get install
    echo "exit 101" > $CHROOT/usr/sbin/policy-rc.d
    chmod 755 $CHROOT/usr/sbin/policy-rc.d
    echo "sun-java6-jre shared/accepted-sun-dlj-v1-1 select true" | c /usr/bin/debconf-set-selections
    c apt-get -y -o Dpkg::Options::="--force-confold" install $PACKAGES > $TMPDIR/base-ami.log
    c apt-get -yqq remove avahi-daemon >/dev/null
    c dpkg --purge avahi-daemon >/dev/null

    echo "  - Installing SumoLogic Collector"
    wget -q "http://files.celtra.com.s3.amazonaws.com/sumologic/sumocollector_19.36-6_amd64.deb" -O $CHROOT/tmp/sumocollector_19.36-6_amd64.deb
    # Install will bork if we have wrapper.conf already in place
    c rm -fr /opt/SumoCollector
    c dpkg -i /tmp/sumocollector_19.36-6_amd64.deb > /dev/null
    cp "$AMI_ROOT/opt/SumoCollector/config/wrapper.conf" $CHROOT/opt/SumoCollector/config/wrapper.conf
    c usermod -a -G adm sumo
    c insserv -d collector

    echo "  - Installing Spark ${SPARK_VERSION}"
    git clone -q https://github.com/mesos/spark.git $TMPDIR/spark
    
    cd $TMPDIR/spark
    git checkout -q $SPARK_VERSION
    sbt/sbt package > /dev/null
    rm -fr .git
    cp -rp $TMPDIR/spark $CHROOT/opt/ > /dev/null
    
    echo "  - Installing Scala 2.9.2"
    wget http://www.scala-lang.org/downloads/distrib/files/scala-2.9.2.tgz -o /dev/null -O $TMPDIR/scala-2.9.2.tgz
    cd $CHROOT/opt
    tar xzf $TMPDIR/scala-2.9.2.tgz
    cd - > /dev/null
    
    rm $CHROOT/usr/sbin/policy-rc.d
    # There's no hwclock on Xen
    c insserv --remove hwclockfirst.sh >/dev/null
    c insserv --remove hwclock.sh >/dev/null

    echo "  - Configuring Grub..."
    # Since we use pvgrub we don't actually have to install grub, just provide a config file for it.
    mkdir -p $CHROOT/boot/grub
    cat <<EOF >$CHROOT/boot/grub/menu.lst
default 0
timeout 1
title Debian GNU/Linux
    root   (hd0)
    kernel /boot/$(cd $CHROOT/boot; ls vmlinuz-* | head -1) root=/dev/xvda1
    initrd /boot/$(cd $CHROOT/boot; ls initrd.img-* | head -1)
EOF
    
    echo "  - Cleaning up..."
    c apt-get -yqq autoremove --purge >/dev/null
    c apt-get -yqq clean
    # should be empty, since tmpfs is mounted over it on boot
    rm -fr $CHROOT/lib/init/rw/*
    rm -f $CHROOT/root/.ssh/authorized_keys
    rm -rf $CHROOT/tmp/*
    rm -f $CHROOT/etc/hostname
    
    echo "  - Unmounting /proc, /sys and /dev/pts..."
    c umount /proc
    c umount /sys
    c umount /dev/pts
    
    echo "  - Unmounting..."
    umount -d $CHROOT
    
    echo "  - Finalizing..."
    mv $BASE_IMAGE_PATH.inprogress $BASE_IMAGE_PATH
fi

#
# Copy the base image (if BASE_IMAGE_CACHE_DIR is not used, just move it, to be faster)
#
$( [ -z $BASE_IMAGE_CACHE_DIR ] && echo mv || echo cp ) $BASE_IMAGE_PATH $TMPDIR/root.img

echo "Creating a bundle..."
declare -A akis=( ["us-east-1_x86_64"]="aki-427d952b" ["us-west-1_x86_64"]="aki-9ba0f1de" ["eu-west-1_x86_64"]="aki-4feec43b" ["ap-southeast-1_x86_64"]="aki-4feec43b" ["ap-northeast-1_x86_64"]="aki-d409a2d5" ["us-east-1_i386"]="aki-407d9529" ["us-west-1_i386"]="aki-99a0f1dc" ["eu-west-1_i386"]="aki-4deec439" ["ap-southeast-1_i386"]="aki-13d5aa41" ["ap-northeast-1_i386"]="aki-d209a2d3" )
AKI="${akis[${EC2_REGION}_${EC2_ARCH}]}"
mkdir $TMPDIR/bundle
ec2-bundle-image \
    --batch \
    --prefix $IMAGE_NAME \
    --image $TMPDIR/root.img \
    --destination $TMPDIR/bundle \
    --arch $EC2_ARCH \
    --kernel ${AKI} \
    --block-device-mapping ami=sda1,root=/dev/sda1,ephemeral0=sda2 \
    >/dev/null

echo "Uploading the bundle..."
declare -A locations=( ["us-east-1"]="US" ["us-west-1"]="us-west-1" ["eu-west-1"]="EU" ["ap-southeast-1"]="ap-southeast-1" ["ap-northeast-1"]="ap-northeast-1" )
LOCATION="${locations[${EC2_REGION}]}"

ec2-upload-bundle \
    --location $LOCATION \
    --manifest $TMPDIR/bundle/$IMAGE_NAME.manifest.xml \
    --bucket $S3_BUCKET/$IMAGE_NAME \
    --retry \
    >/dev/null

echo "Registering the AMI..."
ec2-register \
    --region ${EC2_REGION} \
    $S3_BUCKET/$IMAGE_NAME/$IMAGE_NAME.manifest.xml \
    --name ${IMAGE_NAME} \
    --description ${IMAGE_NAME} \
    >$TMPDIR/ret
IMAGE=$(cut -f 2 <$TMPDIR/ret)

echo "Cleaning up..."
rm -r $TMPDIR

echo "Successfully created $IMAGE ($IMAGE_NAME), total time: $[ ($(date +%s)-$START)/60+1 ] minutes"

if [ -n "$AMI_ID_FILE" ]
then
    echo -e "AMI_ID\t$IMAGE" >$AMI_ID_FILE
fi
