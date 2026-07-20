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
      def on_event(event)
        char = Character[event.char_id]
        return if !char

        unread = Inklings.unread_inklings_for(char)
        return if unread.empty?

        count = unread.count
        Inklings.notify_player(char, "<inklings> You have #{count} inkling#{count == 1 ? "" : "s"} with updates from while you were away. Use +inkling/new to review #{count == 1 ? "it" : "them"}.")
      end
    end
  end
end
