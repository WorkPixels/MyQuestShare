# MyQuestLog

**MyQuestLog** is a lightweight, modern World of Warcraft addon that enhances the default Quest Log and World Map window in WoW Forever with window unlocking, smart zone & dungeon quest sharing, per-zone share buttons, and Questie synchronization.

---

## Features

- **Movable Quest & Map Window**: Unlocks `WorldMapFrame` (and `QuestLogFrame`) so you can freely reposition the quest log anywhere on your screen. Window position is clamped to screen and saved across sessions.
- **Per-Zone Header `Share` Buttons**: Adds a compact **`Share`** button directly onto every zone header bar in the quest log so you can inspect and push quests for any zone with a single click.
- **Dedicated Quest Log Action Bar**: A clean 2-row Blizzard-styled toolbar embedded at the bottom of the quest pane (`QuestMapFrame`) with zero overlap on the quest scroll frame or scrollbar.
  - **`Share Zone (X)` / `Share Dungeon (X)`**: Dynamically detects whether you are in a dungeon or outdoor zone, counts eligible matching quests, and pushes them to your party/raid.
  - **`Share All`**: Shares all eligible quests in your quest log with party members.
  - **`Req Questie`**: Opens a confirmation dialog to ask group members running Questie or MyQuestLog to share their quests for the current zone or dungeon (manual trigger only—no background request spam).
  - **`Auto-share when zoning`**: Checkbox to automatically share matching dungeon or zone quests when entering a new area with a group.
  - **`Reset Pos`**: Instantly re-centers the unlocked World Map window to the middle of the screen.
- **Accurate Dungeon Mapping**: Strict dungeon-to-quest header mapping database so dungeon zoning never shares irrelevant open-world quests.
- **Taint & Secret Value Protection**: Safe wrappers around protected 11.0+ / Forever APIs preventing secret value crashes and `ADDON_ACTION_BLOCKED` errors during combat and group checks.
- **Questie & AddOn Protocol**: Integrates with Questie's sync protocol (`QC_ID_REQUEST_FULL_QUESTLIST`) and `MYQUESTLOG` / legacy `MQS` inter-addon messages.

---

## Slash Commands

Primary command: `/mql` (aliases: `/myquestlog`, `/mqs`, `/myquestshare`).

| Command | Description |
| :--- | :--- |
| `/mql share` | Share current dungeon or zone quests with group |
| `/mql all` | Share all eligible quests in your log |
| `/mql auto` | Toggle automatic sharing on zone/dungeon change |
| `/mql resetmap` | Reset Quest / Map window position to center of screen |
| `/mql levels` | Toggle quest levels & difficulty tags |
| `/mql questie` | Request quest shares from Questie users in group |
| `/mql req` | Request quest shares from MyQuestLog users |
| `/mql status` | Print current zone matching count & group status |

---

## Installation

1. Copy the `MyQuestLog` folder into your World of Warcraft `Interface\AddOns` directory:
   - `World of Warcraft\_forever_\Interface\AddOns\MyQuestLog`
2. Restart World of Warcraft and ensure **MyQuestLog** is enabled in your AddOns list.
3. Open your quest log (`L` or `M`) to access the unlocked window and sharing controls.

---

## License

MIT
