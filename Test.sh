#!/bin/bash
rm -f WinterBoard.dylib
set -e
rsync --exclude .svn -SPaz 'saurik@carrier.saurik.com:menes/winterboard/WinterBoard{,.dylib}' .
rsync --exclude .svn -SPaz 'saurik@carrier.saurik.com:menes/winterboard/Nature/' /Library/Themes/com.saurik.WinterBoard.Nature
#killall SpringBoard
