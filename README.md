# lambra [![Build Status](https://secure.travis-ci.org/txus/lambra.png)](http://travis-ci.org/txus/lambra)

Lambra is an experiment to implement a functional, distributed Lisp on the
[Rubinius](http://rubini.us) Virtual Machine, much à la Erlang.

## Architecture

Lambra processes are much like Erlang's, but implemented as native OS threads.
They share absolutely no memory, and behave like actors: they communicate via
their mailboxes.

### A simple echo program with actors

```lisp
(defn echo []
  (receive
    [pid msg] (send pid self msg)))

(let [echo-pid (spawn echo)]
  (send echo-pid self "Hello world!")
  (receive
    [pid msg] (print msg)))
```

The actor primitives in Lambra are `receive` and `send`.

`receive` blocks until a message in the mailbox can be processed, then pattern
matches (`[pid msg]` is a catch-all clause) and executes the form that matched.

`send` sends a message to the mailbox of an actor. It just needs its `pid`, and
the rest of the arguments will be sent as a message. It is a convention for the
first argument of the message to be the sender's `pid`, but it is in no way
necessary.

`self` is the current process' `pid`.

## Credits

The structure for this first version is taken from Brian Shirai's
[Poetics](http://github.com/brixen/poetics).

Joe Armstrong for his `Programming Erlang` book, and well, for Erlang.

## Who's this

This was made by [Josep M. Bach (Txus)](http://txustice.me) under the MIT
license. I'm [@txustice](http://twitter.com/txustice) on twitter (where you
should probably follow me!).
