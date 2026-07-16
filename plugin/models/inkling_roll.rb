module AresMUSH
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

    # Free-text NPC name for "npc" rolls that aren't tied to an actual
    # Character record (e.g. a one-off NPC with no character sheet).
    # Used for display when target_character isn't set. Ignored for
    # "player" and "static" rolls.
    attribute :npc_name

    # The result of the roll as a string (e.g. "8" or "Mediocre (5)")
    # This is free-form to support any roll system
    attribute :result

    # The raw numeric result for sorting/comparison
    attribute :result_value

    # Per-thread sequence number, assigned once at creation and never
    # reused. Messages and rolls share one counter per inkling (see
    # Inklings.next_event_seq), so combined with the inkling's own ID
    # this gives a stable reference like "2.3" that can be used to
    # point at this specific roll later.
    attribute :seq

    # "true"/"false" - whether this roll is visible only to the player
    # and staff, or visible to all participants in the inkling thread
    attribute :private

    # Number of times this roll has been rerolled
    attribute :reroll_count

    # Cost in luck points if this was a luck reroll (0 = no luck used)
    attribute :luck_cost

    attribute :created_at
    attribute :rolled_at

    # Reverse reference
    index :inkling_id
    index :character_id
    index :target_character_id
    index :created_at
  end
end
