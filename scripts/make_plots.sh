#!/bin/bash

SAVE_DIR=results/figures
mkdir -p $SAVE_DIR

PYTHON=~/.conda/envs/bias/bin/python

for target in $(ls -d results/perturbations/*); do
  $PYTHON scripts/make_plots.py $target $SAVE_DIR
done
