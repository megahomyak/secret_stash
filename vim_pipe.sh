#!/bin/bash
exec 3> >(echo "<stdin>$(cat /dev/stdin)</stdin>")
echo 123 | vim --not-a-term -c "w! /dev/fd/3" -
