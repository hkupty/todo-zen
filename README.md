# todo-zen

Simple TODO listing.

Can be used as a vimgrep-compatible tool or as a CI static check to avoid growing your TODOs out of control.

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
❯ todo-zen --help
todo-zen [options]

Options:
     -h --help            Shows this help text
     -c --comment-prefix  Sets the prefix for comments to be the specified value  [default: //]
     -d --max-depth       Maximum traversal depth.                                [default: 8]
                          Set to 0 to disable.
     -D --max-src-depth   Maximum depth for a `src/` folder.                      [default: 3]
                          Set to 0 to disable.
     -t --threshold       When set, exit with code 1 if there are more todos      [default: 0]
                          then the value set in the threshold.
     -m --markers         Comment markers to look for in the comments.            [default: TODO,HACK,FIX,FIXME]
     -x --extensions      File extensions to be considered during search.         [default: zig,java,kt,go]

❯ todo-zen
src/main.zig:4:1:TODO: Make it configurable
src/main.zig:7:1:TODO: Make it configurable
src/main.zig:123:9:TODO: Ignore .gitignore files
src/main.zig:124:9:NOTE: Revisit blocking all the hidden files
```

## Performance
`todo-zen` already has a quite decent performance, much thanks to Zig, but there's definitely room for improvement.
Still, with the opinionated defaults it currently has, it locally outperforms ripgrep and git grep.
```bash

## Consider `todo-rg` to be the following:
rg --vimgrep "//.*(TODO|HACK|FIX|FIXME)"

## `todo-gg` is the same, but for git grep:
git grep -n -E "//.*(TODO|HACK|FIX|FIXME)"

## That is because `poop` can't run the rg command directly
## Result on a small directory (this project)
❯ poop 'todo-zen' 'todo-rg' 'todo-gg'
Benchmark 1 (7336 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time           644us ±  803us     288us … 13.0ms        166 ( 2%)        0%
  peak_rss            773KB ± 13.2KB     586KB …  774KB         54 ( 1%)        0%
  cpu_cycles          111K  ± 43.4K     97.3K  …  899K         489 ( 7%)        0%
  instructions        261K  ± 77.0       261K  …  261K           0 ( 0%)        0%
  cache_references   7.13K  ±  295      5.97K  … 9.69K         248 ( 3%)        0%
  cache_misses        541   ±  107       263   … 1.49K         295 ( 4%)        0%
  branch_misses       674   ±  245       440   … 1.58K         513 ( 7%)        0%
Benchmark 2 (688 runs): todo-rg
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          7.22ms ± 3.94ms    4.51ms … 33.8ms         69 (10%)        💩+1020.8% ± 16.8%
  peak_rss           7.64MB ±  100KB    7.32MB … 7.99MB          3 ( 0%)        💩+888.3% ±  0.3%
  cpu_cycles         7.14M  ± 1.93M     6.30M  … 22.7M          77 (11%)        💩+6344.4% ± 39.9%
  instructions       12.2M  ± 13.0K     12.1M  … 12.3M          16 ( 2%)        💩+4558.1% ±  0.1%
  cache_references    420K  ± 7.17K      388K  …  455K          40 ( 6%)        💩+5794.9% ±  2.3%
  cache_misses       92.1K  ± 4.00K     81.1K  …  111K          17 ( 2%)        💩+16922.5% ± 17.0%
  branch_misses      71.2K  ±  737      69.3K  … 74.2K          11 ( 2%)        💩+10463.7% ±  3.7%
Benchmark 3 (1125 runs): todo-gg
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          4.38ms ± 3.44ms    2.38ms … 28.9ms        119 (11%)        💩+580.1% ± 14.2%
  peak_rss           8.78MB ±  125KB    8.27MB … 9.13MB          1 ( 0%)        💩+1035.6% ±  0.4%
  cpu_cycles         3.91M  ± 1.16M     3.32M  … 15.1M          84 ( 7%)        💩+3426.2% ± 24.0%
  instructions       6.42M  ± 4.02K     6.41M  … 6.43M          34 ( 3%)        💩+2362.0% ±  0.0%
  cache_references    216K  ± 3.74K      203K  …  245K          41 ( 4%)        💩+2927.0% ±  1.2%
  cache_misses       48.7K  ± 2.08K     42.8K  … 58.4K          23 ( 2%)        💩+8890.5% ±  8.9%
  branch_misses      41.2K  ±  711      39.5K  … 44.4K          64 ( 6%)        💩+6004.1% ±  3.2%

## Result on a medium-to-large-sized monorepo
Benchmark 1 (173 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          28.8ms ± 6.23ms    21.9ms … 53.4ms         15 ( 9%)        0%
  peak_rss            769KB ± 28.6KB     618KB …  774KB          6 ( 3%)        0%
  cpu_cycles         22.4M  ± 2.19M     21.3M  … 40.5M          31 (18%)        0%
  instructions       62.4M  ± 21.3K     62.3M  … 62.4M           0 ( 0%)        0%
  cache_references   1.07M  ± 39.4K      999K  … 1.18M           0 ( 0%)        0%
  cache_misses       3.43K  ±  792      2.34K  … 7.79K           5 ( 3%)        0%
  branch_misses       186K  ± 1.21K      185K  …  191K           4 ( 2%)        0%
Benchmark 2 (53 runs): todo-rg
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          94.9ms ± 11.5ms    74.0ms …  162ms          2 ( 4%)        💩+228.9% ±  8.3%
  peak_rss           10.7MB ±  201KB    10.0MB … 11.0MB          2 ( 4%)        💩+1287.5% ±  4.0%
  cpu_cycles          265M  ± 14.7M      239M  …  304M           1 ( 2%)        💩+1081.8% ± 10.1%
  instructions        267M  ±  862K      265M  …  270M           1 ( 2%)        💩+328.6% ±  0.2%
  cache_references   22.3M  ±  493K     21.8M  … 25.2M           1 ( 2%)        💩+1985.5% ±  6.9%
  cache_misses        886K  ±  227K      777K  … 2.49M           1 ( 2%)        💩+25696.5% ± 981.0%
  branch_misses      1.50M  ± 67.8K     1.45M  … 1.97M           5 ( 9%)        💩+702.4% ±  5.4%
Benchmark 3 (10 runs): todo-gg
  measurement          mean ± σ            min … max           outliers         delta
  wall_time           518ms ± 33.3ms     493ms …  601ms          0 ( 0%)        💩+1696.2% ± 21.2%
  peak_rss           85.8MB ±  143KB    85.5MB … 86.0MB          0 ( 0%)        💩+11054.9% ±  3.5%
  cpu_cycles         1.07G  ± 15.0M     1.05G  … 1.10G           0 ( 0%)        💩+4671.6% ± 11.3%
  instructions       4.57G  ±  108K     4.57G  … 4.57G           0 ( 0%)        💩+7231.5% ±  0.0%
  cache_references   20.5M  ±  110K     20.3M  … 20.7M           0 ( 0%)        💩+1817.9% ±  2.7%
  cache_misses        828K  ± 35.4K      794K  …  902K           0 ( 0%)        💩+24012.3% ± 147.1%
  branch_misses      2.06M  ± 16.2K     2.04M  … 2.09M           0 ( 0%)        💩+1004.3% ±  1.3%


```

## Why?

I really wanted to learn zig in a practical problem space and, while I was developing another zig project, I noticed I was using several TODOs in my code so this felt
like a natural continuation - keep learning zig while developing something practical/useful.
