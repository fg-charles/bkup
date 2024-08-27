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

# required as param of get_dirs
# Ensures that the given valid directory path has a valid .git directory
# at it's trunk, attempt to make it so if not, or error to stdout and exit
# if not possible.
# Parameters:
# - path: a valid directory path
ensure_worktree() {
  local path=`readlink -e $1`
  if ! git --git-dir=$path/.git fsck; then
    $dry git init $path 1>&2 ||\
      echo "warning: could not ensure $path is a worktree" 1>&2 &&\
      return 1
  fi
}

# required as param of get_dirs
# attempts to add a file to the bkup system. warns to stdout if path
# could not be added. if file is already in the bkup system, directly
# or through a submodule, refuses to add notifies to stdout.
# Parameters:
# - path: filepath to attempt to add to bup system.
attempt_add() {
  local path=$1
  $bkup_a submodule foreach --recursive \
    "! git ls-files --error-unmatch $path"  
  # ^ command fails when path already in bkup
  if ! $?; then  # if it failed...
    echo "warning: $path already in bkup, skipping..." 1>&2
  elif ! $dry git --git-dir=$o_bkup_dir add $path; then
    echo "warning: failed to add $path" 1>&2
  fi
}

# Seperates directories from non-directories from a list of paths, applying
# dirfuc and ofunc to directories and other files respecively. returns
# directories which were processed by dirfunc successfully.
# Parameters:
# - dirfunc: the function to apply to directories
# - ofunc: function applied to other filetypes
get_dirs() {
  $verbose "get_dirs: filtering directories and applying functions..." 1>&2
  local dirfunc=$1; local ofunc=$2;
  shift 2
  local dirs=()
  for path in $@; do
    if [ -d $path ]; then
      $dirfunc $path &&\
        dirs+=(`realpath $path`)
    else
      $ofunc $path
    fi
  done
  $verbose -e "resulting directories:\n${dirs[@]}" 1>&2
  echo ${dirs[@]} | tr ' ' '\n'
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


# Takes all directores that aren't true roots and merge them into the
# existing submodule structure
merge_roots() {
  $bkup_a submodule foreach --recurse 'git add --all' # update index
  $bkup_a ls-files --recurse-submodules --error-unmatched 
}

# required by add_submod
# Helper function; we need relative paths between worktrees.
get_worktree() {
  local gitdir=`readlink -f $1`
  echo `git --git-dir=$gitdir config --get core.worktree\
    || dirname $gitdir`
}

# required by recurse_submod_add
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
  sudo git --git-dir=$superproj submodule add -f $url $path ||
    return 1

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



# Attempts to add each argument path given to the backup system, in the way
# described below:
# - non-existing path: warn user and move on
# - directory (true root): incorporates already tracked files and submodules
#      that are children of the directory.
# - directory (subdir): is incorporated as a new submodule of the highest-level
#      submodule parent of directory, and all children files are transfered to it.
# - file/other (true root): attempts add
# - file/other (subdir): warn and ignore
# Parameters:
# - paths...: paths to add to the system.
add() {
  $verbose "adding $@ ..."
  # local dirs=$(get_dirs ensure_git attempt_add $@)
  # local root_dirs=`filter_roots $dirs`
  # local true_roots=`merge_roots $root_dirs` # roots that are not already backed up.
  # for dir in $root_dirs; do
    recurse_submod_add $o_bkup_dir $dir/.git
  # done
}

add "$@"
