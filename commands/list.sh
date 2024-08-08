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
# Gets date of latest backup and contents, recursing into contents of submodules.

# Lists files tracked by given commit, recursing into submodules.
# Parameter:
# - commit: the commit to list contents of.
# - cur_git_repo: git repo which to look in.
list_files_rec() {
  local commit=$1; local cur_git_repo=$2; local level=$3
  if [ "$3" = '' ]; then
    level=1
  fi
  git --git-dir=$cur_git_repo ls-tree -r --full-tree $commit
  while read -r o1 o2 o3 o4; do
    echo -e "
l$level submodule /$o4 -- $2"
    list_files_rec $o3 /$o4/.git $(($level + 1))
  done < <(git --git-dir=$cur_git_repo ls-tree -r --full-tree $commit | grep commit)
}

# Gets (prints to stdout) commit date given commit hash.
get_commit_date() {
  bkup show --no-patch --format=%ci $1
}

# Gets (prints to stdout) remote head commit hash.
get_rem_head() {
  bkup ls-remote $rmt_nm 2> /dev/null | tail -n 1 | cut -f1
}

# List command main function.
list() {
  local rem_head=$(get_rem_head)
  get_commit_date $rem_head
  list_files_rec $rem_head $HOME/.bkup.git
}
