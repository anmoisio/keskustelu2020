#!/usr/bin/env python3
import sys
import argparse
import io

input_stream = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
output_stream = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

for line in input_stream:
    splitline = line.split()
    newline = "<s>"
    for token in splitline:
        newline += " "
        newline += token[0]
        for char in token[1:]:
            newline += "+ +"
            newline += char
    newline += " </s>\n"
    output_stream.write(newline)