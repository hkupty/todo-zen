# todo-zen

Simple TODO listing

## Status

Works, but could be improved

## Install

```bash
# If you have taskfile
task install

# or

zig build --release=fast install
cp zig-out/bin/todo_zen ~/.local/bin/todo-zen
```

## Usage

```bash
❯ todo-zen
src/main.zig:4:1:TODO: Make it configurable
src/main.zig:7:1:TODO: Make it configurable
src/main.zig:123:9:TODO: Ignore .gitignore files
src/main.zig:124:9:NOTE: Revisit blocking all the hidden files
```


## Performance

```bash

## Consider `rg-todo` to be the following:
#!/bin/bash

rg "//.*(TODO|NOTE|PERF|HACK|FIX|FIXME)"

## That is because `poop` can't run the rg command directly
## Result on a small directory (this project)
❯ poop 'todo-zen' 'rg-todo'
Benchmark 1 (8387 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time           559us ±  299us     248us … 3.90ms        524 ( 6%)        0%
  peak_rss            773KB ± 14.8KB     618KB …  774KB         83 ( 1%)        0%
  cpu_cycles          121K  ± 27.9K      112K  …  563K        1017 (12%)        0%
  instructions        253K  ± 58.8       253K  …  253K           0 ( 0%)        0%
  cache_references   6.69K  ±  285      5.86K  … 9.91K         397 ( 5%)        0%
  cache_misses        330   ±  102       143   … 1.16K         385 ( 5%)        0%
  branch_misses       518   ±  187       341   … 1.48K         948 (11%)        0%
Benchmark 2 (653 runs): rg-todo
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          7.61ms ± 2.65ms    4.52ms … 26.6ms         82 (13%)        💩+1262.4% ± 11.0%
  peak_rss           7.68MB ±  118KB    7.34MB … 8.02MB          7 ( 1%)        💩+893.3% ±  0.4%
  cpu_cycles         7.20M  ± 1.42M     6.62M  … 22.8M          81 (12%)        💩+5824.9% ± 25.1%
  instructions       13.7M  ± 9.26K     13.7M  … 13.8M          16 ( 2%)        💩+5314.4% ±  0.1%
  cache_references    419K  ± 7.43K      388K  …  468K          28 ( 4%)        💩+6168.3% ±  2.4%
  cache_misses       90.2K  ± 3.95K     80.5K  …  112K          11 ( 2%)        💩+27259.4% ± 25.7%
  branch_misses      72.8K  ±  805      70.6K  … 76.9K          16 ( 2%)        💩+13940.0% ±  4.3%

## Result on a large monorepo
Benchmark 1 (139 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          36.0ms ± 4.30ms    29.2ms … 46.8ms          0 ( 0%)        0%
  peak_rss            775KB ± 22.7KB     623KB …  778KB          3 ( 2%)        0%
  cpu_cycles         31.5M  ± 1.12M     30.5M  … 36.5M           2 ( 1%)        0%
  instructions       81.8M  ± 22.6K     81.8M  … 81.9M           0 ( 0%)        0%
  cache_references   1.25M  ± 28.0K     1.19M  … 1.35M           1 ( 1%)        0%
  cache_misses       3.50K  ±  787      2.61K  … 7.24K          10 ( 7%)        0%
  branch_misses       140K  ± 1.16K      138K  …  144K           8 ( 6%)        0%
Benchmark 2 (56 runs): rg-todo
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          89.3ms ± 5.51ms    60.7ms …  100ms          3 ( 5%)        💩+148.1% ±  4.0%
  peak_rss           10.7MB ±  197KB    10.3MB … 11.1MB          0 ( 0%)        💩+1277.9% ±  4.3%
  cpu_cycles          255M  ± 10.5M      242M  …  286M           0 ( 0%)        💩+710.1% ±  5.6%
  instructions        269M  ±  866K      267M  …  272M           1 ( 2%)        💩+228.4% ±  0.2%
  cache_references   22.1M  ±  282K     21.7M  … 22.9M           1 ( 2%)        💩+1664.0% ±  3.8%
  cache_misses        868K  ± 53.0K      756K  … 1.02M           6 (11%)        💩+24671.9% ± 250.5%
  branch_misses      1.49M  ± 16.1K     1.45M  … 1.53M           2 ( 4%)        💩+966.7% ±  1.9%
```
