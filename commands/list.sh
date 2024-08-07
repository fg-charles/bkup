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


