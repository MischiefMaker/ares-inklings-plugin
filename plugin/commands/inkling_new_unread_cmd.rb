module AresMUSH
  module Inklings
    # +inkling/new (no args) - mimics the bulletin board's +bbnew: shows
    # the single oldest inkling you have unread content on, one thread
    # per invocation. Run it again to advance to the next-oldest.
    #
    # Takes no arguments by design, so it can never collide with
    # +inkling/create <kind>=<title>/<text> (InklingCreateCmd) - a
    # separate switch entirely, see Inklings.get_cmd_handler.
    class InklingNewUnreadCmd
      include CommandHandler

      def handle
        queue = Inklings.unread_inklings_for(enactor)

        if queue.empty?
          client.emit_success t('inklings.new_no_unread')
          return
        end

        Inklings.show_inkling(queue.first, enactor, client)

        remaining = Inklings.unread_inklings_for(enactor).count
        client.emit_success t('inklings.new_remaining', :count => remaining) if remaining > 0
      end
    end
  end
end
