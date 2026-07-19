---
title: Manage Chargen
---

# Manage Chargen

The Inklings plugin integrates with AresMUSH's character generation process to collect Secret and Goal information as players create new characters.

## Installation

Chargen integration requires manual setup in your game's webportal. There are no staff commands — the configuration happens during installation and then runs automatically.

### Required Types

By default, Inklings expects two chargen field types: `secret` and `goal`. If your game uses different types, update the config:

```yaml
# game/config/inklings.yml
chargen_required_types:
  - secret
  - goal
```

### Web Portal Setup

If adding the web integration:

1. Copy the chargen-custom tab snippet into your game's `ares-webportal/app/components/chargen-custom-tabs.hbs`
2. Copy the chargen-custom form snippet into your game's `ares-webportal/app/components/chargen-custom.hbs`
3. Copy the chargen-custom JS snippet into your game's `ares-webportal/app/components/chargen-custom.js`
4. Restart the webportal: `website/deploy`

See the plugin's README for exact copy-paste instructions.

## How It Works

When a player creates a new character and fills out the Secret and Goal fields during chargen:

1. The fields are collected by the chargen framework
2. The plugin's `chargen_finalize` hook validates they exist
3. The plugin's `save_fields_from_chargen` hook creates draft Inkling threads
4. A staff member approves the character
5. The draft Inklings automatically convert to real threads
6. Players can then add to them and manage them normally

Players see a new "Inklings" tab in chargen showing form fields for:
- **Secret** - A title and description of something the character is hiding
- **Goal** - A title and description of something the character is working toward

## Tips

- Secrets and goals are optional by default — if a player leaves them blank, no inkling is created for that type
- Set `chargen_required_types` to make specific types mandatory
- Staff can view completed character's Secret and Goal inklings on the profile tab
- Chargen-created inklings are locked until staff approves the character
