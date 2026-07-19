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
  # IMPORTANT - keep in sync with game/config/inklings.yml chargen_required_types:
  # There must be one <inkling_KIND_title> / <inkling_KIND_text> pair here for
  # every kind listed in chargen_required_types. The config-driven loops in
  # custom_char_fields.rb read/write these by name (char.send("inkling_#{kind}_title")),
  # so a kind with no matching attribute pair below will raise on profile/chargen load.
  # Default chargen_required_types is [goal, secret]; if you add a kind, add its
  # two attributes here too.
  class Character
    attribute :inkling_secret_title
    attribute :inkling_secret_text
    attribute :inkling_goal_title
    attribute :inkling_goal_text
  end
end
