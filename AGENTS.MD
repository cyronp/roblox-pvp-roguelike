# AGENTS.md

## Project Overview

This repository contains a game built for **Roblox** using **Luau**.

When working in this repository, prioritize:

- Correct Roblox/Luau APIs and conventions.
- Clear separation between client and server code.
- Secure server-authoritative gameplay.
- Maintainable, modular code.
- Good performance on both desktop and mobile Roblox clients.
- Changes that preserve existing gameplay behavior unless a change is explicitly requested.

---

## Tech Stack

- **Platform:** Roblox
- **Language:** Luau
- **Runtime:** Roblox Engine
- **Architecture:** Client / Server
- **Primary APIs:** Roblox Services and Instances

Depending on the repository, development tooling may also include:

- Roblox Studio
- Rojo
- Wally
- Selene
- StyLua
- TestEZ

Do not assume any of these tools are installed unless they exist in the repository configuration.

---

## Repository Structure

Follow the existing project structure before introducing new folders or architectural patterns.

Common Roblox directories may include:

```text
src/
├── client/
│   └── Client-side scripts and controllers
├── server/
│   └── Server-side scripts and services
└── shared/
    └── Modules shared between client and server
```

Typical Roblox mapping:

- `ServerScriptService` → server-only logic
- `ServerStorage` → server-only assets/modules
- `ReplicatedStorage` → shared modules, remotes, and replicated assets
- `StarterPlayerScripts` → client controllers
- `StarterGui` → UI
- `Workspace` → active game-world objects

If the project uses a different structure, preserve it.

---

## Luau Style

Write idiomatic **Luau**, not generic Lua.

Prefer:

```lua
local Players = game:GetService("Players")

local function getPlayerName(player: Player): string
	return player.Name
end
```

Use:

- `local` variables by default.
- Type annotations where they improve correctness and readability.
- `game:GetService()` for Roblox services.
- Early returns to reduce nesting.
- Descriptive names.
- Small, focused functions.
- ModuleScripts for reusable behavior.

Avoid unnecessary global state.

Prefer:

```lua
local MAX_HEALTH = 100
```

over:

```lua
MAX_HEALTH = 100
```

---

## Type Safety

Use Luau types for important interfaces and data structures.

Example:

```lua
export type PlayerData = {
	Coins: number,
	Level: number,
	Experience: number,
}

local function addCoins(data: PlayerData, amount: number)
	data.Coins += amount
end
```

Avoid excessive typing that makes simple code difficult to read.

Do not use `any` unless integration with dynamic data makes it necessary.

---

## Client / Server Rules

Roblox clients must never be trusted with authoritative gameplay decisions.

### Server responsibilities

The server should control:

- Currency
- Inventory
- Damage
- Rewards
- Purchases
- Player progression
- Saved data
- Match results
- Important cooldowns
- Permission checks

### Client responsibilities

The client should primarily control:

- User input
- Camera behavior
- Local visual effects
- UI
- Animations
- Non-authoritative prediction
- Presentation

Never allow the client to directly decide sensitive values such as:

```text
Coins awarded
Damage dealt
Items purchased
Experience gained
Match rewards
```

---

## RemoteEvents and RemoteFunctions

Treat all client input as untrusted.

Bad:

```lua
RemoteEvent.OnServerEvent:Connect(function(player, coins)
	player.leaderstats.Coins.Value += coins
end)
```

Better:

```lua
RemoteEvent.OnServerEvent:Connect(function(player, rewardId)
	local reward = getReward(rewardId)

	if not reward then
		return
	end

	if not canPlayerClaimReward(player, rewardId) then
		return
	end

	grantReward(player, reward)
end)
```

For every remote:

1. Validate argument types.
2. Validate ranges and values.
3. Verify the player is allowed to perform the action.
4. Apply important cooldowns/rate limits.
5. Perform authoritative calculations on the server.

Do not expose unnecessary RemoteEvents or RemoteFunctions.

---

## Security

Assume exploiters can:

- Fire RemoteEvents manually.
- Invoke RemoteFunctions manually.
- Send unexpected arguments.
- Send arguments extremely quickly.
- Modify LocalScripts.
- Modify local state.
- Spoof client-side cooldowns.
- Inspect replicated objects.

Therefore, security checks must happen on the server.

Do not rely on client-side anti-cheat as the sole protection for important systems.

---

## Data Persistence

When modifying player-data systems:

- Keep saves server-side.
- Validate loaded data.
- Handle missing fields gracefully.
- Consider older save formats when adding new fields.
- Avoid saving on every tiny state change.
- Handle shutdowns and player disconnects safely.
- Avoid accidental data overwrites.

When adding a new field, provide a sensible default.

Example:

```lua
local DEFAULT_DATA = {
	Coins = 0,
	Level = 1,
	Experience = 0,
}
```

Be especially careful when modifying existing production data schemas.

---

## Performance

Roblox games must run on a wide range of devices.

Avoid:

- Expensive work every frame without a good reason.
- Large loops inside `RunService.Heartbeat` or `RenderStepped`.
- Creating and destroying Instances continuously when reuse is practical.
- Excessive remote traffic.
- Repeated calls that could be cached.
- Large numbers of unnecessary connections.
- Memory leaks from forgotten event connections.

Use frame-based events only when the behavior genuinely needs frame-level updates.

Prefer events over polling where practical.

---

## Event Connections

Clean up event connections when their owning object or system is destroyed.

For systems with temporary lifetimes, track:

```lua
RBXScriptConnection
```

objects and disconnect them appropriately.

Avoid creating duplicate listeners when initialization functions run more than once.

---

## UI

When editing Roblox UI:

- Support different screen sizes.
- Consider mobile users.
- Prefer scale-based layouts where appropriate.
- Avoid hardcoding UI around one resolution.
- Keep important controls reachable on touch devices.
- Preserve existing UI conventions.

Use layout objects such as:

- `UIListLayout`
- `UIGridLayout`
- `UIPadding`
- `UIAspectRatioConstraint`

when appropriate.

---

## Modules

Prefer focused modules with clear responsibilities.

Example:

```lua
local InventoryService = {}

function InventoryService:AddItem(player: Player, itemId: string)
	-- implementation
end

return InventoryService
```

Avoid giant modules that manage unrelated systems.

Keep dependencies clear and avoid circular module dependencies.

---

## Naming

Follow existing repository naming conventions.

When no convention exists:

- Services/modules: `PascalCase`
- Types: `PascalCase`
- Functions: `camelCase`
- Variables: `camelCase`
- Constants: `UPPER_SNAKE_CASE`

Example:

```lua
local MAX_INVENTORY_SIZE = 50

local function calculateDamage(baseDamage: number, multiplier: number): number
	return baseDamage * multiplier
end
```

---

## Error Handling

Failures caused by normal gameplay should generally be handled without crashing an entire system.

Use `pcall` when interacting with Roblox APIs that can fail, especially network-backed operations when appropriate.

Do not silently swallow important errors.

Prefer useful warnings:

```lua
warn(`Failed to load player data for {player.UserId}`)
```

Avoid excessive logging in frequently executed code.

---

## Comments

Comments should explain **why**, not repeat what the code already says.

Good:

```lua
-- Apply the cooldown server-side because client cooldowns can be bypassed.
```

Less useful:

```lua
-- Set cooldown to 5
local cooldown = 5
```

Document non-obvious gameplay rules and architectural decisions.

---

## Making Changes

Before modifying a system:

1. Inspect related modules and scripts.
2. Understand whether the code runs on the client or server.
3. Identify existing abstractions before creating new ones.
4. Check call sites before changing public module APIs.
5. Preserve backward compatibility when practical.

Avoid unrelated refactors while fixing a focused issue.

If a larger refactor is necessary, keep behavior changes separate from structural changes where possible.

---

## Adding Features

When implementing a feature:

1. Determine which behavior is authoritative.
2. Put authoritative logic on the server.
3. Define shared types/configuration where useful.
4. Add the minimum required remote communication.
5. Validate every client-to-server request.
6. Implement client presentation separately.
7. Consider cleanup and player disconnects.
8. Consider mobile compatibility.
9. Consider performance under multiple simultaneous players.

---

## Bug Fixes

Prefer fixing the underlying cause rather than hiding the symptom.

Before changing code:

- Trace where the relevant value originates.
- Check client/server boundaries.
- Check event listeners.
- Check initialization order.
- Check character respawn behavior.
- Check whether an object can be destroyed during asynchronous work.

Roblox lifecycle behavior should always be considered, especially:

```text
Player joins
Player leaves
Character spawns
Character dies
Character respawns
Round starts
Round ends
Server shuts down
```

---

## Testing

When possible, test changes under multiple Roblox Studio modes:

- Play
- Play Here
- Start Server
- Multiple Players

Multiplayer behavior should not be validated using only a single local player when the feature involves networking.

Important systems should be tested for:

- Joining
- Leaving
- Respawning
- Reconnecting
- Multiple players acting simultaneously
- Invalid remote arguments
- Rapid repeated requests

---

## Agent Guidelines

When an AI coding agent modifies this repository:

- Read relevant existing files before writing code.
- Match existing architecture and naming.
- Do not invent Roblox APIs.
- Do not replace working systems unnecessarily.
- Keep changes scoped to the task.
- Do not move authoritative logic to the client.
- Validate remote requests.
- Avoid new dependencies unless they provide clear value.
- Update affected types when changing data structures.
- Preserve public APIs unless the task requires changing them.
- Mention meaningful assumptions when repository context is incomplete.

If unsure about an architectural choice, prefer consistency with the existing codebase over introducing a new pattern.

---

## Definition of Done

A change is complete when:

- The requested behavior works.
- Luau code is syntactically valid.
- Client/server responsibilities are correct.
- Remote inputs are validated.
- Existing behavior has not been unintentionally broken.
- Temporary resources and connections are cleaned up.
- Code follows the surrounding project's conventions.
- Relevant multiplayer and lifecycle edge cases have been considered.
