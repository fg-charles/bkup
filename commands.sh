############################################################
############################################################
# Commands 
# main and helper functions for program commands.
############################################################
############################################################
alias bkup="git --git-dir=$bkup_dir"
############################################################
# backup
############################################################
# Backs up local changes to configured remote
line="__________________________"
get_parent_name() {
  ps -o comm=$PPID
}

# Wrapper for better output formatting for git `foreach` commands.
# Format:
# <message> <submodule_name>
# __________________________
# <command output>
# __________________________
# Params:
# - message: message to replace for <message>
# - command: command
bkup_forall() {
  local message=$1
  shift
  local commands=$@
  bkup submodule foreach --quiet "sh -c 'echo $message \$name; $commands'"
}


# Syncs local changes that are directly in bkup gitdir worktree.
bkup_root() {
  bkup add -u
  bkup commit -a -m "bkup `get_parent_name`" || :
  bkup push
}
# Main backup command function.
backup() {
  echo -e "$line\n* backing up submodules...\n$line"
  bkup_forall "- adding" git add --all
  bkup_forall "- committing" "git commit -a -m \"bkup `get_parent_name`\" || :"
  bkup_forall "- pushing" git push $rmt_nm
  echo -e "$line\n* backing up root directory...\n$line"
  bkup_root
  echo -e "$line\nfinished!"
}

############################################################
# add
############################################################
add_to_gitmodules() {
  local relpath=$1; local url=$2
  echo -e "\n[submodule \"$relpath\"]" >> /.gitmodules
  echo -e "\tpath = $relpath" >> /.gitmodules
  echo -e "\turl = $url" >> /.gitmodules
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
  $verbose -e "\nresulting directories:\n${dirs[@]}" 1>&2
  echo ${dirs[@]} | sed 's/ /\n/g'
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

############################################################
# list
############################################################
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
    echo -e "\nl$level submodule /$o4 -- $2"
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

############################################################
# tst
############################################################

init_add_commit() {
  git init $1
  git --git-dir=$1/.git --work-tree=$1 add --all 
  git --git-dir=$1/.git --work-tree=$1 commit -a -m "first"
}

# Helper function for creating test environments. Accepts a list of paths of files
# to create and creates them according to their name, in the $tst_env directory.
# - path(s): paths describing contents of test environment. Filenames with prefix
#       'd' are treated as normal directories, g as git directories, and filenames
#       that are lowercase letters as regular files. Exclude trailing dashes.
create_env() {
  $verbose 'creating test environment...'
  rm -rf $tst_dir; mkdir $tst_dir
  local init_env=false
  if [ $1 = "-i" ]; then
    init_env=true
    shift
  fi
  for path in $@; do
    local fullpath=$tst_dir/$path
    local name=`basename $fullpath`
    if echo $name | grep --silent -x '[a-z]' -; then
      touch $fullpath
    elif echo $name | grep --silent -x '\(d\|g\)[0-9]' -; then
      mkdir $fullpath
      touch $fullpath/x
      if echo $name | grep --silent 'g' -; then
        init_add_commit $fullpath
      fi
    fi
  done
  if $init_env; then
    init_add_commit $test_dir
  fi
  $verbose "`tree $tst_dir`"
}

tst_add() {
  local subtest=$1
  ! [ $subtest ] && subtest='get_dirs'
  $verbose "Processing add subcommand $subtest"
  local verbose='echo'
  case $subtest in
    get_dirs) 
      create_env a b g1 g1/d1 g1/g2 d2
      cd $tst_dir && get_dirs ensure_git attempt_add a b g1 g1/d1 d2 
      ;;
    filter_roots)
      local paths="/tst/d1 /tst/d2 /tst/d1/s1 /tst/d2/s2 /tst/d3 /tst/d3/s3"
      filter_roots $paths 1>/dev/null
      ;;
    recurse_submod_add)
      create_env -i g1 g1/g2 g1/g3 g1/g3/g4
      recurse_submod_add $tst_dir/.git $tst_dir/g1/.git
      ;;
    *)
      echo "Error: $subtest is not a recognized tst add subcommand" 1>&2
      help
      ;;
  esac
}


tst() {
  local test=$1; shift;
  ! [ $test ] && test='all'
  $verbose "Processing tst subcommand: $test"
  case $test in
    add)
      tst_add $@;;
    all)
      tst_add;;
    *)
      echo "Error: $test is not a recognized tst subcommand" 1>&2
      help
  esac
}

############################################################
############################################################
# Command Processing
############################################################
############################################################
shift $((OPTIND - 1))
command=$1; shift;
$verbose "Processing command name $command..."
case $command in
  tst)
    tst $@;;
  backup)
    backup;;
  add)
    add $@;;
  list)
    list;;
  *) 
    bkup $@
esac


