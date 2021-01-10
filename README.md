parler-grab
=============

More information about the archiving project can be found on the ArchiveTeam wiki: [Parler](http://archiveteam.org/index.php?title=Parler)

Setup instructions
=========================

Be sure to replace `YOURNICKHERE` with the nickname that you want to be shown as, on the tracker. You don't need to register it, just pick a nickname you like.

In most of the below cases, there will be a web interface running at http://localhost:8001/. If you don't know or care what this is, you can just ignore it—otherwise, it gives you a fancy view of what's going on.

**If anything goes wrong while running the commands below, please scroll down to the bottom of this page. There's troubleshooting information there.**

Running with a warrior
-------------------------

Follow the [instructions on the ArchiveTeam wiki](http://archiveteam.org/index.php?title=Warrior) for installing the Warrior, and select the "Parler" project in the Warrior interface.

Running without a warrior
-------------------------
To run this outside the warrior, clone this repository, cd into its directory and run:

    python3 -m pip install setuptools wheel
    python3 -m pip install --upgrade seesaw zstandard requests
    ./get-wget-lua.sh

then start downloading with:

    run-pipeline3 pipeline.py --concurrent 2 YOURNICKHERE

For more options, run:

    run-pipeline3 --help

If you don't have root access and/or your version of pip is very old, you can replace "pip install --upgrade seesaw" with:

    wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py ; python3 get-pip.py --user ; ~/.local/bin/pip3 install --upgrade --user seesaw

so that pip and seesaw are installed in your home, then run

    ~/.local/bin/run-pipeline3 pipeline.py --concurrent 2 YOURNICKHERE

Running multiple instances on different IPs
-------------------------------------------

This feature requires seesaw version 0.0.16 or greater. Use `pip install --upgrade seesaw` to upgrade.

Use the `--context-value` argument to pass in `bind_address=123.4.5.6` (replace the IP address with your own).

Example of running 2 threads, no web interface, and Wget binding of IP address:

    run-pipeline3 pipeline.py --concurrent 2 YOURNICKHERE --disable-web-server --context-value bind_address=123.4.5.6

Distribution-specific setup
-------------------------
### For Debian/Ubuntu:

Package `libzstd-dev` version 1.4.4 is required which is currently available from `buster-backports`.

    adduser --system --group --shell /bin/bash archiveteam
    echo deb http://deb.debian.org/debian buster-backports main contrib > /etc/apt/sources.list.d/backports.list
    apt-get update \
    && apt-get install -y git-core libgnutls-dev lua5.1 liblua5.1-0 liblua5.1-0-dev screen bzip2 zlib1g-dev flex autoconf autopoint texinfo gperf lua-socket rsync automake pkg-config python3-dev python3-pip build-essential \
    && apt-get -t buster-backports install zstd libzstd-dev libzstd1
    python3 -m pip install setuptools wheel
    python3 -m pip install --upgrade seesaw zstandard requests
    su -c "cd /home/archiveteam; git clone https://github.com/ArchiveTeam/parler-grab.git; cd parler-grab; ./get-wget-lua.sh" archiveteam
    screen su -c "cd /home/archiveteam/parler-grab/; run-pipeline3 pipeline.py --concurrent 2 --address '127.0.0.1' YOURNICKHERE" archiveteam
    [... ctrl+A D to detach ...]

In __Debian Jessie, Ubuntu 18.04 Bionic and above__, the `libgnutls-dev` package was renamed to `libgnutls28-dev`. So, you need to do the following instead:

    adduser --system --group --shell /bin/bash archiveteam
    echo deb http://deb.debian.org/debian buster-backports main contrib > /etc/apt/sources.list.d/backports.list
    apt-get update \
    && apt-get install -y git-core libgnutls28-dev lua5.1 liblua5.1-0 liblua5.1-0-dev screen bzip2 zlib1g-dev flex autoconf autopoint texinfo gperf lua-socket rsync automake pkg-config python3-dev python3-pip build-essential \
    && apt-get -t buster-backports install zstd libzstd-dev libzstd1
    [... pretty much the same as above ...]

Wget-lua is also available on [ArchiveTeam's PPA](https://launchpad.net/~archiveteam/+archive/wget-lua) for Ubuntu.

### For CentOS:

Ensure that you have the CentOS equivalent of bzip2 installed as well. You will need the EPEL repository to be enabled.

    yum -y groupinstall "Development Tools"
    yum -y install gnutls-devel lua-devel python-pip zlib-devel zstd libzstd-devel git-core gperf lua-socket luarocks texinfo git rsync gettext-devel
    pip install --upgrade seesaw
    [... pretty much the same as above ...]

Tested with EL7 repositories.

### For Fedora:

The same as CentOS but with "dnf" instead of "yum". Did not successfully test compiling, so far.

### For openSUSE:

    zypper install liblua5_1 lua51 lua51-devel screen python-pip libgnutls-devel bzip2 python-devel gcc make
    pip install --upgrade seesaw
    [... pretty much the same as above ...]

### For OS X:

You need Homebrew. Ensure that you have the OS X equivalent of bzip2 installed as well.

    brew install python lua gnutls
    pip install --upgrade seesaw
    [... pretty much the same as above ...]

**There is a known issue with some packaged versions of rsync. If you get errors during the upload stage, parler-grab will not work with your rsync version.**

This supposedly fixes it:

    alias rsync=/usr/local/bin/rsync

### For Arch Linux:

Ensure that you have the Arch equivalent of bzip2 installed as well.

1. Make sure you have `python2-pip` installed.
2. Install [the wget-lua package from the AUR](https://aur.archlinux.org/packages/wget-lua/). 
3. Run `pip2 install --upgrade seesaw`.
4. Modify the run-pipeline script in seesaw to point at `#!/usr/bin/python2` instead of `#!/usr/bin/python`.
5. `useradd --system --group users --shell /bin/bash --create-home archiveteam`
6. `screen su -c "cd /home/archiveteam/parler-grab/; run-pipeline pipeline.py --concurrent 2 --address '127.0.0.1' YOURNICKHERE" archiveteam`

### For Alpine Linux:

    apk add lua5.1 git python bzip2 bash rsync gcc libc-dev lua5.1-dev zlib-dev gnutls-dev autoconf flex make
    python -m ensurepip
    pip install -U seesaw
    git clone https://github.com/ArchiveTeam/parler-grab
    cd parler-grab; ./get-wget-lua.sh
    run-pipeline pipeline.py --concurrent 2 --address '127.0.0.1' YOURNICKHERE

### For FreeBSD:

Honestly, I have no idea. `./get-wget-lua.sh` supposedly doesn't work due to differences in the `tar` that ships with FreeBSD. Another problem is the apparent absence of Lua 5.1 development headers. If you figure this out, please do let us know on IRC (irc.hackint.org #archiveteam).

Troubleshooting
=========================

Broken? These are some of the possible solutions:

### wget-lua was not successfully built

If you get errors about `wget.pod` or something similar, the documentation failed to compile - wget-lua, however, compiled fine. Try this:

    cd get-wget-lua.tmp
    mv src/wget ../wget-lua
    cd ..

The `get-wget-lua.tmp` name may be inaccurate. If you have a folder with a similar but different name, use that instead and please let us know on IRC what folder name you had!

Optionally, if you know what you're doing, you may want to use wgetpod.patch.

### Problem with gnutls or openssl during get-wget-lua

Please ensure that gnutls-dev(el) and openssl-dev(el) are installed.

### ImportError: No module named seesaw

If you're sure that you followed the steps to install `seesaw`, permissions on your module directory may be set incorrectly. Try the following:

    chmod o+rX -R /usr/local/lib/python2.7/dist-packages

### run-pipeline: command not found

Install `seesaw` using `pip2` instead of `pip`.

    pip2 install seesaw

### Issues in the code

If you notice a bug and want to file a bug report, please use the GitHub issues tracker.

Are you a developer? Help write code for us! Look at our [developer documentation](http://archiveteam.org/index.php?title=Dev) for details.

### Other problems

Have an issue not listed here? Join us on IRC and ask! We can be found at hackint IRC [#neparlepas](https://webirc.hackint.org/#irc://irc.hackint.org/#neparlepas).


