#!/bin/bash

: <<'USAGE'
This script uses GhostScript to unlock a PDf.

The path/name of the PDF is the only argument the script takes:

  ./unlock_pdf.sh path/to/your/file.pdf

It outputs the unlocked PDF in the same location as the original, altering 
the title of the file to reflect that it's now unlocked:

  path/to/your/file_unlocked.pdf

Alternately, you can provide a second argument as a string, 
which the script will concat to the end of the file name instead:

  ./unlock_pdf.sh path/to/your/file.pdf "_bwahahaha"
  > path/to/your/file_bwahahaha.pdf

This script has been tested with the following versions of GhostScript:

- 9.10 on Mac OS 10.9.2
- 9.10 on Ubuntu 14.10
- 9.16 on Ubuntu 15.10

YMMV.

********
WARNING: 

GhostScript doesn't seem to handle non-alphanumeric characters well.  If it
seems to be choking on the path, try either putting the target file in a path
without spaces or symbols, running the script from your path in the same
location as the file, or renaming the file to something without spaces or
symbols in it.  Namely:

  ./unlock_pdf.sh this\ makes/Skyler's\ heart/Explode Messily.pdf
  > WTF I HATE YOU DIE

  unlock_pdf.sh much/better/for/everyone.pdf
  > You get a gold star!
********

Author:   Skyler Brungardt
Date:     2014-04-06
License:  GPL 3.0
USAGE

file=$1
newfile=${file%.pdf}
pdf=".pdf"

if [ -z "$2" ]; then
  suffix="_unlocked"
else 
  suffix=$2
fi

ghostscript -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$newfile$suffix$pdf -c .setpdfwrite -f $1

