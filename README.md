# MyQuestShare

**MyQuestShare** is a lightweight, modern World of Warcraft addon that seamlessly enhances the default Quest Log and World Map window with window unlocking, smart zone & dungeon quest sharing, and party synchronization with Questie.

---

## Features

- **Movable Quest & Map Window**: Unlocks `WorldMapFrame` (and `QuestLogFrame`) so you can freely reposition the quest log anywhere on your screen. Window position is clamped to screen and saved across sessions.
- **Dedicated Quest Log Action Bar**: A clean 2-row Blizzard-styled toolbar embedded at the bottom of the quest pane (`QuestMapFrame`) with zero overlap on the quest scroll frame or scrollbar.
  - **`Share Zone (X)` / `Share Dungeon (X)`**: Dynamically detects whether you are in a dungeon or outdoor zone, counts eligible matching quests, and pushes them to your party/raid.
  - **`Share All`**: Shares all eligible quests in your quest log with party members.
  - **`Request Quests`**: Broadcasts a sync request asking group members running Questie or MyQuestShare to share their quests for the current area.
  - **`Auto-Share`**: Checkbox to automatically share matching dungeon or zone quests when entering a new area with a group.
- **Accurate Dungeon Mapping**: Strict dungeon-to-quest header mapping database so dungeon zoning never shares irrelevant open-world quests.
- **Taint & Secret Value Protection**: Safe wrappers around protected 11.0+ / Forever APIs preventing secret value crashes during combat and group checks.
- **Questie & AddOn Protocol**: Compatible with Questie's packet handshake protocol (`QC:request_log`, `QC:request_quest`) and MyQuestShare inter-addon protocol.

---

## Slash Commands

| Command | Description |
| :--- | :--- |
| `/mqs share` | Share current dungeon or zone quests with group |
| `/mqs all` | Share all eligible quests in your log |
| `/mqs auto` | Toggle automatic sharing on zone/dungeon change |
| `/mqs resetmap` | Reset Quest / Map window position to center of screen |
| `/mqs questie` | Request quest shares from Questie users in group |
| `/mqs req` | Request quest shares from MyQuestShare users |
| `/mqs status` | Print current zone matching count & group status |

---

## Installation

1. Copy the `MyQuestShare` folder into your World of Warcraft `Interface\AddOns` directory:
   - `World of Warcraft\_forever_\Interface\AddOns\MyQuestShare` (or `_classic_` / `_anniversary_`)
2. Restart World of Warcraft or reload your UI with `/reload`.
3. Open your quest log (`L` or `M`) to access the unlocked window and sharing buttons.

---

## License

MIT
