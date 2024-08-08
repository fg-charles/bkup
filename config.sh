# Copyright 2024 Charles Faisandier
# This file is part of bkup.
# bkup is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.
# bkup is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with
# bkup. If not, see <https://www.gnu.org/licenses/>. 

rmt_user=root           # git server username
rmt_host=192.3.36.79           # git server ip
rmt_nm=bkup                  # name to use for remotes
bkup_dir="$HOME/.bkup.git"   # path to local git directory
tst_env=`realpath /tmp/`     # path where to create testing environment
rmt_env=/root/bkup           # path to store remote git directories
