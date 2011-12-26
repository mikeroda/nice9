Nice9 Compiler
==============

Compiler written in Ruby that compiles a C-like language named Nice9 to 
TM (Tiny Machine) code.  This was written as part of a compiler construction course 
I took but I have modified the grammer to discourage its reuse by future students.

Tiny Machine is a assembly-like language written by Kenneth Louden and modified by
Robert Heckendorn for teaching compiler construction. To run TM code you must compile
the included C program.

Nice9 requires two Ruby files to run: 

1. nice9.rex.rb - This is the scanner, generated partially from Ruby Rex but modified heavily. Should be used as is.
2. nice9.tab.rb - Generated from the nice9.racc grammar file using Ruby Racc...

Racc takes a Yacc-like grammer file and generates a Ruby parser from it. To build nice9.tab.rb 
from the grammar file, do the following:

  racc nice9.racc

A shell script is provided to run the parser from the command line. Just
execute 'nice9'. Example:
 
   nice9 output.tm < input.9

Nice9 Testing
=============

1. Several usable sample programs (author unknown) included in the samples directory
2. Run ./test.py (requires Python) to execute an extensive test suite. Original test suite provided by Michael Wright (https://github.com/mdwrigh2).

TM Optimizer
============

Use the tmo program to optimize the TM code output from the compjiler. Performs full control-flow 
and data-flow (live variable) analysis. The following optimizations are supported:

 1. Dead/unreachable code elimination
 2. Common subexpression elimination
 3. Copy propagation
 4. Constant propagation
 5. Jump chaining

Jumps based on dynamic registers or values loaded from memory, as commonly used for 
procedures, are not supported and will cause Tmo to exit immediately. 

The programs bsort.tm and sieve.tm (use tm "-a 20000000" optiomake sure to un) generated 
from the Nice9 samples demonstrate many optimizations with high instruction counts.

Tmo requires two Ruby files to run: 

1. tmo.rex.rb - This is the scanner, generated partially from Ruby Rex but modified heavily. Should be used as is.
2. tmo.tab.rb - Generated from the tmo.racc grammar file using Ruby Racc...

Racc takes a Yacc-like grammer file and generates a Ruby parser from it. To build tmo.tab.rb 
from the grammar file, do the following:

  racc tmo.racc

A shell script is provided to run the parser from the command line. Just
execute 'tmo'. Example:
 
   tmo bsort_optimized.tm < bsort.tm

Software Requirements
=====================

1. Ruby version 1.8.7 or newer
2. Ruby racc (1.4.6)
3. Tiny Machine - included, original version at http://marvin.cs.uidaho.edu/~heckendo/CS445/tm.c
