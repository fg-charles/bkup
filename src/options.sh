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

append_opt() {
  local options=$1 keyval=$2
  options=$options$'\n'$keyval
}

# Reads options from a config file and from command line. Outputs options
# interpretable by eval to stdout, and returns number of command-line options
# processed.
options() {
  # Config: where configurable defaults are before potential overwriting
  local config_path="`[ $XDG_CONFIG_HOME ] && echo "$XDG_CONFIG_HOME/bkup/config.ini"\
    || echo \"$HOME/.config/bkup/config.ini\"`"
  if ! [ -e $config_path ]; then
    if ! [ -e '/etc/bkup/.profile' ]; then
      echo -e 'fatal: no config file found anywhere, please create one in the below\
        filepaths (paths are in decreasing order of precedence):\n$XDG_CONFIG_HOME/\
        bkup/config.ini\n$HOME/.config/bkup/config.ini\n/etc/bkup/config.ini' >&2
      echo 'you can also create a new configuration and initiate a system with bkup\
        init' >&2
      exit
    fi 
    config_path='/etc/bkup/.profile'
  fi
  local options=`helper getconfig general $config_path`

  options=$options$'\n'verbose=false
  options=$options$'\n'dry=false
  options=$options$'\n'alias=false
  while getopts ":vda" option; do
    case $option in
      v)
        options=$options$'\n'verbose=true
        ;;
      d)
        options=$options$'\n'dry=true
        ;;
      a)
        options=$options$'\n'alias=true
        ;;
      \?)
        echo "Error: Invalid option" >&2
        exit 1;;
    esac
  done
  echo -e "$options"
  return $((OPTIND - 1))
}

options "$@"
return $?
