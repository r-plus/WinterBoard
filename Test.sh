#!/bin/bash
rm -f WinterBoard.dylib
set -e
rsync --exclude .svn -SPaz 'saurik@carrier.saurik.com:menes/winterboard/WinterBoard{,.dylib}' .
rsync --exclude .svn -SPaz 'saurik@carrier.saurik.com:menes/winterboard/*.theme' /Library/Themes/
#killall SpringBoard
