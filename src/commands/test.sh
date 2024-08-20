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

test() {
  local test=$1; shift;
  ! [ $test ] && test='all'
  $verbose "Processing tst subcommand: $test"
  case $test in
    init)
      . $cell_dir/commands/tests/tst_init.sh "$@";;
    add)
      . $cell_dir/commands/tests/tst_add.sh "$@";;
    *)
      echo "Error: $test is not a recognized tst subcommand" 1>&2
      exit 1
  esac
}

test "$@"
