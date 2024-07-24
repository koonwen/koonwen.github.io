---
layout: post
title: Efficient concurrency through eio
cover-pic: "/assets/img/eio-cover.png"
date: 2024-07-24 16:50 +0800
prerequisites: OCaml
---
Getting concurrency right is often tricky. Recently, I've been playing
around with **eio**, an IO concurrency library for OCaml. In particular, I've
been trying to optimize a recursive directory copy algorithm, hoping to use
concurrency to get a speed boost. Turns out, this problem was much more
intricate than I anticipated! Here's how it went.

## Concurrency
As a quick overview of how concurrency is used to speed up
programs. Concurrency is the structuring of a program into separate
tasks that runs one at a time but can swap in and out with one
another. However, this overlapping structure doesn't provide any
speedup on it's own. It needs to be paired with a program that
consists of some waiting and other independent work that could be
processed in the meantime. To give a concrete example, if boiling
vegetables were the task at hand, the sequential (dual to concurrent)
way of doing this would be:

```
t1: Skin potatoes
t2: Skin tomatoes
t3: Boil water
t4: Waiting for water to boil ...
t5: Waiting for water to boil ...
t6: Add skinned vegetables to boiling water
```
The concurrent way to do this would be:

```
t1: Boil water
t2: Waiting for water to boil ...  | In the meantime, skin potatoes
t3: Waiting for water to boil ...  | In the meantime, skin tomatoes
t4: Add skinned vegetables to boiling water
```
As you can see, doing some of the work concurrently completes work
faster than the sequential manner. This is only because we can do some
meaningful work in between whilst we are waiting. If the task had no
waiting involved, it wouldn't benefit us to do things concurrently.

### Mental model
The question now is: what does this look like in computers and when
does this happen? Most of us understand that computers have a CPU which is at
the heart of the processing in the machine. What's less understood is that the
CPU needs to coordinate itself with other peripheral IO "devices" such as the
network card or hard drive in system. Moreover, each of these "devices" do
their own internal independent processing prior to passing or upon receiving
data from the CPU. Therefore, it is a more accurate to think of computers as
a distributed systems in itself. This concept is key because it maps nicely
into the explanation of when waiting happens. Every time a CPU interacts with
it's peripheral "devices", it is making a request to an external system and has
to wait for data to flow to or from these device subsystems.

That was the view from physical hardware. In software, programs don't
interact directly with devices. Instead, they make IO requests through
the operating system which coordinates the underlying request to the
device. For example, a program declaring that it is wants to write to
a file will be translated into a disk write request by the OS so that
data isn't lost when the computer is rebooted.

In the past, these proxied requests (also known as system calls) were
blocking. This means that whilst the request to the underlying
hardware was sent, the OS would pause your program and resume it only
when the IO subsystem had completed the request. These days, operating
systems provide system calls which can be performed in non-blocking
mode. Now instead of suspending your program, the system call returns
immediately regardless of whether the IO request completed. This
allowed the program to do other things and then at some point in the
future, the program can check if the request for the data has
completed and then do whatever post processing it needed. In short,
non-blocking syscalls is the core mechanism which enables programs to
express "do something else in the meantime".

### eio
With this foundation, we can now come around and address some of what
goes into an IO concurrency library. At it's core, eio is built on top
of non-blocking syscalls to ensure that the program doesn't get
suspended while waiting on IO. This is combined with OCaml5's new
language feature - Fiber's, which allows you to programmatically
express independent tasks. Finally, tying the two together, a
scheduler organizes the Fibers to run, scheduling them in and out
depending on if the Fiber has to wait for some IO or if IO has been
completed.

## The Problem
With the stage set, let's see an actual program that can be sped up
with eio. I came across a discussion post about how one should write
an efficient directory copy using *eio*. The original poster provided
their implementation which I have simplified and reused as our
starting point.

### Baseline Expectations
Before looking at that, The first useful thing to do is to step back
and think about how this problem will interact with IO. Since my
filesystem is on disk, we expect the copying to engage reading and
writing to and from disk. Moreover, our algorithm can be structured
concurrently since given two files in the same directory (e.g. file A
and file B), these could be expressed as independent "fibers" since
they don't depend on one another. Concretely, I could initiate writing
to file A, while waiting for the request to be written to disk, I
could initiate writing to file B.

#### Hardware
Next, to get some throughput expectations, the actual hardware of my
system is a Quad-core Intel i7-7600U 2.8GHz with an Intel SSD 6000p, 512GB. The
advertised transfer rate of the SSD is roughly **430 MB/s**.

#### Measuring sequential throughput with dd
To see if those numbers provided by the manufacturer are reproducible
on my machine, I used the `dd` command to measure the throughput of
sequential writes. ![dd_result](/assets/img/dd_result.jpg) Writing 1GB of
data to disk measured **490 MB/s**. It's odd that the value we observe is
higher but it's within the ballpark so we'll take it as it is for now.

#### Workload expectations
The previous two measurements are sequential, meaning that the data to
be written was in one contiguous chunk. This is also usually the best
workload scenario for disks to manage and often see's the best
throughput performance. However, filesystem copying is different,
firstly it comprises of a mixture of reading and writing. Moreover,
there is no guarantee that writes will happen in one sequential block
since the filesystem could decide spread out files to be stored
sparsely on disk. Thus, in order to get something closer to our
workload, I simply timed the system's `cp -r` command on the following
input:

```
Directory depth: 5
Files per directory: 7
Filesize: 4k
Total size of directory (including the subdirectory files): 480MB 
Total IO size (R + W) = 960MB 
Total time to completion:
```
![cp_r_4k_large_dir](/assets/img/cp_r_4k_large_dir.png)

Our estimated throughput for `cp -r` is therefore `960MB / 3.045s =
~315MB/s`. As expected we are slower, but not just because of the
reasons stated above. The recursive copy also has to walk through the
directory tree structure incurring extra fees from other system calls
such as opening and creating files & directories along the way. The
`dd` command here is more akin to writing to a singular large
file. That said, `dd` is useful just to give us a fairly good estimate
on what the upper limit is.

#### Can we do better?
Peering into how `cp` is implementation, it doesn't employ any
concurrency and just performs a sequential walk through the directory
using a blocking syscalls. So in theory, we should be able to design a
faster concurrent version of the algorithm.

### Cp implemented with eio
Now returning back to reimplementing copy with eio, let's look at the
following algorithm.

```ocaml
open Eio

let ( / ) = Eio.Path.( / )

let copy src dst =
  let rec dfs ~src ~dst =
    let stat = Path.stat ~follow:false src in
    match stat.kind with
    | `Directory ->
      Path.mkdir ~perm:stat.perm dst;
      let files = Path.read_dir src in
      List.iter (fun basename -> dfs ~src:(src / basename) ~dst:(dst / basename)) files
    | `Regular_file ->
      Path.with_open_in src @@ fun source ->
      Path.with_open_out ~create:(`Exclusive stat.perm) dst @@ fun sink ->
      Flow.copy source sink;
    | _ -> failwith "file type error"
    in
  dfs ~src ~dst

let () =
  Eio_linux.run (fun env -> 
      let cwd = Eio.Stdenv.cwd env in
      let src = cwd / Sys.argv.(1) in
      let dst = cwd / Sys.argv.(2) in
      copy src dst)
```

The above implementation is a minimal sequential version of `cp -r`
using eio's API's. However, right now we don't expect to do better. In
fact, the benchmarks show that the eio's sequential implementation takes
**8.8** seconds to complete, the throughput is only **109MB/s**. 3 times
slower than the original `cp`. We will rack up this overhead to being
because of the cost of the scheduler and coordinating non-blocking IO in
a sequential manner for now.

To make this program concurrent, the simple change of spawning fibers
to handle each file to copy is enough. It should be mentioned that the
number of fibers spawned need to be capped for 2 reasons. The first is
that fibers simulate their stacks on the heap and thus extra memory
space is incurred when more fibers are used. Secondly, there is a
limit on the number of open file descriptors a process is allowed to
have open. Looking at this program, it is implemented with DFS, in
either branch, it will minimally have the file descriptor of it's
current directory open as well as all it's parent directories. Each
branch will additionally open 1 or 2 file descriptors. As such if we
were to spawn fibers without much thought, the number of file
descriptors opened at one time can grow quite large if our filesystem
we are copying is big enough. Seeing that the limit is 1024 open file
descriptors, it's therefore neccessary to throttle the number of
fibers we spawn.

For the sake of simplicity, let's be conservative and spawn only 2 fibers
every time we encounter a new directory. Our new algorithm just adds this
change

```diff
- List.iter (fun ...)
+ Fiber.List.iter ~max_fibers:2 (fun ...)
```

## Results
Using the hyperfine command-line benchmarking tool, and on the same
workload:

### Benchmark 1
Using the same workload as above,

![Benchmark1](/assets/img/eio_cp_r_4k_large_dir.png)

We were expecting a speedup here but that’s not exactly what we
observe. Thinking for a moment, our guess is that the cost of each IO
could be so cheap that the overhead of spawning a new fiber to handle IO
concurrently overshadows. In that case, let's try increasing the file sizes to
**1MB**

### Benchmark 2
Our new test directory has the following properties: 
```
Directory depth: 5 
Files per directory: 4 
Filesize: 1MB 
Total size of directory (including the subdirectory files): 780MB 
Total IO size (R + W) = 1560MB
```
![Benchmark2](/assets/img/benchmark_2.png)

Unfortunately, we're still performing worse than the regular copy but
relatively better compared to the first benchmark run. Now we are doing 1.4x
slower versus 1.6x slower relative to system copy. This is strange, which means
it's time to bring out a tracer to see what's going on. `eio` provides
a separate tool `eio-trace` which gives you a visualization of the concurrency
in the program. The trace produces

![eio-trace](/assets/img/eio-trace.png)

What's going on here? It looks like for every copy, there's a long
read/write loop. Digging into the eio codebase, it looks like it
selects the default buffer size for each copy to be 4096. This
explains why copying a large file requires so many reads and
writes. eio supports different backends that provide it's low-level
non-blocking API's. When using `Eio_main.run` function to instrument
the scheduler environment, it selects the most appropriate backend
depending on your system. In my case, it uses the linux backend, which
is equivalent to use running `Eio_linux.run`. However, the difference
is that while using `Eio_main.run` is portable between different OS's,
it doesn't provide us any configuration options. `Eio_linux.run` on
the other hand, provides us with some options.

```ocaml
val run :
  ?queue_depth:int ->
  ?n_blocks:int ->
  ?block_size:int ->
  ?polling_timeout:int ->
  ?fallback:([`Msg of string] -> 'a) ->
  (stdenv -> 'a) -> 'a
```

The main one of interest is `?block_size`. Basically, this allows us
to configure the eio runtime to use buffers of custom sizes for IO. In our
case, let's increase this to **1MB** and see how this affects performance. Our
new main function looks like this:

```ocaml
let () =
  Eio_linux.run ~block_size:1000000 (fun env ->
    ...
    copy src dst
  )
```

### Benchmark 3
![Benchmark3](/assets/img/benchmark_3.png)

Finally, a configuration and workload where the concurrent version
gets better performance! Huzzah!

## Conclusion 
If anything, I hope you can see that the destination we've
arrived at is the classic "it depends". The problem I've presented demonstrates
that even with opportunities for concurrency, it isn't going to be
immediately helpful. You'll still need to empathize with the problem and
understand the workload in order to correctly tune your program to benefit
from the concurrency. If not, you could end up paying more for it.

This was an introduction to using concurrency with eio.
I've waved my hands a lot and hidden a lot of details. The next post will
be a deep dive into a bunch more considerations that arise when you peer
behind the curtain and see the actual machinery behind calling an IO
function with eio and the data making it onto disk.
