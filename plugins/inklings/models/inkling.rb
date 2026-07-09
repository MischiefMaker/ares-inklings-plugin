module AresMUSH
  # Database models live in the base AresMUSH module (not the plugin's
  # own module), even though the files live under the plugin folder.

  # A single inkling thread. Covers all kinds - staff-to-player,
  # player-to-staff, and secrets in either direction - since they all
  # share the same shape: a subject character, a status, an optional
  # linked job, and a series of messages.
  class Inkling < Ohm::Model
    include ObjectModel

    # kind is one of: hint, vision, nudge, hook (staff -> player),
    # action, research, request, update, pitch, goal (player -> staff),
    # secret (IC character secret, shareable with other players),
    # or roll (either direction).
    attribute :kind
    # "open" or "closed"
    attribute :status
    attribute :created_at
    # "true"/"false" - whether the player has unread staff messages
    # on this thread.
    attribute :player_unread

    # The player this thread concerns. Always a player character,
    # regardless of who started the thread or which direction it runs.
    reference :character, "AresMUSH::Character"
    # Whoever started the thread - staff or the player themselves.
    reference :creator, "AresMUSH::Character"
    # Only set once staff need to be notified (i.e. once a player has
    # created, replied to, or deleted a thread). Inklings' own data is
    # never stored on the job - this is purely a notification/tracking
    # link back into the normal job workflow.
    reference :job, "AresMUSH::Job"

    collection :messages, "AresMUSH::InklingMessage"
    collection :rolls, "AresMUSH::InklingRoll"
    collection :participants, "AresMUSH::InklingParticipant"

    index :character_id
    index :kind
    index :status
    index :job_id
  end

  # A single message within an inkling thread.
  class InklingMessage < Ohm::Model
    include ObjectModel

    attribute :text
    attribute :created_at
    # "true"/"false" - was the author staff at the time they wrote this
    attribute :is_staff
    # "true"/"false" - visible only to the author and staff; hidden from
    # other participants in the thread.
    attribute :is_private

    reference :inkling, "AresMUSH::Inkling"
    reference :author, "AresMUSH::Character"
    # Set only when this message was pulled in from a JobReply on the
    # linked job (see Inklings.sync_job_replies). Lets the sync tell
    # which replies it's already mirrored, so it doesn't duplicate them.
    reference :source_job_reply, "AresMUSH::JobReply"

    index :inkling_id
    index :source_job_reply_id
  end

  # A roll attached to an inkling. Can be used for system rolls (FS3, etc.)
  # or just tracking arbitrary roll results.
  class InklingRoll < Ohm::Model
    include ObjectModel

    # The inkling this roll is attached to
    reference :inkling, "AresMUSH::Inkling"
    # The character who made the roll (for player rolls)
    reference :character, "AresMUSH::Character"
    # The character this roll is about (may differ for staff rolls)
    reference :target_character, "AresMUSH::Character"
    # The character who created the roll (staff or player themselves)
    reference :creator, "AresMUSH::Character"

    # Roll type: "player" (player rolling for themselves), "npc" (staff
    # rolling for an NPC), "static" (just a number)
    attribute :roll_type

    # For player/npc rolls: the FS3 skill/attribute rolled
    # For static: description of what this number represents
    attribute :roll_spec

    # The result of the roll as a string (e.g. "8" or "Mediocre (5)")
    # This is free-form to support any roll system
    attribute :result

    # The raw numeric result for sorting/comparison
    attribute :result_value

    # "true"/"false" - whether this roll is visible only to the player
    # and staff, or visible to all participants in the inkling thread
    attribute :private

    # Number of times this roll has been rerolled
    attribute :reroll_count

    # Cost in luck points if this was a luck reroll (0 = no luck used)
    attribute :luck_cost

    attribute :created_at
    attribute :rolled_at

    index :inkling_id
    index :character_id
    index :target_character_id
    index :created_at
  end

  # Tracks additional players who have been granted access to an inkling
  # thread (e.g. the other party in a shared IC secret). The owning
  # character and creator always have access; this covers anyone else.
  class InklingParticipant < Ohm::Model
    include ObjectModel

    reference :inkling, "AresMUSH::Inkling"
    reference :character, "AresMUSH::Character"
    attribute :added_at

    index :inkling_id
    index :character_id
  end

  # Reverse reference so char.inklings gives every thread that character
  # is the subject of.
  class Character
    collection :inklings, "AresMUSH::Inkling"
  end
end
