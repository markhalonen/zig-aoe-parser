I wanted to write some zig so I ported https://github.com/happyleavesaoc/aoc-mgz.

I started the project by hand then had Claude do the rest, which it did a fine job on except the JSON serialization seems quite hacky. 

It runs 15-20x faster than aoc-mgz and produces the same JSON file for 3 games that I played. 

Most of the speedup was from replacing a regex with manual byte scan logic. I didn't spend tons of time optimizing.

To observe the speedup, compile with zig `0.14.1` (only tested version)

`zig build -Doptimize=ReleaseFast`

and then run with

`.\zig-out\bin\zig14_basic.exe .\game2.aoe2record` 
