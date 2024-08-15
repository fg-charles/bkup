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

# prints a given section of the config file.
# Params:
# - section: the section to print
# - config-file: config file path
readconfig() {
  local section=$1 config_file=$2
  # Config sections must be seperated by blank line.
  # Sed outputs newline and section name before config values, tail command
  # chops those off.
  sed -s "/./{H;\$!d} ; x ; /\[$section\]/!d" $config_file | tail -n +3 
}

readconfig "$@"
