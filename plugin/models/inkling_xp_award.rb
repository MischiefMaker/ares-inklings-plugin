module AresMUSH
  # Tracks bonus-XP awards granted by the inkling-type XP cron job
  # (see Inklings.run_xp_award_cycle). Exists purely to guarantee a
  # character is never credited twice for the same award period, even
  # if the cron job fires more than once for that period or the
  # process restarts mid-cycle.
  class InklingXpAward < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"

    # Identifies which award period this record belongs to: the
    # timestamp (as a string) marking the start of the period being
    # evaluated - i.e. the end of the *previous* completed cycle. This
    # only changes once a full cycle finishes successfully (see
    # InklingXpCronState below), so a crash mid-cycle and subsequent
    # retry reuses the same period_start. Characters who already have
    # a record for that period_start are correctly skipped on retry
    # instead of being double-awarded.
    attribute :period_start
    attribute :awarded_at
    attribute :xp_amount

    index :character_id
    index :period_start
  end

  # Singleton record tracking when the inkling-type XP award cycle
  # last completed successfully. There should only ever be one of
  # these - use Inklings.xp_cron_state to fetch (or lazily create) it,
  # rather than querying this model directly.
  class InklingXpCronState < Ohm::Model
    include ObjectModel

    # Timestamp (as a string) marking the end of the last successfully
    # completed award cycle. Becomes the *next* cycle's period_start.
    # Nil until the very first cycle completes.
    attribute :last_period_end
  end
end
