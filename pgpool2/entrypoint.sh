#!/bin/bash

readonly cmd=$(command -v pgpool)
flags=("-n")

exec "${cmd}" "${flags[@]}"
