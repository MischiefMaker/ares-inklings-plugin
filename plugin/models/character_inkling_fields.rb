module AresMUSH
  # Reopens the core Character model to add the chargen-required inkling
  # draft fields. AresMUSH custom character fields must be declared with
  # `attribute` before char.<name> / char.update(<name>: ...) will work
  # (see https://aresmush.com/tutorials/code/hooks/char-fields.html and
  # https://aresmush.com/tutorials/code/add-cmd/db-field.html). Without
  # these declarations the profile/chargen hooks raise
  # "undefined method `inkling_secret_title'".
  #
  # These hold the DRAFT text a player enters during chargen (and can edit
  # on their profile). They are NOT the finished Inkling records - on
  # character approval, Inklings.character_approved converts any populated
  # draft into a real Inkling and clears the draft field.
  #
  # The chargen feature is intentionally fixed to two types, secret and goal
  # (see Inklings.chargen_required_types), so these four attributes are the
  # complete, static set - there is no config list to keep in sync. Turning
  # chargen off (chargen_enabled: false) simply leaves these fields unused;
  # they stay declared and harmless.
  class Character
    attribute :inkling_secret_title
    attribute :inkling_secret_text
    attribute :inkling_goal_title
    attribute :inkling_goal_text
  end
end
