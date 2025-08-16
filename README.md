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

## Features

`todo-zen` is quite limited in features yet but it can already:
- List `TODO`, `HACK`, `FIX` and `FIXME` comments;
- Skip hidden folders;
- Return a vimgrep-compatible format;
- Bail out of too deep directory trees without finding `src/` folder.

Expected features to come are:
- [ ] flag parsing support;
    - [ ] `-d` Max depth;
    - [ ] `-D` Max depth for `src/` directory
    - [ ] `-m` Markers to look for;
    - [ ] `-l` languages/extensions to look for;

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
Benchmark 1 (7971 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time           586us ±  332us     275us … 4.29ms        695 ( 9%)        0%
  peak_rss            772KB ± 17.4KB     618KB …  774KB        114 ( 1%)        0%
  cpu_cycles          123K  ± 31.5K      112K  …  619K         967 (12%)        0%
  instructions        253K  ± 58.8       253K  …  253K           0 ( 0%)        0%
  cache_references   6.70K  ±  340      5.97K  … 9.90K         367 ( 5%)        0%
  cache_misses        335   ±  107       127   … 1.58K         388 ( 5%)        0%
  branch_misses       531   ±  201       343   … 1.43K         920 (12%)        0%
Benchmark 2 (653 runs): todo-rg
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          7.61ms ± 2.49ms    5.28ms … 34.0ms         79 (12%)        💩+1199.3% ± 10.3%
  peak_rss           7.67MB ±  110KB    7.34MB … 8.00MB          4 ( 1%)        💩+893.3% ±  0.4%
  cpu_cycles         6.71M  ± 1.37M     6.21M  … 21.8M          77 (12%)        💩+5374.0% ± 24.5%
  instructions       12.1M  ± 8.12K     12.1M  … 12.2M          13 ( 2%)        💩+4703.8% ±  0.1%
  cache_references    416K  ± 7.31K      379K  …  459K          30 ( 5%)        💩+6113.7% ±  2.4%
  cache_misses       90.1K  ± 3.80K     81.5K  …  111K          14 ( 2%)        💩+26799.2% ± 25.0%
  branch_misses      70.8K  ±  747      68.8K  … 74.1K          15 ( 2%)        💩+13222.4% ±  4.2%
Benchmark 3 (1059 runs): todo-gg
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          4.68ms ± 1.34ms    3.41ms … 16.1ms         92 ( 9%)        💩+698.3% ±  6.1%
  peak_rss           8.69MB ±  157KB    8.17MB … 9.11MB          2 ( 0%)        💩+1025.7% ±  0.5%
  cpu_cycles         3.71M  ±  602K     3.26M  … 10.4M          64 ( 6%)        💩+2925.5% ± 10.9%
  instructions       6.36M  ± 3.24K     6.35M  … 6.37M          13 ( 1%)        💩+2416.8% ±  0.0%
  cache_references    211K  ± 3.28K      191K  …  231K          41 ( 4%)        💩+3050.2% ±  1.1%
  cache_misses       48.6K  ± 2.21K     43.7K  … 58.5K          11 ( 1%)        💩+14414.8% ± 14.6%
  branch_misses      40.7K  ±  738      39.0K  … 45.0K          43 ( 4%)        💩+7566.4% ±  3.8%

## Result on a medium-to-large-sized monorepo
Benchmark 1 (136 runs): todo-zen
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          36.7ms ± 3.87ms    30.9ms … 49.2ms          0 ( 0%)        0%
  peak_rss            771KB ± 22.9KB     618KB …  774KB          4 ( 3%)        0%
  cpu_cycles         31.5M  ± 1.01M     30.5M  … 35.4M           3 ( 2%)        0%
  instructions       81.8M  ± 22.3K     81.8M  … 81.9M           0 ( 0%)        0%
  cache_references   1.25M  ± 34.2K     1.18M  … 1.37M           3 ( 2%)        0%
  cache_misses       3.67K  ±  760      2.68K  … 6.53K           4 ( 3%)        0%
  branch_misses       140K  ± 1.32K      138K  …  144K           1 ( 1%)        0%
Benchmark 2 (56 runs): todo-rg
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          89.8ms ± 6.16ms    60.4ms …  101ms          1 ( 2%)        💩+144.8% ±  3.9%
  peak_rss           10.7MB ±  218KB    9.92MB … 11.1MB          3 ( 5%)        💩+1284.1% ±  4.8%
  cpu_cycles          256M  ± 10.9M      239M  …  287M           0 ( 0%)        💩+711.4% ±  5.9%
  instructions        267M  ±  775K      265M  …  269M           1 ( 2%)        💩+226.6% ±  0.2%
  cache_references   22.0M  ±  293K     21.6M  … 23.3M           2 ( 4%)        💩+1655.0% ±  4.0%
  cache_misses        857K  ± 50.2K      771K  … 1.10M           1 ( 2%)        💩+23288.3% ± 229.3%
  branch_misses      1.48M  ± 16.6K     1.45M  … 1.54M           2 ( 4%)        💩+960.7% ±  2.0%
Benchmark 3 (10 runs): todo-gg
  measurement          mean ± σ            min … max           outliers         delta
  wall_time           532ms ± 28.2ms     498ms …  595ms          0 ( 0%)        💩+1351.7% ± 14.0%
  peak_rss           85.6MB ±  146KB    85.3MB … 85.8MB          0 ( 0%)        💩+11002.5% ±  3.6%
  cpu_cycles         1.07G  ± 18.7M     1.03G  … 1.09G           1 (10%)        💩+3295.1% ±  9.7%
  instructions       4.57G  ± 75.0K     4.57G  … 4.57G           0 ( 0%)        💩+5484.1% ±  0.0%
  cache_references   20.3M  ± 75.4K     20.1M  … 20.4M           0 ( 0%)        💩+1518.0% ±  1.9%
  cache_misses        827K  ± 30.3K      793K  …  895K           0 ( 0%)        💩+22463.2% ± 133.5%
  branch_misses      2.06M  ± 9.34K     2.05M  … 2.08M           0 ( 0%)        💩+1375.4% ±  1.2%
```
