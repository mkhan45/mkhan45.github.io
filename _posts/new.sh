#!/bin/sh

title=$1
date=`date +'%Y-%m-%d'`

nvim "$date-$title".md
