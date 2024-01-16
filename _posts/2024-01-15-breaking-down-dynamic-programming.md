---
layout: post
title: Breaking down Dynamic-Programming
cover-pic: "/assets/img/greedy-cover.jpg"
prerequisites: Python
tags:
date: 2024-01-15 23:22 +0800
---
Dynamic-Programming (DP) is one of those things that makes my brain
overheat. To a first approximation, DP is an algorithmic trick that
improves the time complexity of otherwise exponential algorithms. DP
manages this because it avoids doing unnecessary re-computation - A
common feature that causes problems to grow exponentially. Instead
of re-computing something we've already done before, DP says "let's
store this result because I'll have to refer back to it".  Sound
simple? In practice, not so much. This post tries to provide a clear
step by step to approach such problems.

## When does DP apply?
The first thing that makes DP challenging is that it's not clear when
it applies. I believe there's no simple way to figure it out
either. So far, I use some heuristics like thinking about if the
problem asks for "an optimal combination". This usually means that the
brute force solution would have you calculate *all possibilities* to
find the best one. This is the dead giveaway that your algorithm
diverges. That said, sometimes problems that seem like DP could
actually just by a simple Greedy algorithm, so it's worth trying that
approach first before committing to DP.

## A Problem
Calculate the i-th term Fibonacci sequence
``` math
Fib(n) = Fib(n-1) + Fib(n-2)
```

### Naive solution
This is pretty much in your face exponential because of the recursive
definition. Implementing it recursively is basically brute force and
would yield exponential time complexity

{% highlight python %}
def fib(n):
    if n <= 1:
        return 1
    else:
        return fib(n-1) + fib(n-2)
{% endhighlight %}

### Looking Top-down
The problem with our recursive solution is that we have a lot of
branching and incur many repeated sub-computation.

```
              fib(4)
             /      \
        fib(3)       fib(2)
        /   \        /    \
    fib(2)  fib(1) fib(1) fib(0)
    /    \
fib(1)  fib(0)

We can see that *fib(2)* is repeated 2 times and fib(1) and
fib(0), 3 and 2 times respectively.
```

One way to visualize your algorithm is to think if the evaluation
expands into a N-branch tree. In that case, you can start think if you
can leverage **Memoization**. Memoization is the one of two DP
approaches. As per the name, here the memo is where we are going to
save the result of some sub-computation and lookup later when we need
it. How we'll do this is to add a table lookup just before we descend
into the recursion and make sure to save the results into the table
when we get them.

{% highlight python %}
memo = dict()

def fib(n):
    if n in memo: return memo[n]
    if n <= 1:
        return 1
    else:
        res = fib(n-1) + fib(n-2)
        memo[n] = res
        return res
{% endhighlight %}

If you can't yet tell, this basically causes the recursion to
short-circuit because it can find the previously computed results in
the table. Our runtime is significantly better since we only really
descend down the left side of the tree and every subsequent right
child's result cost a single constant lookup. Something to note about
the time complexity is that this is O(n), not O(log(n)). You might be
quick to assume that because of the tree I drew but actually we
descend n times down the left side, so we haven't split the problem in
half.

> We call this a top-down approach because the recursive call begins
> at the top and bottoms out at the base case and builds back up the
> result.

### From Bottom-up
The second technique DP technique is called **Tabulation**. With this
method, we skip the recursion downward and just start directly from
the base case and build the result up. We also use a table to keep
track and reference our previous results. Our Fibonacci problem is not
the most motivating case for a table (explained later) but I will
demonstrate it anyway. For intuition, instead of trying to calculate
our results from the top, notice that working from the bottom pretty
easy. That is, we can find fib(2) easily because it is fib(1) + fib(0)
which we know to be 1 + 1 effectively. Then fib(3) is fib(2) + fib(1)
and we just calculated the result of fib(2), and so forth.

``` python
def fib(n):
    tbl = [0] * n
    tbl[0], tbl[1] = 1, 1
    for i in range(2, n):
        tbl[i] = tbl[i-1] + tbl[i-2]
    return tbl[n-1]
```

In this implementation, we iteratively calculate up toward the value
that we want using the result of previous calculated
result. Leveraging the same idea used in memoization, just in a
different style.

> This is bottom-up because we start directly from the base case. An
> interesting note is that memoization usually involves recursion and
> tabulation uses simple iteration so it is generally faster because
> it doesn't need to allocate stack frames for the recursive function
> calls.

## A Harder Problem
As alluded to, using tabulation for the Fibonnacci problem is
unnecessary here because we only really need to keep track of one
variable to calculate the subsequent result. Tabulation shines when
there are multiple "choices" to be made. Let's see an example:

"The assembly-line problem: Given 2 assembly lines, each with M
stations where M is some given integer value representing the time
taken at the station. Determine the shortest path that can be taken
through the factory if there is also a cost to transferring between
assembly lines"

``` text
Line1: 5 -> 2  -> 10 -> 7
Line2: 1 -> 12 -> 1  -> 1

Line1 to Line2 transfer cost: [2, 1,  5]
Line2 to Line1 transfer cost: [1, 12, 15]

The optimal solution is the following:
Line1:    5    2   10   7
             /   \
         +1 /     \ +1
           /       \
Line2: -> 1    12    1 -> 1  => 1 + 1 + 2 + 1 + 1 + 1 = 7
```

It's worth looking first what the recursive solution might look like
``` python
def path(l1, l2, l1_l2, l2_l1):
    length = len(l1)
    def aux(i, line, line_other, switch, switch_other):
        if i == 0:
            return line[0]
        elif i == length:
            return min(aux(i-1, l1, l2, l2_l1, l1_l2), aux(i-1, l2, l1, l1_l2, l2_l1))
        else:
            stay = aux(i-1, line, line_other, switch, switch_other)
            switch = aux(i-1, line_other, line, switch_other, switch) + switch[i-1]
            return min(stay, switch) + line[i]
    return aux(length, l1, l2, l2_l1, l1_l2)
```

As you can see, we have to keep track of multiple variables in our
`aux` recursive function which makes the code rather clunky. Adding in
memoization would just make it even more complex. Now look at the
tabulation solution

``` python
def path_tab(l1, l2, l1_l2, l2_l1):
    length = len(l1)
    for i in range(1, length):
        l1[i] += min(l1[i-1], l2[i-1] + l2_l1[i-1])
        l2[i] += min(l2[i-1], l1[i-1] + l1_l2[i-1])
    return min(l1[length-1], l2[length-1])
```

The iterative solution to my mind is much easier to follow what is
going and also overall cleaner. Unlike the recursive solution, we
don't have to pass on variables to the next recursive call.

## Conclusion
This sums up the introduction to Dynamic programming, why it works,
when it applies and the trade-off between the two main techniques.

> When you see branching with similar looking sub-branches, it's
> probably going to need DP.
