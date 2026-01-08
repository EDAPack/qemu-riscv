cmake_minimum_required(VERSION 3.15)
project(qemu-riscv-bin)

include(ExternalProject)
include(ProcessorCount)
ProcessorCount(NPROC)

# Options to control build behavior
option(USE_LATEST_BRANCH "Use latest master branch instead of tagged release" ON)
set(QEMU_TAG "" CACHE STRING "Specific QEMU tag to use (overrides USE_LATEST_BRANCH)")

# Set install prefix if not specified
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Installation directory" FORCE)
endif()

# Determine QEMU version/branch
if(QEMU_TAG)
  set(QEMU_GIT_TAG ${QEMU_TAG})
elseif(USE_LATEST_BRANCH)
  set(QEMU_GIT_TAG "master")
else()
  # Default to a stable release
  set(QEMU_GIT_TAG "v9.2.0")
endif()

message(STATUS "Building QEMU: ${QEMU_GIT_TAG}")

# Build QEMU for RISC-V targets
ExternalProject_Add(qemu
  GIT_REPOSITORY https://gitlab.com/qemu-project/qemu.git
  GIT_TAG ${QEMU_GIT_TAG}
  GIT_SHALLOW TRUE
  CONFIGURE_COMMAND <SOURCE_DIR>/configure 
    --target-list=riscv32-softmmu,riscv64-softmmu,riscv32-linux-user,riscv64-linux-user
    --prefix=${CMAKE_INSTALL_PREFIX}
    --disable-docs
    --disable-guest-agent
    --disable-vnc
    --disable-sdl
    --disable-gtk
    --disable-opengl
    --disable-slirp
  BUILD_COMMAND make -j${NPROC}
  INSTALL_COMMAND make install
  BUILD_IN_SOURCE 1
)

# Post-install cleanup
ExternalProject_Add(post-install
  DEPENDS qemu
  DOWNLOAD_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND 
    ${CMAKE_COMMAND} -E echo "Running post-install cleanup..."
    COMMAND bash -c "strip ${CMAKE_INSTALL_PREFIX}/bin/* 2>/dev/null || true"
)
