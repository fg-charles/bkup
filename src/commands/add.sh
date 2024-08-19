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
# ###############################################################################

get_gitmodule_entry() {
  local path=$1 url=$2
  echo -e "\n[submodule \"$path\"]\n path = $path\n url=$url"
}

# Helper function; we need relative paths between worktrees.
get_worktree() {
  local gitdir=`readlink -f $1`
  echo `git --git-dir=$gitdir config --get core.worktree\
    || dirname $gitdir`
}

# Adds a git directory as a submodule of another, ensuring that the intended submodule
# has a functional remote that can be backed up to. Not recursive. Checks that submodule 
# is not already added.
# Parameters:
# - superproj: intended superproject git dir path.
# - submod: intended submodule git dir path.
add_submod() {
  local superproj=$1 submod=$2;
  local submod_name=`basename $(get_worktree $submod)`
  local submod_rmt_path="$o_rmt_dir/$submod_name.git"
  $verbose "add_submod -- $2 -> $1"
  # use temporary remotes for tests.
  if ! [ ${submod#$tst_dir} = $submod ]; then
    submod_rmt_path="/tmp/$submod_name.git"
  fi

  local url=$o_rmt_user@$o_rmt_host:$submod_rmt_path
  local grep_txt="$o_rmt_nm.*$url"
  # make sure submod has the remote we're looking for.
  local submod_a="git --git-dir=$submod"
  local remotes=`$submod_a remote -v`
  if ! echo "$remotes" | grep -q $grep_txt -; then
    $verbose "$submod doesn't have remote $grep_txt; adding it..."
    $dry $submod_a remote rm $o_rmt_nm
    $dry $submod_a remote add $o_rmt_nm $url
  fi
  $verbose -e "$submod has desired remote."

  # make sure the remote is actually accessible
  if ! $submod_a fetch $o_rmt_nm 2> /dev/null; then
    $verbose -e "$o_rmt_nm not available, attempting to create the remote..."
    local temp_gitdir=/tmp/$submod_name.git
    $dry rm -rf $temp_gitdir
    $dry git clone --bare $submod $temp_gitdir
    $dry scp -r $temp_gitdir $url
  fi
  $verbose "remote is accessible"

  # make sure submodule has a commit checked out
  if ! $submod_a log; then
    $submod_a add --all
    $submod_a commit -a -m 'bkup initial commit'
  fi

  # add the submodule
  local superproj_worktree=`get_worktree $superproj`
  local path=`realpath --relative-to=$superproj_worktree $(dirname $submod)`
  cd $superproj_worktree
  $verbose "attempting to add $submod as submodule of $superproj
  url: $url path: $path"
  sudo git --git-dir=$superproj submodule add -f $url $path   

  # git fails to append to /.gitmodules due to lockfile permissions.
  # this ensures it has an entry.
  local gitmodule_entry=`echo -e "[submodule \"$path\"]\n path = $path\n url=$url"`
  local gitmodules=`[ $superproj_worktree = '/' ] &&\
    echo $superproj_worktree.gitmodules ||\
    echo $superproj_worktree/.gitmodules`
  if ! grep -Fqz "$gitmodule_entry" $gitmodules; then
    $verbose "superproj doesn't have required gitmodules entry, adding it..."
    echo "$gitmodule_entry" >> $gitmodules
  fi
  $verbose "required gitmodules entry found."
}

# Adds a git directory as a submodule of another git directory, recursively adding
# git directories within the intended submodule's worktree as submodules of the
# intended submodule.
# Parameters:
# - superproj: path to superproj git directory.
# - submod: path to intended submod git directory.
recurse_submod_add() { 
  local superproj=$1 submod=$2
  
  local submod_wrktree=`dirname $submod`
  local submod_gitdirs=`find $submod_wrktree -mindepth 1 -type d\
    -exec sh -c 'test -d "$1"/\.git' -- {} \; -print -prune`;
  for gitdir in $submod_gitdirs; do
    recurse_submod_add $submod $gitdir/.git
  done
  add_submod $superproj $submod
}

# From a list of directory paths, return only directories that 
# are not subdirectories of something else on the list.
filter_roots() {
  $verbose "filtering root directories..." 1>&2
  local roots=()
  for path1 in $@; do
    local root=1
    for path2 in $@; do
      if [ $path2 = $path1 ]; then
        continue
      elif ! [ ${path1#*$path2} = "$path1" ]; then
        root=0
        break
      fi
    done
    if [ $root -eq 1 ]; then
      roots+=($path1)
      $verbose "$path1 is a root" 1>&2
    else
      $verbose "$path1 is not a root." 1>&2
    fi
  done
  $verbose -e "root dirs:\n${roots[@]}" 1>&2
  echo ${roots[@]}
}

# Seperates directories from non-directories from a list of paths, applying
# dirfuc and ofunc to directories and other files respecively. returns
# directories.
get_dirs() {
  $verbose "get_dirs: filtering directories and applying functions..." 1>&2
  local dirfunc=$1; local ofunc=$2;
  shift 2
  local dirs=()
  for path in $@; do
    if [ -d $path ]; then
      dirs+=(`realpath $path`)
      $dirfunc $path
    else
      $ofunc $path
    fi
  done
  $verbose -e "resulting directories:\n${dirs[@]}" 1>&2
  echo ${dirs[@]} | tr ' ' '\n'
}

ensure_git() {
  local path=$1
  if ! [ -d $path/.git ]; then
    $dry git init $path 1>&2
  fi
}

attempt_add() {
  local path=$1
  $verbose "- adding $path to bkup..." 1>&2
  ! [ -e $path ] && echo "$path doesn't exist" 1>&2 && return 1
  if ! [ -r $path ]; then
    echo "user doesn't have required read permission for $path." 1>&2
    echo "attempt fix: chmod 744 $path? (Y/[n])" 1>&2
    read choice
    if [ $choice = 'Y' ]; then
      sudo chmod 744 $path;
    fi
  fi
  if ! $dry git --git-dir=$o_bkup_dir add $path; then
    echo "warning: failed to add $path" 1>&2
  fi
}

$verbose "adding $@ ..."
local dirs=$(get_dirs ensure_git attempt_add $@)
local root_dirs=`filter_roots $dirs`
for dir in $root_dirs; do
  recurse_submod_add $o_bkup_dir $dir/.git
done
