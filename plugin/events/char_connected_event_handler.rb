module AresMUSH
  module Inklings
    # Fired when a character connects. Verified against the real
    # AresMUSH source (not guessed - see plugins/login/login.rb's
    # get_event_handler and plugins/login/events/char_connected_event_handler.rb
    # in https://github.com/AresMUSH/aresmush): the event is
    # "CharConnectedEvent" and exposes event.char_id (the connecting
    # character's id) and event.client.
    #
    # notify_player/Login.emit_ooc_if_logged_in (used everywhere else in
    # this plugin for real-time notifications) only reach a character
    # who is already online at the moment the underlying event fires -
    # anything that happened while they were offline is otherwise
    # silently missed entirely. This handler closes that gap: on every
    # connect, check for inklings with unread content (the same
    # definition +inkling/new uses - see Inklings.unread_inklings_for)
    # and, if any exist, send one summary line pointing at it.
    class CharConnectedEventHandler
      # Debounce window: don't re-notify the same character again this
      # soon, even if CharConnectedEvent fires again before they've had
      # a chance to act on the first notice - a client can legitimately
      # reconnect several times in quick succession (web socket
      # reconnects, multiple client windows, idle timeouts), and without
      # this a still-unread inkling would trigger a fresh notice on
      # every single one of those. In-memory only, same pattern as
      # InklingResetCmd's pending_confirmations - a server restart just
      # clears it, which is harmless; this exists purely to collapse a
      # burst of reconnects into one notice, not to remember "have I
      # ever told them" forever.
      NOTIFY_COOLDOWN_SECONDS = 300

      @last_notified = {}

      class << self
        attr_accessor :last_notified
      end

      def on_event(event)
        char = Character[event.char_id]
        return if !char

        last = self.class.last_notified[char.id]
        return if last && (Time.now - last) < NOTIFY_COOLDOWN_SECONDS

        unread = Inklings.unread_inklings_for(char)
        return if unread.empty?

        self.class.last_notified[char.id] = Time.now

        count = unread.count
        message = "<inklings> You have #{count} inkling#{count == 1 ? "" : "s"} with updates from while you were away. Use +inkling/new to review #{count == 1 ? "it" : "them"}."
        Inklings.notify_player(char, message)
      end
    end
  end
end
