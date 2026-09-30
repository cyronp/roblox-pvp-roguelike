local Offer = require("../src/client/UpgradeOfferState")

local first = { offerId = 12, pending = 1, choices = { "Damage", "Ammo", "Health" }, levels = {} }
local state = Offer.new(first)
assert(Offer.request(state, 4) == state, "Unavailable keys must not submit")
state = Offer.request(state, 2)
assert(state.requested == "Ammo" and state.selected == nil, "A key press must wait for the server")
assert(Offer.request(state, 1) == state, "Rapid keys must not submit multiple choices")

local queued = { offerId = 12, pending = 3, choices = first.choices, levels = {} }
state = Offer.receive(state, queued)
assert(state.requested == "Ammo" and state.selected == nil, "More XP is not selection confirmation")
assert(state.displayed.pending == 3)

local second = { offerId = 13, pending = 2, choices = { "Ammo", "Health", "Reload" }, levels = { Ammo = 1 } }
state = Offer.receive(state, second)
assert(state.selected == "Ammo" and state.requested == nil)
assert(state.displayed.offerId == 12, "Keep the old cards until their exit animation finishes")
assert(Offer.request(state, 1) == state, "Keys during an exit must not select the next offer")
local additionalXp = { offerId = 13, pending = 4, choices = second.choices, levels = second.levels }
state = Offer.receive(state, additionalXp)
assert(state.selected == "Ammo" and state.displayed.offerId == 12)
state = Offer.finish(state)
assert(state.displayed == additionalXp and state.selected == nil and state.requested == nil)

state = Offer.request(state, 1)
local last = { offerId = 13, pending = 0, choices = {}, levels = { Ammo = 2 } }
state = Offer.receive(state, last)
assert(state.selected == "Ammo", "The last offer must animate even when the token stays the same")
state = Offer.finish(state)
assert(#state.displayed.choices == 0)

state = Offer.request(Offer.new(first), 1)
state = Offer.finish(state)
assert(state.displayed == first and state.requested == nil, "Rejected/timed-out requests must allow retry")
assert(Offer.request(state, 3).requested == "Health")

state = Offer.receive(Offer.request(Offer.new(first), 2), second)
state = Offer.receive(state, Offer.empty())
assert(state.selected == nil and #state.displayed.choices == 0, "Death must cancel an active animation")
state = Offer.receive(Offer.request(Offer.new(first), 1), Offer.empty())
assert(state.requested == nil and state.displayed.offerId == 0, "Death must cancel an in-flight request")

-- A response arriving after the retry timeout must still show the actual server state.
state = Offer.finish(Offer.request(Offer.new(first), 2))
state = Offer.receive(state, second)
assert(state.displayed == second and state.requested == nil)
print("PASS: upgrade presentation acknowledgement, queued offers, rapid input, retries, late responses, and death")
