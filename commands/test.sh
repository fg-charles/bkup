init_add_commit() {
  git init $1
  git --git-dir=$1/.git --work-tree=$1 add --all 
  git --git-dir=$1/.git --work-tree=$1 commit -a -m "first"
}

# Helper function for creating test environments. Accepts a list of paths of files
# to create and creates them according to their name, in the $tst_env directory.
# - path(s): paths describing contents of test environment. Filenames with prefix
#       'd' are treated as normal directories, g as git directories, and filenames
#       that are lowercase letters as regular files. Exclude trailing dashes.
create_env() {
  $verbose 'creating test environment...'
  rm -rf $tst_dir; mkdir $tst_dir
  local init_env=false
  if [ $1 = "-i" ]; then
    init_env=true
    shift
  fi
  for path in $@; do
    local fullpath=$tst_dir/$path
    local name=`basename $fullpath`
    if echo $name | grep --silent -x '[a-z]' -; then
      touch $fullpath
    elif echo $name | grep --silent -x '\(d\|g\)[0-9]' -; then
      mkdir $fullpath
      touch $fullpath/x
      if echo $name | grep --silent 'g' -; then
        init_add_commit $fullpath
      fi
    fi
  done
  if $init_env; then
    init_add_commit $test_dir
  fi
  $verbose "`tree $tst_dir`"
}

tst_add() {
  local subtest=$1
  ! [ $subtest ] && subtest='get_dirs'
  $verbose "Processing add subcommand $subtest"
  local verbose='echo'
  case $subtest in
    get_dirs) 
      create_env a b g1 g1/d1 g1/g2 d2
      cd $tst_dir && get_dirs ensure_git attempt_add a b g1 g1/d1 d2 
      ;;
    filter_roots)
      local paths="/tst/d1 /tst/d2 /tst/d1/s1 /tst/d2/s2 /tst/d3 /tst/d3/s3"
      filter_roots $paths 1>/dev/null
      ;;
    recurse_submod_add)
      create_env -i g1 g1/g2 g1/g3 g1/g3/g4
      recurse_submod_add $tst_dir/.git $tst_dir/g1/.git
      ;;
    *)
      echo "Error: $subtest is not a recognized tst add subcommand" 1>&2
      help
      ;;
  esac
}


tst() {
  local test=$1; shift;
  ! [ $test ] && test='all'
  $verbose "Processing tst subcommand: $test"
  case $test in
    add)
      tst_add $@;;
    all)
      tst_add;;
    *)
      echo "Error: $test is not a recognized tst subcommand" 1>&2
      help
  esac
}


