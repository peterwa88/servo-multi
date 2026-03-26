#!/usr/bin/env bash

# Build environment already prepared successfully.
# Do not modify unless a true hard blocker proves it is necessary.

export PATH="/c/LLVM/bin:$PATH"
export PATH="/d/gstreamer/1.0/msvc_x86_64/bin:$PATH"

export GSTREAMER_1_0_ROOT_MSVC_X86_64="/d/gstreamer/1.0/msvc_x86_64"
export WIN32_REDIST_DIR="/d/ProgramFiles/VisualStudio/2022/Professional/VC/Redist/MSVC/14.44.35207/x64/Microsoft.VC143.CRT"

# Uncomment only if truly required by a proven blocker
export VCToolsVersion="14.36.32532"
