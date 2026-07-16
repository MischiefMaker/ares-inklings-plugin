module AresMUSH
  # MERGE-IN SNIPPET - not a complete file, and not auto-loaded by
  # this plugin.
  #
  # plugins/profile/custom_char_fields.rb is a single shared hook file
  # per https://www.aresmush.com/tutorials/code/hooks/char-fields.html -
  # every plugin that wants a custom chargen/profile field adds its own
  # keys into the SAME get_fields_for_*/save_fields_from_* methods
  # there, alongside whatever other plugins already have. Merge the
  # bodies below into your game's actual custom_char_fields.rb rather
  # than overwriting that file with this one.
  #
  # This only covers the two chargen-required fields (secret and
  # goal), matching the tutorial's own single-field "goals" example.
  # It does NOT cover the full Inklings tab (browsing threads, rolls,
  # sharing, etc.) - that's handled entirely by the self-contained
  # inklings-tab component instead (see webportal/snippets/profile-*),
  # since it saves its own changes immediately and doesn't need to go
  # through this shared hash-based hook.
  module CustomCharFields
    # --- Profile Display --------------------------------------------
    def self.get_fields_for_viewing(char, viewer)
      secret = Inkling.find(character_id: char.id, kind: "secret").first
      goal = Inkling.find(character_id: char.id, kind: "goal").first

      {
        # ...other plugins' fields already here...
        inkling_secret_title: secret ? secret.title : nil,
        inkling_secret_text: secret ? Website.format_markdown_for_html(secret.messages.to_a.first&.text) : nil,
        inkling_goal_title: goal ? goal.title : nil,
        inkling_goal_text: goal ? Website.format_markdown_for_html(goal.messages.to_a.first&.text) : nil
      }
    end

    # --- Profile Editing ----------------------------------------------
    def self.get_fields_for_editing(char, viewer)
      # Same shape as get_fields_for_viewing, just without the HTML
      # formatting pass, since this feeds an editable form field
      # instead of read-only display markup.
      secret = Inkling.find(character_id: char.id, kind: "secret").first
      goal = Inkling.find(character_id: char.id, kind: "goal").first

      {
        inkling_secret_title: secret ? secret.title : nil,
        inkling_secret_text: secret ? secret.messages.to_a.first&.text : nil,
        inkling_goal_title: goal ? goal.title : nil,
        inkling_goal_text: goal ? goal.messages.to_a.first&.text : nil
      }
    end

    def self.save_fields_from_profile_edit2(char, viewer, args)
      save_inkling_field(char, viewer, "secret", args[:inkling_secret_title], args[:inkling_secret_text])
      save_inkling_field(char, viewer, "goal", args[:inkling_goal_title], args[:inkling_goal_text])
    end

    # --- Chargen -------------------------------------------------------
    def self.get_fields_for_chargen(char)
      get_fields_for_editing(char, char)
    end

    def self.save_fields_from_chargen(char, args)
      save_inkling_field(char, char, "secret", args[:inkling_secret_title], args[:inkling_secret_text])
      save_inkling_field(char, char, "goal", args[:inkling_goal_title], args[:inkling_goal_text])
    end

    # --- Shared helper ---------------------------------------------------
    # Creates the character's secret/goal inkling on first save, or
    # adds an update to the existing one on subsequent saves - either
    # way going through InklingApi rather than writing to the Inkling
    # model directly, so this still gets this plugin's normal
    # validation, job-linking, and title requirements.
    def self.save_inkling_field(char, viewer, kind, title, text)
      return if title.to_s.blank? && text.to_s.blank?

      existing = Inkling.find(character_id: char.id, kind: kind).first
      if existing
        AresMUSH::Inklings::InklingApi.reply_to_inkling(char.id, existing.id, viewer.id, text)
      else
        AresMUSH::Inklings::InklingApi.create_inkling(char.id, viewer.id, kind, text, title)
      end
    end
  end
end
