#!/bin/bash
rm -f WinterBoard.dylib
set -e
rsync -SPaz 'saurik@carrier.saurik.com:menes/winterboard/WinterBoard{,.dylib}' .
#killall SpringBoard
