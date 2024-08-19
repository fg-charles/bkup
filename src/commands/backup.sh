# Copyright 2024 Charles Faisandier
# This file is part of bkup.
# $bkup_a is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.
# $bkup_a is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with
# bkup. If not, see <https://www.gnu.org/licenses/>. 
# Backs up local changes to configured remote
# ###############################################################################

# HELPERS
bkup_forall() {
  local message=$1
  shift
  local commands=$@
  $bkup_a submodule foreach --quiet "sh -c 'echo $message \$name; $commands'"
}

get_parent_name() {
  ps -o comm= $PPID
}

# MAIN
echo "backing up submodules..."
bkup_forall "- adding" git add --all
bkup_forall "- committing" "git commit -a -m \"bkup `get_parent_name`\" || :"

echo "backing up root directory..."
$bkup_a add -u
$bkup_a commit -a -m "bkup `get_parent_name`" || :
$bkup_a push

