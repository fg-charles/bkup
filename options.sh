#!/bin/sh
############################################################
# Option Messages
############################################################
help() {
  printf "%bUsage:%b bkup %b[h|v|V]%b %b<command> [<arguments>]%b\n" "$G" "$N" "$Y" "$N" "$M" "$N"
  printf "\n"
  printf "%bOptions:%b\n" "$G" "$N"
  printf "  -h                    Show this help message and exit.\n"
  printf "  -v                    Enable verbose mode.\n"
  printf "  -d                    Dry run only, don't actually perform git operations.\n"
  printf "  -V                    Show version and quit.\n"
  printf "\n"
  printf "%bCommands:%b\n" "$G" "$N"
  printf "  list                    Show the date and contents of remote head commit\n"
  printf "  backup                  Back up tracked files/submodules to remote repo.\n"
  printf "  add                     Add things to backup system.\n"
}

version() {
  printf "bkup v0.1\n"
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
$verbose -e "\t${opts[@]}"
