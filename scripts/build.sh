export SDE=~/bf-sde-9.13.4
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

sudo rm -rf *.log
sudo rm -rf build
mkdir build && cd build 

cmake $SDE/p4studio/ \
 -DCMAKE_INSTALL_PREFIX=$SDE/install \
 -DCMAKE_MODULE_PATH=$SDE/cmake \
 -DP4_NAME=p4mcast \
 -DP4_PATH=path/to/p4mCast/p4src/p4mcast.p4 

sudo make p4mcast && make install