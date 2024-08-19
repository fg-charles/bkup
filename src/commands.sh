# Copyright 2024 Charles Faisandier
# This file is part of bkup.
# bkup is free sourceftware: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.
# bkup is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with
# bkup. If not, see <https://www.gnu.org/licenses/>. 
# ###############################################################################

commands() {
  local command=$1; shift
  $verbose "Processing command name $command..."
  case $command in
    tst)
      source $cell_dir/commands/tst.sh $@;;
    backup)
      source $cell_dir/commands/backup.sh $@;;
    add)
      source $cell_dir/commands/add.sh $@;;
    list)
      source $cell_dir/commands/list.sh $@;;
    init)
      source $cell_dir/commands/init.sh $@;;
    *) 
      $bkup_a $command $@
  esac
}

commands "$@"
