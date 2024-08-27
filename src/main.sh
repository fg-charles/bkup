#!/bin/sh
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
####################################################################################

git --git-dir=/home/cgf/.bkup.git add -u
git --git-dir=/home/cgf/.bkup.git commit -a -m "bkup - automatic backup"
git --git-dir=/home/cgf/.bkup.git push

read -r -d '' gitdirs <<'EOF'
  /home/cgf/.config/nvim/.git
  /home/cgf/code/mine/bkup/.git
  /home/cgf/org/.git
EOF

for dir in $gitdirs; do
  cd $dir/..
  git --git-dir=$dir add --all
  git commit -a -m "bkup - automatic backup"
  git push bkup
done

rsync -avAXHS --progress /home/cgf/media/ root@$cgf_ip:/root/bkup/media.rsync/
