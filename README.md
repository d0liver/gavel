# What is This?

__Gavel__ is a library which adjudicates orders in the game _Diplomacy_. It was written for use with the [Dead Potato](http://deadpotato.org) application which is currently still in development. The implementation is based loosely on _The Math of Adjudication_ by Lucas Kruijswijk.

## Developer Documentation
__CycleException:__ Used to indicate that a cycle has occurred in the sequence of recursive calls in the course of order resolution.

__CycleGuard:__ Implementation allows us to kick off a mutual recursion and then detect and handle scenarios where a cyclic recursion occurred. Intended to simplify situations which are naïvely recursive but where cycles can occur in the recursion. In this way, we can outline a strategy for dealing with these cycles and keep the underlying recursion simple.

__DATC:__ Handles running the DATC compliancy tests which are a series of published tests intended to verify new adjudication tools. They can be found [here](http://web.inter.nl.net/users/L.B.Kruijswijk/).

__Engine:__ Pretty much what it sounds like. Uses the OrdersParser, Resolver, etc. to deduce the correct adjudication for the given orders.

__Resolver:__ Responsible for low level adjudication of orders according to the rules. Doesn't know about orders formats, map data, etc. except via other components but is solely responsible for the logical aspects of adjudication.