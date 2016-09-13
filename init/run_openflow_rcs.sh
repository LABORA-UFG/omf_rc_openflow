#!/bin/bash

# Startup wrapper for the openflow_rcs
# detects system-wide RVM installations & Ruby from distro packages

# system-wide RVM must be installed using
# '\curl -L https://get.rvm.io | sudo bash -s stable'

die() { echo "ERROR: $@" 1>&2 ; exit 1; }

RUBY_VER = RUBY_VERSION
RUBY_BIN_SUFFIX = RUBY_VERSION

if [ `id -u` != "0" ]; then
  die "This script is intended to be run as 'root'"
fi

if [ -e /etc/profile.d/rvm.sh ]; then
    # use RVM if installed
    echo "System-wide RVM installation detected"
    source /etc/profile.d/rvm.sh
    if [[ $? != 0 ]] ; then
        die "Failed to initialize RVM environment"
    fi
    # rvm use $RUBY_VER@omf > /dev/null
    # if [[ $? != 0 ]] ; then
    #     die "$RUBY_VER with gemset 'omf' is not installed in your RVM"
    # fi
    ruby -v | grep RUBY_VER  > /dev/null
    if [[ $? != 0 ]] ; then
        die "Could not run Ruby #{RUBY_VER}"
    fi
    gem list | grep openflow_rcs  > /dev/null
    if [[ $? != 0 ]] ; then
        die "The openflow_rcs gem is not installed in the 'omf' gemset"
    fi
else
    # check for distro ruby when no RVM was found
    echo "No system-wide RVM installation detected"
    ruby -v | grep RUBY_VER  > /dev/null
    if [[ $? != 0 ]] ; then
        ruby -v | grep RUBY_VER  > /dev/null
        if [[ $? != 0 ]] ; then
            die "Could not run system Ruby #{RUBY_VER}. No useable Ruby installation found."
        fi
        #RUBY_BIN_SUFFIX="2.3.1"
    fi
    echo "Ruby #{RUBY_VER} found"
    gem$RUBY_BIN_SUFFIX list | grep openflow_rcs  > /dev/null
    if [[ $? != 0 ]] ; then
        die "The openflow_rcs gem is not installed"
    fi
fi

EXEC=""

case "$1" in

1)  echo "Starting flowvisor_proxy"
    EXEC=`which omf_rc_openflow_slice_factory`
    if [[ $? != 0 ]] ; then
        die "could not find flowvisor_proxy executable"
    fi
    ;;
2)  echo "Starting ovs_proxy"
    EXEC=`which omf_rc_virtual_openflow_switch_factory`
    if [[ $? != 0 ]] ; then
        die "could not find ovs_proxy executable"
    fi
    ;;
*) echo "Starting run_proxies"
    die "could not find run_proxies executable"
    ;;
esac

echo "Running $EXEC"
exec /usr/bin/env ruby$RUBY_BIN_SUFFIX $EXEC