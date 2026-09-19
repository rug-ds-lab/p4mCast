export SDE=~/bf-sde-9.13.4
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

$SDE/run_p4_tests.sh -p p4mcast -t path/to/p4mCast/ptf-tests/ -s leader 
$SDE/run_p4_tests.sh -p p4mcast -t path/to/p4mCast/ptf-tests/ -s follower
