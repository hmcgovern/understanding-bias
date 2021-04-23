#!/bin/bash

set -e

BASE_DIR=$(dirname $0)

# Make Wiki corpus
# echo Downloading and building Simple Wikipedia corpus...
# scripts/init_corpora.sh
# echo
# PYTHON=~/.conda/envs/bias/bin/python

# $PYTHON $BASE_DIR/scripts/make_wiki_corpus.py

# # Build GloVe and train a Toy Embedding
# echo Building GloVe and training a toy embedding...
# make -C "$BASE_DIR/GloVe"
# scripts/embed.sh scripts/toy_embed.config
# echo

# # Evaluate analogy performance
# echo Evaluating analogy performace...
# scripts/analogy.sh embeddings/vectors-C0-V20-W8-D25-R0.05-E15-S1.bin embeddings/vocab-C0-V20.txt
# echo

# Diff Bias
# echo Generating Differential Bias 
# julia --project src/differential_bias.jl
# echo

# # Perturbations
# echo Generating Perturbed corpora
# julia --project src/make_perturbations.jl
# echo

# # Get Perturbations
echo Training perturbed embeddings
scripts/reembed.sh 'C0-V20-W8-D25-R0.05-E15-B1' results/perturbations embeddings 
echo 
# TARGET=$1
# PERT_DIR=$2
# EMBEDDING_DIR=$3

# Run tests
# echo Running tests
# ./test
# echo


# Plot results
# echo Making plots
# scripts/make_plots.sh 