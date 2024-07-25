---
layout: post
title: Disciplined indexing with Binary-search
date: 2024-01-18 20:33 +0800
cover-pic: "/assets/img/bin-search-cover.jpg"
prerequisites: Python | Binary Search
toc: true
---
The topic for today's article was churned up out of frustration thanks
to the classic "off-by-one" error. The especially annoying thing is
that Binary-search is one of those elementary algorithms that you
should be able to produce without hiccup. Except that it's happened
now a couple times that I spend way too long figuring out where I'm
messing up the indices. With this article, I put forth a set of
"rules" to think about when implementing binary search in future.

## Binary Search: a summary
Binary search is a quick way to search technique given an **ordered
collection**. The search runs by looking at the arbitrary midpoint and
checking if we should continue the search to the left or to the
right. We do this same process until we end up with just one element,
at which point we can decide that the search was successful or
not. Being able to halve the problem every time leads to a fantastic
time complexity of O(log(n)).

## Bisect > Binary search
One thing I learnt about approaching Binary search problems, is that
you should think about them instead as a bisection problems. This
means that rather than viewing the algorithm as a search method, we
look at it from the vantage point of a method to reduce our search
space. This subtle shift in mind-set arrives at a different
perspective of our usual "We use Binary search to look for an element"
to "We use Binary search to throw away the bits that don't matter".

Still confused? Let's put it into concrete terms. Given some sorted
array `arr` of elements, identify if the element `k` is in the
array. If we are thinking about this in terms of bisection, our
question is now: "identify the smallest index where the element is
equal to `k`"

Here are some example arrays where we'd expect the final index to land
``` text
k = 3

Case1:[1,2,3,4,5,6]
           ^
Case2:[3,3,3,3,3,3]
       ^
Case3:[1,2,3,3,3,4]
           ^
Case4:[1,1,1,1,1,1]
                   ^
Case5:[4,4,4,4,4,4]
       ^
```

Cases1-3 are fairly self explanatory, we landed on the index where the
element under the index is equal to 3 `and` is also the earliest 3 we
encounter if we traverse the list from left to right. How about Case4?
What if 3 is not in the list? Then by our bisection criteria, we
should rightly land outside the list, Translated into indices, we only
have `0 - N-1` index elements, but we will allow our search to also
land on `N`. This means that if our index is on `N` we can conclude
that `k` is not in the array.

However, look at Case5. Although `3` is not in the list, the final
index lands on position `0` (In accordance to how expect the search to
move leftwards rather than to the right as in Case4). This is a
problem, shouldn't we also allow `-1` to be a possible index to land
on? The answer is yes but mostly no. Yes, in that we should be landing
outside the array bounds following the bisection principle. No because
this will complicate how we decide to bisect the array as well as how
we find divide to find the midpoint. The workaround is to have two
checks at the end:

- Make sure you're within array bounds
- if you're within, check that the element under my index is equal to
  `k`

## Termination
Another thing to make sure to get right, is that the algorithm doesn't
get stuck looping on the same index. The key to this are three things,
the **loop invariant**, how you find the **midpoint** and how you get the
new **array bounds**. These three **MUST** be compatible to ensure
that your algorithm will eventually hit the base case. One combination
that works is:

``` python
loop invariant: lo < hi

midpoint: (lo + hi) // 2    # floor division

array bounds: if arr[midpoint] == k:
                  hi = midpoint
              else:
                  lo = midpoint + 1
```

Let's go through why this work, starting with the array bounds. Given
our bisection criteria again, if the element we are currently on is
equal to `k`, we may or may not be on the smallest index. Eitherways
we have to keep it's index **inside** the array bounds so we only
update `hi = midpoint`. In the `else` case, we know for certainty that
we can exclude the current index, therefore the '+1'.

For the midpoint calculation, we use floor division which gives us the
following properties. If the number of elements we are considering is
`odd` we have an true midpoint. Floor division gives the correct index
of that midpoint when we use indices bounds. E.g. `(0 + 4) // 2 = 2`.
**index 2** in the `[1,2,3,4,5]` is the element 3, perfectly in the
middle. However, if we are performing the division for an even number
of elements, then we land to the left of the middle. So the index that
we land on for the array `[1,2,3,4]`, would be `(0+3) // 2 = 1`
**index 1**, which is **element 2**.

With the above constraints, the only way we can "get stuck" is if we
always calculate the same midpoint and the value under the midpoint
index is equal to `k`, so that `hi` remains the same. We can narrow
this down further to when `lo` and `hi` are next to each other since
our loop invariant exits when `lo == hi`. Now we just have to realize
that our previous argument said that if we are considering an even
number of elements, we always end up to the left of the middle. That
means that our `hi` will always progress to equal `lo` and terminate
the loop invariant. Nice!

## All in all
Now why go through all that effort to turn the binary search into
bisection? For a lot of questions I've run into, binary search is
often employed to find bisection. E.g "Find the earliest occurrence in
a git history of a bad commit". In such cases, I mess up by being
"one-off" because the search criteria in my head is looking for an
exact point. Trying to edit it after is like working out if the three
factors for termination play nice which is a disaster. Bisection works
in both cases so it's much better to go with one disciplined approach.

Our final solution looks something like this that can be modified
based on the specific algorithm

``` python
def bin_search(arr, k):
    lo, hi = 0, len(hi)   # We include the len(hi) index as discussed earlier
    while lo < hi:
        midpoint = (lo + hi) // 2
        if arr[midpoint] == k:
            hi = midpoint
        else:
            lo = midpoint + 1
    return lo < len(arr) and arr[lo] == k
```

Checking either `lo` or `hi` will work because it is always the case
that they will be equal to each other.

Of course there are different ways to design this focusing on
different bisection criteria. But since I've gone through the effort
to prove to myself that this combination works, I'll take this as my
template solution.

##### A lot of my ideas here are inspired by this great [article][article].

[article]: http://coldattic.info/post/95/
