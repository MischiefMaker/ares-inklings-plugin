module AresMUSH
  # Database models live in the base AresMUSH module (not the plugin's
  # own module), even though the files live under the plugin folder.

  # A single inkling thread. Covers all kinds - staff-to-player,
  # player-to-staff, and secrets in either direction - since they all
  # share the same shape: a subject character, a status, an optional
  # linked job, and a series of messages.
  class Inkling < Ohm::Model
    include ObjectModel

    # kind is a configurable type - see the "types" section of
    # game/config/inklings.yml for the authoritative list of valid
    # kinds, their categories, names, and descriptions
    # (Inklings.type_config reads it). Rolls are not a kind — they can
    # be attached to any inkling.
    attribute :kind
    attribute :title
    # "open" or "closed" - the inkling's own lifecycle, independent of
    # approval_state below. A thread can go through many rounds of
    # submit/approve (see approval_state) while staying open the whole
    # time - approving one round doesn't mean the initiative is finished,
    # just that staff signed off on where it's at right now. Set to
    # "closed" (see close_inkling) only when there's nothing further to
    # do on it at all.
    attribute :status
    # Comma-separated group specs (e.g. "Navy" or "Faction:Navy,Marines").
    # Any character whose group membership matches a spec has access, even
    # if they were approved after the share was set.
    attribute :shared_groups
    # Comma-separated tags for organization (e.g. "family,plot-hook").
    # Tags are optional and used for categorizing inklings.
    attribute :tags
    attribute :created_at
    attribute :updated_at
    # "true"/"false" - whether the player has unread staff messages
    # on this thread.
    attribute :player_unread
    # "true"/"false" - whether the thread is locked pending a staff
    # response. Set by +inkling/submit (see Inklings.submit_inkling);
    # cleared by both +inkling/approve and +inkling/needschanges (see
    # Inklings.approve_inkling / request_changes). Ordinary staff replies
    # (+inkling/advance, +inkling/private, or a reply pulled in from
    # the linked job) do NOT change this - only the explicit review
    # actions do, since a reply is not the same thing as a decision.
    # While locked, non-staff cannot add replies, private replies, or
    # rolls - see check_not_locked in the relevant commands.
    attribute :locked
    # The status of the MOST RECENT round of staff review, not the
    # inkling as a whole (see status above for that): "draft" (default -
    # player is still working on it, nothing sent to staff yet),
    # "submitted" (+inkling/submit was run - locked, awaiting a staff
    # decision), "needs_changes" (staff sent it back via
    # +inkling/needschanges - unlocked, player can revise and resubmit),
    # or "approved" (staff approved THIS round via +inkling/approve -
    # unlocked, back to ordinary player mode). "Approved" is deliberately
    # not a final state: many inklings are an ongoing back-and-forth
    # between player and staff, each beat submitted and approved in turn,
    # with more still to come. +inkling/submit works again immediately
    # after an approval if the player has more to bring to staff -
    # +inkling/close is the actual "nothing more to do here" signal. See
    # Inklings.submit_inkling / approve_inkling / request_changes.
    attribute :approval_state

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
    # "true"/"false" - visible only to the author. Personal entries are
    # intended for the author's private notes and are hidden from
    # everyone including staff during normal viewing.
    attribute :is_personal
    # Comma-separated character IDs of non-staff players who can see
    # this private message. For player private entries this is empty
    # (only the author + staff). For staff private entries this defaults
    # to the inkling's subject character.
    attribute :private_recipient_ids
    # Optional: marks special system messages for labeling purposes.
    # Values: "submitted", "approved", "needs_changes", "reward"
    # Regular player/staff replies have no message_type set.
    attribute :message_type

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

  # NOTE: There is intentionally no `collection :inklings` reverse
  # reference on Character here. That reverse-collection macro was the
  # source of a bug where it could return the wrong character's
  # threads. Everywhere in this plugin that needs a character's
  # inklings queries explicitly instead:
  #   Inkling.find(character_id: char.id).to_a
end
