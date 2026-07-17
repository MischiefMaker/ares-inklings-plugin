module AresMUSH
  # CUSTOM CHARACTER FIELDS SNIPPET - BACKEND HOOK
  #
  # FILE: plugins/profile/custom_char_fields.rb
  # NOTE: This is a SHARED HOOK FILE. Every plugin adds its own methods into the SAME
  #       module. You will MERGE these method bodies, not replace the entire file.
  #
  # INSTRUCTIONS:
  # 1. Open your game's plugins/profile/custom_char_fields.rb
  # 2. Find the CustomCharFields module
  # 3. Copy each method below (get_fields_for_viewing, get_fields_for_editing, etc.)
  # 4. Find the matching method in your custom_char_fields.rb (it may have other plugins' fields already)
  # 5. Add these Inklings fields to the hash, after any other plugins' fields
  # 6. Save the file
  #
  # WHAT THIS DOES:
  # - Saves the Secret and Goal inklings that players create during chargen
  # - Displays them on the character profile page
  # - Allows editing them from the character profile
  #
  # IMPORTANT: These methods create/update Inkling records through InklingApi, which
  #            goes through normal validation and title requirements (not direct database writes).

  module CustomCharFields
    # --- Profile Display (what viewers see) ---
    def self.get_fields_for_viewing(char, viewer)
      secret = Inkling.find(character_id: char.id, kind: "secret").first
      goal = Inkling.find(character_id: char.id, kind: "goal").first

      {
        # Add these lines to your existing hash (other plugins' fields go here too):
        inkling_secret_title: secret ? secret.title : nil,
        inkling_secret_text: secret ? Website.format_markdown_for_html(secret.messages.to_a.first&.text) : nil,
        inkling_goal_title: goal ? goal.title : nil,
        inkling_goal_text: goal ? Website.format_markdown_for_html(goal.messages.to_a.first&.text) : nil
      }
    end

    # --- Profile Editing (editable form) ---
    def self.get_fields_for_editing(char, viewer)
      # Same as get_fields_for_viewing but WITHOUT HTML formatting (raw text for editing)
      secret = Inkling.find(character_id: char.id, kind: "secret").first
      goal = Inkling.find(character_id: char.id, kind: "goal").first

      {
        # Add these lines to your existing hash:
        inkling_secret_title: secret ? secret.title : nil,
        inkling_secret_text: secret ? secret.messages.to_a.first&.text : nil,
        inkling_goal_title: goal ? goal.title : nil,
        inkling_goal_text: goal ? goal.messages.to_a.first&.text : nil
      }
    end

    # When a profile edit is saved, update the Inklings
    def self.save_fields_from_profile_edit(char, viewer, args)
      # Add these two lines to your method:
      save_inkling_field(char, viewer, "secret", args[:inkling_secret_title], args[:inkling_secret_text])
      save_inkling_field(char, viewer, "goal", args[:inkling_goal_title], args[:inkling_goal_text])
    end

    # --- Chargen Setup ---
    def self.get_fields_for_chargen(char)
      # Just reuse the editing version (no HTML formatting for form fields)
      get_fields_for_editing(char, char)
    end

    # When chargen is completed, save the Secret and Goal Inklings
    def self.save_fields_from_chargen(char, args)
      # Add these two lines to your method:
      save_inkling_field(char, char, "secret", args[:inkling_secret_title], args[:inkling_secret_text])
      save_inkling_field(char, char, "goal", args[:inkling_goal_title], args[:inkling_goal_text])
    end

    # --- Helper Method (add to the bottom of the module) ---
    # Creates a new Inkling or adds a message to an existing one
    # Always goes through InklingApi (validates, checks titles, etc.)
    def self.save_inkling_field(char, viewer, kind, title, text)
      return if title.to_s.blank? && text.to_s.blank?

      existing = Inkling.find(character_id: char.id, kind: kind).first
      if existing
        # Inkling already exists, add a new message to it
        AresMUSH::Inklings::InklingApi.reply_to_inkling(char.id, existing.id, viewer.id, text)
      else
        # Create new Inkling (title is required)
        AresMUSH::Inklings::InklingApi.create_inkling(char.id, viewer.id, kind, text, title)
      end
    end
  end
end
