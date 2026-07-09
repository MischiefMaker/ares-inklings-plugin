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
    # or secret (either direction).
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

    reference :inkling, "AresMUSH::Inkling"
    reference :author, "AresMUSH::Character"
    # Set only when this message was pulled in from a JobReply on the
    # linked job (see Inklings.sync_job_replies). Lets the sync tell
    # which replies it's already mirrored, so it doesn't duplicate them.
    reference :source_job_reply, "AresMUSH::JobReply"

    index :inkling_id
    index :source_job_reply_id
  end

  # Reverse reference so char.inklings gives every thread that character
  # is the subject of.
  class Character
    collection :inklings, "AresMUSH::Inkling"
  end
end
