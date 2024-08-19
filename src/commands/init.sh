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
# ###############################################################################

# Ensures that:
# - $o_bkup_dir exists and is a valid git repository
# - $o_bkup_dir has remote $rmt_nm $rmt_user@$rmt_host:$rmt_dir, and it is reachable.
# - $o_bkup_dir is synced to remote $rmt_nm
# - $o_bkup_dir has all configuration specified in $c_dir/helpers/gitconfig.sh
# fails if unable to do so.
init() {
  # exists and is valid
  ! [ -d  $o_bkup_dir ] && git init --bare $o_bkup_dir
  if ! $bkup_a fsck 2> /dev/null 1>&2; then
    echo "error: $o_bkup_dir exists but is disfunctional as a git directory." 1>&2
    echo "please ensure $o_bkup_dir is non-existent or a valid git directory." 1>&2
    exit 1
  fi

  # config
  . "$cell_dir/helpers/gitconfig.sh"
  
  # remote is added 
  local url="$o_rmt_user@$o_rmt_host:$o_rmt_dir/bkup.git"
  local grep_txt="$o_rmt_nm.*$url"
  local remotes=`$bkup_a remote -v`
  if ! echo "$remotes" | grep -q $grep_txt -; then
    $bkup_a remote add $o_rmt_nm $url
  fi

  # remote exists
  if ! $bkup_a fetch $o_rmt_nm 2> /dev/null; then
    local temp_gitdir=/tmp/bkup.git
    rm -rf $temp_gitdir
    git clone --bare $o_rmt_nm $temp_gitdir
    scp -r $temp_gitdir $url
  fi

  # sync
  # all-cases: add all arguments
  ! [ $# -eq 0 ] && . $cell_dir/commands/add.sh $@
  if ! $bkup_a log 2> /dev/null 1>&2 &&\
    [ "`bkup diff --cached`" = '' ]; then
    if [ "`$bkup_a branch -r`" = '' ]; then 
      # empty-empty: abort if nothing was added
      echo "starting fresh bkup system requires adding content.
            provide arguments as paths to content to be tracked" 1>&2
      exit 1;
    else
      # empty-full: add some temporary thing if no args given
      touch /tmp/bkup_init.tmp
      $bkup_a add /tmp/bkup_init.tmp
    fi
  fi
  # all-cases: commit, set remote tracking
  $bkup_a commit -a -m 'bkup -- init command' 1> /dev/null 2>&1
  $bkup_a branch -u $o_rmt_nm/main   # this might fail if remote is empty

  if $bkup_a ls-files HEAD | grep "/bkup_init.tmp" -; then
    # empty-full: reset hard.
    $bkup_a reset --hard $o_rmt_nm/main
    return 0;
  fi

  # behind-full: pull | empty-empty, full-empty, full-behind: push
  if ! ($bkup_a merge --ff-only || $bkup_a push $o_rmn_nm/main); then
    echo "content in main and $o_rmt_nm/main are unrelated. which\
      branch would you like to take priority? choices: local/remote"
    read choice
    case choice in
      local)
        # full-unrelated
        ssh $o_rmt_usr@$o_rmt_host git branch -M main store
        $bkup_a push
        ;;
      remote)
        # unrelated-full
        $bkup_a branch -m main store
        checkout_out="`$bkup_a checkout -b main $o_rmt_nm/main 2>&1`"
        if ! $? && (echo "$checkout_res" |\
          grep "untracked working tree files" -); then
                  echo -e "$checout_res\n overwrite w/ -f flag? y/[n]" 
                  read choice
                  [ $choice = 'y' ] && $bkup_a checkout -f -b main $o_rmt_nm/main
        fi
        ;;
      *)
        echo "error: user must choose between local and remote branch" 1>&2
        exit 1
        ;;
    esac
    echo "$choice took priority: other repository had their main branch renamed 'store',
    and the main branch from  $choice was set to be its new main, with appropriate tracking."
  fi
}

# running this with set -e causes "pop_var_context: head of shell_variables
# not a function context" failure.
init "$@" || :
