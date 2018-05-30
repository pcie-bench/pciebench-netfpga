#!/bin/bash

sed -i 's@define\(\s*\)VERSION_VIVADO_2014_4@define\1VERSION_VIVADO_2014_4@;T;s@^//@@' $1
