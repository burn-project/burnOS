#!/usr/bin/env bash
DEVICE=panther
JOBS=6
bash -c "
  echo lunch \"${DEVICE}-cur-user\"
  echo m -j\"${JOBS}\"
"
