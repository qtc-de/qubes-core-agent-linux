#!/bin/sh

# check if private.img (xvdb) is empty - all zeros
private_size_512=`blockdev --getsz /dev/xvdb`
if dd if=/dev/zero bs=512 count=$private_size_512 | diff /dev/xvdb - >/dev/null; then
    # the device is empty, create filesystem
    echo "--> Virgin boot of the VM: creating filesystem on private.img"
    mkfs.ext4 -m 0 -q /dev/xvdb || exit 1
fi

resize2fs /dev/xvdb 2> /dev/null || echo "'resize2fs /dev/xvdb' failed"
tune2fs -m 0 /dev/xvdb
mount /rw

if ! [ -d /rw/home ] ; then
    echo
    echo "--> Virgin boot of the VM: Populating /rw/home"

    mkdir -p /rw/config
    touch /rw/config/rc.local
    touch /rw/config/rc.local-early

    mkdir -p /rw/home
    cp -a /home.orig/user /rw/home

    mkdir -p /rw/usrlocal
    cp -a /usr/local.orig/* /rw/usrlocal

    touch /var/lib/qubes/first-boot-completed
fi

# Chown home if user UID have changed - can be the case on template switch
HOME_USER_UID=`ls -dn /rw/home/user | awk '{print $3}'`
if [ "`id -u user`" -ne "$HOME_USER_UID" ]; then
    find /rw/home/user -uid "$HOME_USER_UID" -print0 | xargs -0 chown user:user
fi

# Old Qubes versions had symlink /home -> /rw/home; now we use mount --bind
if [ -L /home ]; then
    rm /home
    mkdir /home
fi

if [ -e /var/run/qubes-service/qubes-dvm ]; then
    mount --bind /home_volatile /home
    touch /etc/this-is-dvm

    #If user have customized DispVM settings, use its home instead of default dotfiles
    if [ -e /rw/home/user/.qubes-dispvm-customized ]; then
        cp -af /rw/home/user /home/
    else
        cat /etc/dispvm-dotfiles.tbz | tar -xjf- --overwrite -C /home/user --owner user 2>&1 >/tmp/dispvm-dotfiles-errors.log
    fi
else
    mount /home
fi
