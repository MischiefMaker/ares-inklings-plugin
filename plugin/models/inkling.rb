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
    # or secret (IC character secret, shareable with other players).
    # Rolls are not a kind — they can be attached to any inkling.
    attribute :kind
    attribute :title
    # "open" or "closed"
    attribute :status
    # Comma-separated group specs (e.g. "Navy" or "Faction:Navy,Marines").
    # Any character whose group membership matches a spec has access, even
    # if they were approved after the share was set.
    attribute :shared_groups
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
    # Per-thread sequence number, assigned once at creation and never
    # reused. Messages and rolls share one counter per inkling (see
    # Inklings.next_event_seq), so combined with the inkling's own ID
    # this gives a stable reference like "2.1" that can be used to
    # point at this specific message later.
    attribute :seq
    # "true"/"false" - was the author staff at the time they wrote this
    attribute :is_staff
    # "true"/"false" - visible only to the author, staff, and any IDs
    # listed in private_recipient_ids.
    attribute :is_private
    # "true"/"false" - visible only to staff via can_manage_inklings?.
    attribute :is_gm_note
    # Comma-separated character IDs of non-staff players who can see
    # this private message. For player private entries this is empty
    # (only the author + staff). For staff private entries this defaults
    # to the inkling's subject character.
    attribute :private_recipient_ids

    reference :inkling, "AresMUSH::Inkling"
    reference :author, "AresMUSH::Character"
    # Set only when this message was pulled in from a JobReply on the
    # linked job (see Inklings.sync_job_replies). Lets the sync tell
    # which replies it's already mirrored, so it doesn't duplicate them.
    reference :source_job_reply, "AresMUSH::JobReply"

    index :inkling_id
    index :source_job_reply_id
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
