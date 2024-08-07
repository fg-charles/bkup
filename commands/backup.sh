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



