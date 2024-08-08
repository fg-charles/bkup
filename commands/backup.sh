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
  echo -e "$line
* backing up submodules...
$line"
  bkup_forall "- adding" git add --all
  bkup_forall "- committing" "git commit -a -m \"bkup `get_parent_name`\" || :"
  bkup_forall "- pushing" git push $rmt_nm
  echo -e "$line
* backing up root directory...
$line"
  bkup_root
  echo -e "$line
finished!"
}
