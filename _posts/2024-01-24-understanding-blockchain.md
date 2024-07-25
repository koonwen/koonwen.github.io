---
layout: post
title: Understanding blockchain
cover-pic: "/assets/img/blockchain.png"
prerequisites:
tags:
date: 2024-01-24 11:50 +0800
toc: true
---
I've recently started reading about blockchain. To consolidate my
understanding, I've put together an executive summary about what this
technology is all about.

## The Problem
As always, we should start with the motivation for the technology. Do
we trust banks as middlemen for our purchases? Even if we do, it comes
back to that age old adage that we "shouldn't place all our eggs in
one basket". what should happen if that central authority goes down?
Now to rephrase the question more generally: can we have a trust-less
service that allows us to exchange value?  Initially, this seems like
an obvious contradiction because the whole point of the service is to
act as a trusted third-party in the transaction. With blockchain
however, we answer the question in the affirmative.

## Overview by example
Before diving into the technical under-workings of blockchain, it pays
to get a general sense of what it is based on. Let's say Alice and Bob
are performing an exchange. Alice hands Bob $10 and now Alice is now
$10 poorer and Bob is $10 richer. No trust is required because the
money was physically handed over. This is not how we usually make
transactions in the modern day though. Today we have banks that keep
track of how much we own and perform the transaction by deducting or
adding to our balance. So if Alice transfers Bob $10, Alice balance
sheet gets reduced by $10 and Bob increases by $10, no physical money
needs to exchange hands. That's simple enough. The problem with this
is that now we need to trust that the bank records this correctly and
doesn't make a blunder in updating the records (And all other worries
we have about trusting central authorities). This type of transaction
is akin to if Alice and Bob had a friend Charles that keeps track of
who owes who. In this case Alice owes Bob $10. This is problematic if
Charles mistakes the amount that was owed, worse still he may be
biased to his good friend Alice.

Now enter the third option, Alice, Bob and Charles live in a small
town of about 100 people. Instead of having only Charles keep track of
the exchange, what if everyone in the town helped out by individually
keeping track of the transaction. In such a case, we no longer have to
have to rely on Charles as a fair and trustworthy third-party. We can
spread our trust amongst the other 97 people in the town. If a dispute
where to happen, we can rely on the majority to validate the
transaction details. This is the premise of blockchain, a way to
distribute the responsibility of book-keeping. Of course, whilst this
is ideal, it has multiple problems.

- How do we secure transactions?
- How do we verify a transaction occurred?
- How do we get people to take part?

- How do we prevent people from requesting a transaction when they have insufficient funds?
- How do we agree on an order of transactions since everyone is bound to receive them in different orders?

The first three are the meat of blockchain technology and can be
described fairly generically. I will tackle those here. The last two
will be addressed in later posts discussing specific types of
blockchains.

### Forward
What I initially confused when learning about blockchain was the
process of securing a transaction and verifying that a transaction
occurred. To give the general idea, securing a transaction is about
knowing who currently owns the money. Verifying a transaction is then
the process of adding it to the public transaction log to confirms the
exchange of ownership of the money. To put it in less technical terms,
securing a transaction would be as though Alice signs her name that
she approves a transaction to Bob for $10. Verifying this transaction
would be to actually upgrade this local agreement to the global ledger
such that the transaction is visible to everyone.

### How do we secure transactions?
In the physical world, it suffices to say that if the money is
physically in my possession, it is mine (unless I've stolen it of
course). However, when dealing with digital currency, ownership is not
so straightforward. It turns out that the way to keep track of
ownership is by keeping a log of the history of transactions. You
could think of this as if we had to write down the name of the person
we were giving the money to before we pass it to them. To make this
chain secure so that only the people who own the money can spend it,
the transaction log is a trail of **cryptographically** secure
signatures of the people who previously owned it until it's current
owner. Cryptography in this sense, is used to make stealing or
masquerading as someone else computationally infeasible.

The technical term for this is called **Asymmetric cryptography (Or
public key cryptography)**. At a high level, this works by each user
have a pair of keys. A public one and a private one. The public one is
available to other users whilst the private one is kept a secret only
to the user. These pair of keys have a unique feature to them which is
that they can be used to digitally sign a message and make it close to
impossible to forge. Procedurally, signing and verifying looks like
the following:

``` text
Sign(Message, private_key) => Signature

Verify(Message, Signature, public_key) => True/False
```

As mentioned, the important feature of this encryption process is that
it is there is no known way to reverse-engineer it. Knowing how the
algorithm works doesn't allow one to discover the private
key. Furthermore, a slight change in the message contents, causes
wildly different signature so there's no relationship/pattern we can
use to generate a valid signature other than guessing and checking.

Hence we arrive at the term cryptocurrency. We can now see where and
why cryptography is applied to the digital currency.

### How do we verify transactions?
After a secure transaction is broadcasted, it ends up in a pool of
"pending transactions". At this time, we introduce other actors in the
system known as "miners". In our example, the minors are analogous to
anyone in the town. The job of the miner is to pick up these
transactions and then validate them so that they end up on the public
ledger. For this process to occur, miners must first complete a
computational "challenge/puzzle". Upon completion, it awards them a
prize and the ability to append a new block (some set of pending
transactions) onto the chain. It should be noted that appending a
block onto the chain doesn't yet guarantee permanence or legitimacy of
the action. Instead, nodes work on the policy of following the longest
chain. This means that even if a bad actor were to successfully solve
the challenge before other nodes, it would only be able to append a
single block. To keep up with it's scam, it would have to continuously
outperform the rest of the miners to have it's chain become
validated. Unless the bad actor has the computational power of more
than 50% of the system, it is proven that it is computationally
infeasible for a bad actor to invalidate the system.

### How do we get people to take part?
A vital part to a functioning blockchain is that there are a
distributed set of machines called "nodes" that are working to
validate transactions. Similar to how we have people in the town
actively keeping track of transactions that happen. To reward the
nodes, a node is given with a small amount of the
cryptocurrencies. This keeps people/businesses incentivized to run
their nodes participating in the exchange. On top of that, some
transaction even offer transaction fees that goes to the nodes (known
as miners) that successfully validate their transaction.

## Conclusion
To come full circle, given my understanding of blockchain works, I
don't think it's accurate to say that it's trust-less. I think it is
trust-less in so far as we think of it as having no central
authority. It still remains the fact that we need to have trust in the
**majority** of actors in the system.  I suppose the answer is still
fairly clear that it's better to place our bets on the majority rather
than a single entity, no matter how trustworthy.
