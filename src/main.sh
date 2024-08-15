#!/bin/sh
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
####################################################################################
helper() {
  local helper=$1; shift;
  . $cell_dir/helpers/${helper}.sh $@
}

bkup() {
  local cell_dir=$(dirname "`readlink -f $0`")

  # options and config
  options=`. $cell_dir/options.sh`
  shift $?

  while read line; do
    eval "local o_$line"
  done <<- EOF
    $options
EOF
  local verbose="`[ $o_verbose = true ] && echo 'echo' || echo ': ||'`"
  local dry="`[ $o_dry = true ] && echo 'echo dry:' || echo ''`"
  $verbose -e "options:\n$(set | grep o_)"
  alias bkup="git --git-dir=$o_bkup_dir"

  . $cell_dir/commands.sh $@
}

bkup "$@"
