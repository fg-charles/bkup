#!/bin/sh
rmt_user=root           # git server username
rmt_host=192.3.36.79           # git server ip
rmt_nm=bkup                  # name to use for remotes
bkup_dir="$HOME/.bkup.git"   # path to local git directory
tst_env=`realpath /tmp/`     # path where to create testing environment
rmt_env=/root/bkup           # path to store remote git directories

tst_dir=`realpath $tst_env/bkup_tst`
