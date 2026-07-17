module AresMUSH
  # A single reward granted to a character in connection with an
  # inkling thread - see Inklings.grant_reward and +inkling/reward.
  #
  # Deliberately generic (reward_type/reward_key/amount rather than
  # separate fields per reward system) so future reward systems (e.g.
  # a SOUL/Boons/Banes plugin, if one is ever added) can record their
  # own reward_type values here without needing a schema change or a
  # redesign of this model. This plugin only actually *applies*
  # "xp" (via FS3Skills.modify_xp) and records "fs3_skill" for staff
  # to apply manually - see the note on Inklings.grant_reward.
  class InklingReward < Ohm::Model
    include ObjectModel

    reference :inkling, "AresMUSH::Inkling"
    # The character receiving the reward.
    reference :character, "AresMUSH::Character"
    # The staff member who granted it.
    reference :granted_by, "AresMUSH::Character"

    # e.g. "xp", "fs3_skill". Not an enum/constant list on purpose -
    # this is exactly the field future reward systems would add new
    # values to.
    attribute :reward_type
    # e.g. an FS3 skill name like "Medicine". Blank/nil for reward
    # types (like "xp") that don't need one.
    attribute :reward_key
    # Stored as a string like every other Ohm attribute; callers
    # parse it back to a number as needed (see Inklings.grant_reward).
    attribute :amount
    attribute :reason

    # "private" (default - only the recipient can see the history
    # entry) or "all" (visible to every participant in the thread).
    # See +inkling/reward's "/all" flag.
    attribute :visibility

    attribute :created_at

    index :inkling_id
    index :character_id
  end
end
