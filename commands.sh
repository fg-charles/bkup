alias bkup="git --git-dir=$bkup_dir"
############################################################
############################################################
# Command Processing
############################################################
############################################################
shift $((OPTIND - 1))
command=$1; shift;
$verbose "Processing command name $command..."
case $command in
  tst)
    tst $@;;
  backup)
    backup;;
  add)
    add $@;;
  list)
    list;;
  *) 
    bkup $@
esac


