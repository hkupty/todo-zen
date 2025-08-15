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
todo-zen

 → src/main.zig
NOTE: Revisit blocking all the hidden files
```


## Performance

```bash

## Consider `rg-todo` to be the following:
#!/bin/bash

rg "//.*(TODO|NOTE|PERF|HACK|FIX|FIXME)"

## That is because `poop` can't run the rg command directly
❯ poop 'todo-zen' 'rg-todo'
Benchmark 1 (1157 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          4.25ms ± 2.80ms    2.25ms … 31.1ms         78 ( 7%)        0%
  peak_rss            778KB ± 8.20KB     623KB …  778KB          7 ( 1%)        0%
  cpu_cycles         2.29M  ±  683K     2.08M  … 8.54M          91 ( 8%)        0%
  instructions       5.28M  ±  286      5.28M  … 5.28M           0 ( 0%)        0%
  cache_references    152K  ± 5.01K      135K  …  174K          17 ( 1%)        0%
  cache_misses       1.54K  ±  623       696   … 5.47K          21 ( 2%)        0%
  branch_misses      22.2K  ± 1.02K     19.4K  … 25.2K           1 ( 0%)        0%
Benchmark 2 (478 runs): rg-todo
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          10.4ms ± 2.45ms    8.30ms … 35.9ms         45 ( 9%)        💩+145.2% ±  6.8%
  peak_rss           8.12MB ±  161KB    7.64MB … 8.53MB          1 ( 0%)        💩+943.9% ±  1.2%
  cpu_cycles         12.9M  ± 2.54M     11.5M  … 41.2M          50 (10%)        💩+461.1% ±  6.9%
  instructions       23.8M  ±  206K     23.2M  … 24.6M          12 ( 3%)        💩+350.7% ±  0.2%
  cache_references    806K  ± 23.5K      735K  …  917K          31 ( 6%)        💩+431.7% ±  0.9%
  cache_misses        146K  ± 7.25K      128K  …  178K          15 ( 3%)        💩+9368.2% ± 27.4%
  branch_misses       128K  ± 2.78K      121K  …  139K           8 ( 2%)        💩+475.0% ±  0.8%
❯ rg-todo | wc -l
26
❯ todo-zen | wc -l
58
```
