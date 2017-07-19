# What is This?

__Gavel__ is a library which adjudicates orders in the game _Diplomacy_. It was written for use with the [Dead Potato](http://deadpotato.org) application which is currently still in development. The implementation is based loosely on _The Math of Adjudication_ by Lucas Kruijswijk.

## Developer Documentation

### Important Conventions

The variables _from_, _to_, _target_, _supporter_, and _convoyer_ by convention denote a region (just like you would expect in the regular game). _type_ typically denotes the type of an order (MOVE, SUPPORT, CONVOY).

### Modules
__CycleException:__ Used to indicate that a cycle has occurred in the sequence of recursive calls in the course of order resolution.

__CycleGuard:__ Implementation allows us to kick off a mutual recursion and then detect and handle scenarios where a cyclic recursion occurred. Intended to simplify situations which are naïvely recursive but where cycles can occur in the recursion. In this way, we can outline a strategy for dealing with these cycles and keep the underlying recursion simple.

__DATC:__ Handles running the DATC compliancy tests which are a series of published tests intended to verify new adjudication tools. They can be found [here](http://web.inter.nl.net/users/L.B.Kruijswijk/).

__Engine:__ A facade into the underlying functionality of the library. Should contain a minimum of its own functionality and should be mosty focused on integrating other components.

__Resolver:__ Responsible for low level adjudication of orders according to the rules. Doesn't know about orders formats, map data, etc. except via other components but is solely responsible for the logical aspects of adjudication.

__utils:__ Contains `attackStrength`, `defendStrength`, `holdStrength`, `holdStrength`, `preventStrength`, `support` which correspond to the described values in _The Math of Adjudication_.

__describe:__ Convert logics to human readable text to use as output for testing. E.g. some object describing orders gets translated into "Turkey Moves A to Romania".

__parseOrder:__ What it sounds like - parse orders provided in a text format and convert them to useful objects. Primarily useful for testing.