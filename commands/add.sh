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
add_to_gitmodules() {
  local relpath=$1; local url=$2
  echo -e "
[submodule \"$relpath\"]" >> /.gitmodules
  echo -e "	path = $relpath" >> /.gitmodules
  echo -e "	url = $url" >> /.gitmodules
}

# Adds a git directory as a submodule of another, ensuring that the intended submodule
# has a functional remote that can be backed up to. Not recursive. Checks that submodule 
# is not already added.
# Parameters:
# - superproj: intended superproject git dir path.
# - submod: intended submodule git dir path.
add_submod() {
  local superproj=$1; local submod=$2;
  $verbose "attempting to add $submod as submodule of $superproj..."

  # Helper function; we need relative paths between worktrees.
  get_worktree() {
    local gitdir=$1
    echo `git --git-dir=$gitdir config --get core.worktree\
      || dirname $gitdir`
  }
  local submod_worktree=`get_worktree $submod`
  local submod_rmt_dir=`basename $submod_worktree`.git
  if ! [ ${submod#$tst_dir} = $submod ]; then
    # if submod is inside of $tst_dir, make the remote temporary.
    submod_rmt_dir="/tmp/$submod_rmt_dir"
  fi
  local remote_dest=$rmt_user@$rmt_host:$submod_rmt_dir
  local grep_txt="$rmt_nm.*$remote_dest"
  if ! git --git-dir=$submod remote -v | grep -q $grep_txt -; then
    $verbose "$submod doesn\'t have remote $grep_txt; creating it..."
    $dry git clone $submod $submod_worktree/.git 2> /dev/null || :
    $dry scp -r $submod_worktree/.git $remote_dest
    $dry git --git-dir=$submod remote add $rmt_nm root@$rmt_ip:$submod_rmt_dir
  fi

  superproj_worktree=`get_worktree $superproj`
  relpath=`realpath --relative-to=$superproj_worktree $submod`
  $dry git rm $submod_rmt_dir 2> /dev/null || :
  local url=root@$rmt_ip:$submod_rmt_dir
  $verbose "$superproj <- $submod: adding $submod as submodule of $superproj..."
  $dry git --git-dir=$superproj submodule add $url $relpath || add_to_gitmodules $relpath $url
}

# Adds a git directory as a submodule of another git directory, recursively adding
# git directories within the intended submodule's worktree as submodules of the
# intended submodule.
# Parameters:
# - superproj: path to superproj git directory.
# - submod: path to intended submod git directory.
recurse_submod_add() { 
  local superproj=$1 ; local submod=$2
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
  $verbose -e "root dirs:
${roots[@]}" 1>&2
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
  $verbose -e "
resulting directories:
${dirs[@]}" 1>&2
  echo ${dirs[@]} | sed 's/ /
/g'
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
  if ! $dry git --git-dir=$bkup_dir add $path 1>&2; then
    echo "warning: failed to add $path" 1>&2
  fi
}

# Add command main function.
add() {
  $verbose "adding $@..."
  local dirs=$(get_dirs ensure_git attempt_add $@)
  local root_dirs=`filter_roots $dirs`
  for dir in $root_dirs; do
    recurse_submod_add $bku_dir $dir/.git
  done
}
