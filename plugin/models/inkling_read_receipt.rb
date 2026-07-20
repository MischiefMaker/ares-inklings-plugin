module AresMUSH
  # Per-character read tracking for an inkling thread. Independent of
  # Inkling#player_unread (which only ever reflects the OWNING
  # character's state, set/cleared by a handful of specific staff
  # actions - see the attribute comment on Inkling#player_unread) -
  # this exists so "have I seen everything on this thread" is
  # meaningful for shared/group participants too, not just the owner.
  # Used by +inkling/new (InklingNewUnreadCmd) and the on-login unread
  # check (CharConnectedEventHandler). See Inklings.mark_read /
  # Inklings.has_unread_for? / Inklings.unread_inklings_for.
  class InklingReadReceipt < Ohm::Model
    include ObjectModel

    reference :inkling, "AresMUSH::Inkling"
    reference :character, "AresMUSH::Character"
    # Highest event (message or roll) seq this character has seen on
    # this inkling. No receipt for a character/inkling pair means 0 -
    # i.e. nothing seen yet.
    attribute :last_read_seq

    index :inkling_id
    index :character_id
  end
end
