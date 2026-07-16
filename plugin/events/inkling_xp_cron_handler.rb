module AresMUSH
  module Inklings
    # Handles the engine's CronEvent, sent once a minute by the Cron
    # system, and - when the event time matches the configured
    # award_cron schedule - runs the bonus XP award cycle. Follows the
    # standard pattern from
    # https://www.aresmush.com/tutorials/code/cron.html
    #
    # Registered via Inklings.get_event_handler below, per
    # https://www.aresmush.com/tutorials/code/events.html
    class InklingXpCronHandler
      def on_event(event)
        config = Global.read_config("inklings", "award_cron")
        return if !Cron.is_cron_match?(config, event.time)

        Inklings.run_xp_award_cycle(event.time)
      end
    end
  end
end
