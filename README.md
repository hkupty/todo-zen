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
Benchmark 1 (8410 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time           560us ±  468us     261us … 13.7ms        228 ( 3%)        0%
  peak_rss            772KB ± 16.0KB     508KB …  774KB         98 ( 1%)        0%
  cpu_cycles          206K  ± 52.6K      194K  … 1.20M         817 (10%)        0%
  instructions        493K  ± 55.0       493K  …  493K           0 ( 0%)        0%
  cache_references   6.99K  ±  271      6.28K  … 11.0K         489 ( 6%)        0%
  cache_misses        368   ± 96.4       151   … 1.36K         458 ( 5%)        0%
  branch_misses       565   ±  173       396   … 1.78K         754 ( 9%)        0%
Benchmark 2 (687 runs): rg-todo
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          7.23ms ± 2.61ms    4.63ms … 27.0ms         53 ( 8%)        💩+1192.0% ± 11.8%
  peak_rss           7.80MB ±  117KB    7.45MB … 8.15MB          5 ( 1%)        💩+909.3% ±  0.4%
  cpu_cycles         7.22M  ± 1.54M     6.63M  … 22.4M          59 ( 9%)        💩+3401.7% ± 16.1%
  instructions       13.7M  ± 8.79K     13.6M  … 13.7M          10 ( 1%)        💩+2669.4% ±  0.0%
  cache_references    419K  ± 7.85K      390K  …  516K          35 ( 5%)        💩+5898.6% ±  2.4%
  cache_misses       91.6K  ± 3.74K     82.9K  …  110K          16 ( 2%)        💩+24812.8% ± 21.8%
  branch_misses      72.7K  ±  758      70.5K  … 75.6K          19 ( 3%)        💩+12771.4% ±  3.7%

## Result on a large monorepo
Benchmark 1 (52 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          97.1ms ± 3.65ms    88.3ms …  109ms          6 (12%)        0%
  peak_rss            769KB ± 36.6KB     623KB …  778KB          3 ( 6%)        0%
  cpu_cycles          111M  ± 1.32M      110M  …  117M           5 (10%)        0%
  instructions        311M  ± 46.9K      311M  …  311M           0 ( 0%)        0%
  cache_references   3.13M  ±  225K     2.98M  … 4.55M           3 ( 6%)        0%
  cache_misses       8.01K  ±  770      6.42K  … 10.0K           1 ( 2%)        0%
  branch_misses       340K  ± 1.78K      336K  …  345K           0 ( 0%)        0%
Benchmark 2 (55 runs): rg-todo
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          91.2ms ± 4.59ms    85.3ms …  108ms          2 ( 4%)        ⚡-  6.1% ±  1.6%
  peak_rss           10.8MB ±  157KB    10.5MB … 11.1MB          0 ( 0%)        💩+1306.1% ±  5.8%
  cpu_cycles          259M  ± 16.7M      243M  …  344M           2 ( 4%)        💩+133.4% ±  4.2%
  instructions        269M  ±  846K      266M  …  271M           2 ( 4%)        ⚡- 13.5% ±  0.1%
  cache_references   22.1M  ±  271K     21.6M  … 23.0M           2 ( 4%)        💩+605.6% ±  3.1%
  cache_misses        920K  ± 52.6K      803K  … 1.04M           0 ( 0%)        💩+11390.2% ± 180.8%
  branch_misses      1.49M  ± 13.9K     1.46M  … 1.51M           0 ( 0%)        💩+337.1% ±  1.1%

```
