#!/bin/bash

BASE_DIR="$(dirname $0)/.."

EMBED_BIN=$1
VOCAB=$2
EMBED_TXT=${EMBED_BIN%.*}.txt.tmp # Create name for txt vectors



cd $BASE_DIR/GloVe # change directory to GloVe
# fixing the paths here bc they otherwise don't work in the Julia command
EMBED_BIN=../$EMBED_BIN
EMBED_TXT=../$EMBED_TXT
VOCAB=../$VOCAB


`julia --project -e "
include(\"../src/GloVe.jl\");
M=GloVe.load_model(\"$EMBED_BIN\", \"$VOCAB\");
GloVe.save_text_vectors(\"$EMBED_TXT\", M.W, M.ivocab);
"`

python eval/python/evaluate.py --vocab_file $VOCAB --vectors_file $EMBED_TXT

# rm $EMBED_TXT
