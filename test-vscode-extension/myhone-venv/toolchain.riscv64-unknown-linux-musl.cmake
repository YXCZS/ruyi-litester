# Use like:
#
# cmake ... \
#     -DCMAKE_TOOLCHAIN_FILE=/home/yxc/work/ruyi-litester/test-vscode-extension/myhone-venv/toolchain.cmake \
#     -DCMAKE_INSTALL_PREFIX=/home/yxc/work/ruyi-litester/test-vscode-extension/myhone-venv/sysroot.riscv64-unknown-linux-musl \
#     ...

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)
set(CMAKE_C_COMPILER /home/yxc/work/ruyi-litester/test-vscode-extension/myhone-venv/bin/riscv64-unknown-linux-musl-gcc)
set(CMAKE_CXX_COMPILER /home/yxc/work/ruyi-litester/test-vscode-extension/myhone-venv/bin/riscv64-unknown-linux-musl-g++)
set(CMAKE_FIND_ROOT_PATH /home/yxc/work/ruyi-litester/test-vscode-extension/myhone-venv/sysroot.riscv64-unknown-linux-musl)

# search for headers and libraries in the target environment,
# search for programs in the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
