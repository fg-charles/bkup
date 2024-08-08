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
#!/bin/sh
############################################################
# Option Messages
############################################################
help() {
  printf "%bUsage:%b bkup %b[h|v|V]%b %b<command> [<arguments>]%b " "$G" "$N" "$Y" "$N" "$M" "$N"
  printf " " printf "%bOptions:%b " "$G" "$N"
  printf "  -h                    Show this help message and exit. "
  printf "  -v                    Enable verbose mode. "
  printf "  -d                    Dry run only, don't actually perform git operations. "
  printf "  -V                    Show version and quit. "
  printf " "
  printf "%bCommands:%b " "$G" "$N"
  printf "  list                    Show the date and contents of remote head commit "
  printf "  backup                  Back up tracked files/submodules to remote repo. "
  printf "  add                     Add things to backup system. "
}

version() {
  printf "bkup v0.1 "
}

############################################################
# Option Processing
############################################################
verbose='false &&'
opts=()
while getopts ":hvVdx" option; do
  case $option in
    h)
      help
      exit;;
    x)
      set -x
      opts+=("xtrace")
      ;;
    v)
      verbose='echo'
      opts+=("verbose")
      ;;
    V)
      version
      exit;;
    d)
      dry="false &&"
      opts+=("dry")
      ;;
    \?)
      echo "Error: Invalid option"
      exit;;
  esac
done
$verbose "Options finished processing. options enabled:"
$verbose -e "	${opts[@]}"
