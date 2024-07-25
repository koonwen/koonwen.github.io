---
layout: post
title: Continuation-Passing-Style for the pragmatic layman
cover-pic: "/assets/img/cps-cover.jpg"
date: 2024-01-07 16:47 +0800
prerequisites: OCaml | Tail-recursion
toc : true
---
I've always found continuation-passing-style (CPS) one of the more an
elusive concept to grasp. Today I came across a simple tree traversal
problem that helped me work through some of that complexity.

## The Problem
Suppose you are given an integer value `target` and a binary tree
whereby each node has a integer value assigned to it. Identify if a
path exists from the root to leaf whereby the total sum of the path
equates to `target`.

### Solution 1: Classic recursion
At first glance, this question can be solved with the classic
recursive approach. That is, we recursively traverse down the tree
until we hit a leaf node as our base case. Along the way, we subtract
the value of the current node from the `target` and pass on the
difference. In the base case, we now have the result whether the sum
of the path is equal to the `target` and we will need to bubble up the
result. In OCaml, we would have something like

{% highlight ocaml %}
type 'a node =
  | Lf
  | Br of 'a * 'a node * 'a node

let rec find_path node target =
  match node with
  | Lf -> target = 0
  | Br (v, l, r) ->
      let lv = find_path l (target - v) in
      let rv = find_path r (target - v) in
      lv || rv
{% endhighlight %}

This works, but it's very memory intensive. The recursive calls blow
up the stack with a lot of pending function frames. Can we do better?
More precisely, can we make this function tail-recursive?

Not all functions are created equal. Some happen to be easier to be
converted their tail-recursive counterparts. Unfortunately,
`find_path` is one of those difficult functions. The reasons why this
is the case currently escapes me and will be tackled in a later
post. For now, let's assume that to be the case. (Or you can try
to come up with the tail-recursive solution yourself)

### Solution 2: CPS transformation
Turns out, the way to convert such a function to a tail-recursive
version is to leverage the idea of *continuations*. There's a lot of
technical literature on the topic obfuscating what the term refers
to. To my mind, it just means "what is next thing to do". In other
words, if you ran a program and paused it at some arbitrary point
(think a debugger), what's left to do is the continuation of that
program. So continuation-passing-style, is a way of programming where
we explicitly pass functions "the next thing to do". What does that
look like in code? Instead of functions returning values to the
caller, we can design functions that return with a new function call.

{% highlight ocaml %}
let find_path_cps node target =
  let rec aux node target k =
    match node with
    | Lf -> k (0 = target)
    | Br (v, l, r) ->
        aux l (target - v) (fun lv ->
            aux r (target - v) (fun rv ->
                k (lv || rv)))
  in
  aux node target Fun.id
{% endhighlight %}

This looks confusing and it is. I took some time to really process
what exactly is going on in this function. Let's start with the most
obvious. Firstly our cps version defines an auxiliary function with an
added parameter `k` that stands for continuation. This parameter can
be thought of as a kind of accumulator that builds up the things "left
to do" in the same way that the recursive solution builds up stack
frames to keep track of pending computation to execute later. In CPS
we don't leave anything in the stack pending instead by passing the
*continuation* represented by a function to the next recursive
call. In such a way, our cps inspired function is now tail-recursive
by passing around a function pointer.

### Solution 3: Short-circuiting CPS
Reducing memory usage is one of the main advantages of CPS but it also
allows us to "short-circuit" functions. Specifically for the case of
`find_path` we could design it in such a way to "forget" about what's
left to do and have an escape hatch that allows us to return early
once we found a path that exists.

{% highlight ocaml %}
let find_path_cps_fast node target =
  let rec aux node target k =
    match node with
    | Lf -> k (0 = target)
    | Br (v, l, r) ->
        aux l (target - v) (fun lv ->
            aux r (target - v) (fun rv ->
                if lv then true else k rv))
  in
  aux node target Fun.id
{% endhighlight %}

In this new implementation, we insert a conditional within the
continuation to ignore searching down the right subtree.

## Benchmarks
Initializing a balanced binary tree of height=26 => 67108863 nodes
with a single valid path down the left spine, we get the following
results

``` bash
        recursive: 13.87 WALL (13.87 usr +  0.00 sys = 13.87 CPU) @  0.72/s (n=10)
              cps: 18.27 WALL (18.27 usr +  0.00 sys = 18.27 CPU) @  0.55/s (n=10)
cps short circuit:  0.00 WALL ( 0.00 usr +  0.00 sys =  0.00 CPU) @ 3333333.34/s (n=10)
```

Clearly, the test case is skewed to show the best performance of the
`cps short circuiting` function. If the valid path was down the right
of the tree, we would get similarly bad performance as the `cps`
implementation. What's interesting is perhaps the bad performance of
our `cps` implementation. My guess is that whilst we are saving on
stack memory, we have moved the recursion into heap memory by
allocating pointers onto the heap which is invariably slower.

This finding motivated me to dig into seeing when we actually benefit
from writing stack-saving cps functions. For this particular case, our
recursive call depth is limited by the height of the tree which is
pretty shallow, not nearly big enough to burst the stack. This means
that one needs to consider the actual depth of the recursive calls and
whether they realistically place any stress on the stack. A traversal
over a list is perhaps a more motivating case for a CPS transformation
than our tree here. In fact, I ended up running out of memory just by
the allocation of the tree alone. To which we come to the second
interesting observation, you need to consider that your CPS function
will be competing with your data structure (if any) for resources on
the heap. For most user programs, we don't usually get that kind of
scale for data structures anyway. It usually makes sense to opt for
the simpler recursive solution.

(In utop and OCaml bytecode programs, the stack limit is 1024k words
whilst natively compiled programs depend on the system limits which
is 8192 in my case)

> Food for thought: Continuations are an abstraction of the program stack
