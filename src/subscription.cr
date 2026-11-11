module EventHandler
  # A single event subscription that remembers how to cancel itself.
  #
  # The *target* is captured at subscribe time inside the cancel closure, so
  # `#off` always removes from the exact object it added to, regardless of
  # where the owner later points. `#off` is idempotent, so two teardown paths
  # can both call it without double-freeing; `#on` cancels any previous handler
  # first, so a slot re-armed repeatedly can't leak.
  #
  # *target* is any `EventHandler` includer (duck-typed: anything with the
  # generated `on(type, ...)`/`off(type, wrapper)` pair).
  class Subscription
    @cancel : Proc(::Nil)?

    # Asks the emitter whether the handler is still registered; `nil` for a
    # plain teardown block, which has nothing to ask.
    @live : Proc(::Bool)?

    # The `Wrapper` behind this subscription (in the erased
    # `Wrapper(Proc(Event, Nil))` form `AddHandlerEvent` listeners also get),
    # once the generated `on`/`once` returned it or `#on` armed it. `nil` for
    # an empty slot and for a plain teardown block (`Subscriptions#add`).
    getter wrapper : ::EventHandler::Wrapper(::Proc(::EventHandler::Event, ::Nil))?

    # An empty (inactive) subscription, armed later via `#on`.
    def initialize
    end

    # A subscription over an already-installed handler: *cancel* removes it.
    # This is the form the generated `EventHandler#on`/`#once` return, so
    # every subscription — whether built here or handed out by `on` — tears
    # down through the same idempotent `#off`.
    #
    # *live*, when given, reports whether the handler is still installed
    # (see `#live?`).
    def initialize(@cancel : Proc(::Nil), @wrapper = nil, @live : Proc(::Bool)? = nil)
    end

    # The registered handler's identity hash (`Wrapper#handler_hash`), for the
    # `off(type, hash)` bulk-removal form. Raises `ArgumentError` when this
    # subscription holds no wrapper (see `#wrapper`).
    def handler_hash : UInt64
      w = @wrapper || raise ::ArgumentError.new("Subscription holds no wrapper (empty slot or plain teardown block)")
      w.handler_hash
    end

    # Whether this subscription still holds a cancel, i.e. has not been torn
    # down through `#off`. It does not track the handler's presence on the
    # emitter: a `once` handler that auto-fired, or one removed through
    # `off(type, ...)`/`remove_all_handlers`, leaves the subscription active
    # until its own `#off` (a no-op by then).
    def active? : Bool
      !@cancel.nil?
    end

    # Whether the handler behind this subscription is still installed on its
    # emitter. Unlike `#active?` this does track the handler: it turns false
    # once a `once` handler has fired, or the handler was removed through
    # `off(type, ...)`/`remove_all_handlers`, as well as after `#off`. A
    # plain teardown block (`Subscriptions#add`) is live until its `#off`.
    def live? : Bool
      return false unless @cancel
      (l = @live) ? l.call : true
    end

    # Subscribes *block* to event *type* on *target*, first cancelling any
    # handler this slot already holds. Returns `self`.
    def on(target, type : T.class, once = false, async = ::EventHandler.async?,
           at = ::EventHandler.at_end, &block : T -> ::Nil) : self forall T
      off
      # `target.on` already returns a `Subscription`; this slot takes over its
      # cancel and wrapper, adding only the re-arm bookkeeping on top.
      sub = target.on(type, once: once, async: async, at: at, &block)
      @cancel = sub.cancel
      @wrapper = sub.wrapper
      @live = sub.live
      self
    end

    # The cancel closure, for a slot taking over this subscription (see `#on`).
    protected def cancel : Proc(::Nil)?
      @cancel
    end

    # :ditto:
    protected def live : Proc(::Bool)?
      @live
    end

    # Removes the handler if one is installed. Idempotent.
    def off : ::Nil
      if c = @cancel
        @cancel = nil
        c.call
      end
    end

    # `dispose`/`disposed?` aliases of `#off`/`!active?`, for callers whose
    # teardown vocabulary is `dispose` (e.g. reactive stacks). `#off` stays the
    # canonical spelling (it mirrors `on`/`off`).
    def dispose : ::Nil
      off
    end

    # :ditto: — whether this subscription has been torn down (no handler live).
    def disposed? : Bool
      !active?
    end
  end

  # A bag of `Subscription`s that are torn down together. `#on` adds a tracked
  # subscription and returns it, so a single one can still be re-armed or
  # cancelled individually; `#add` tracks a subscription made elsewhere, or a
  # plain teardown block; `#off` cancels every remaining one, idempotently.
  #
  # Subscriptions that are no longer live (`Subscription#live?`: cancelled
  # individually, or a `once` handler that fired) are dropped from the bag as
  # it grows, so a long-lived bag does not accumulate them, nor keep their
  # handlers' closures alive.
  #
  # Like the standard collections, neither class is synchronized: share one
  # between fibers running in parallel only under your own lock. (The
  # emitter's `on`/`off`/`emit` are safe to call in parallel.)
  class Subscriptions
    @subs = [] of Subscription

    # Bag size at which the next `#add` prunes dead subscriptions. Doubles
    # with the live population, keeping the pruning amortized.
    @prune_at = 16

    # Subscribes *block* to *type* on *target*, tracking it for a later bulk
    # `#off`. Returns the created `Subscription`.
    def on(target, type : T.class, once = false, async = ::EventHandler.async?,
           at = ::EventHandler.at_end, &block : T -> ::Nil) : Subscription forall T
      add target.on(type, once: once, async: async, at: at, &block)
    end

    # Tracks a teardown that is not an event subscription — a listener
    # registered with a config option, a timer, a file watcher — so the bag's
    # `#off` cancels it with the rest. *cancel* runs once, at the bag's `#off`
    # or at the returned `Subscription`'s own, whichever comes first. Returns
    # the created `Subscription`.
    #
    # ```
    # handle = Config.on_change("app.theme") { apply_theme }
    # subs.add { Config.off_change "app.theme", handle }
    # ```
    def add(&cancel : -> ::Nil) : Subscription
      add Subscription.new(cancel)
    end

    # Tracks an existing *subscription*, such as one `EventHandler#on`
    # returned, for the bag's bulk `#off`. Returns it.
    def add(subscription : Subscription) : Subscription
      if @subs.size >= @prune_at
        @subs.select!(&.live?)
        @prune_at = {16, @subs.size * 2}.max
      end
      @subs << subscription
      subscription
    end

    # Cancels every tracked subscription and empties the bag. Idempotent.
    #
    # Every subscription is cancelled even if one raises: the bag is emptied
    # first, each remaining one is still torn down, and the first exception
    # is re-raised at the end.
    def off : ::Nil
      subs = @subs
      @subs = [] of Subscription
      first = nil
      subs.each do |sub|
        sub.off
      rescue ex
        first ||= ex
      end
      raise first if first
    end

    # `dispose`/`disposed?` aliases of `#off`/`#empty?`. See
    # `Subscription#dispose`.
    def dispose : ::Nil
      off
    end

    # :ditto: — whether the bag has been torn down (holds no subscriptions).
    def disposed? : Bool
      empty?
    end

    # Whether the bag holds no subscriptions. Dead ones not yet pruned count.
    def empty? : Bool
      @subs.empty?
    end
  end
end
