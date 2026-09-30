-- Presentation waits for the authoritative inventory change before celebrating a pick.
export type Snapshot = {
	levels: { [string]: number },
	pending: number,
	choices: { string },
	offerId: number,
}

export type State = {
	latest: Snapshot,
	displayed: Snapshot,
	requested: string?,
	selected: string?,
}

local Offer = { SELECTION_DURATION = 0.8 }

function Offer.empty(): Snapshot
	return { levels = {}, pending = 0, choices = {}, offerId = 0 }
end

function Offer.new(snapshot: Snapshot): State
	return { latest = snapshot, displayed = snapshot, requested = nil, selected = nil }
end

function Offer.receive(state: State, snapshot: Snapshot): State
	if snapshot.offerId == 0 then
		return Offer.new(snapshot)
	end
	if state.selected then
		-- Further level-ups can arrive while the accepted card is animating out.
		return { latest = snapshot, displayed = state.displayed, selected = state.selected, requested = nil }
	end
	local requested = state.requested
	-- The final choice retains its token when there is no next offer.
	if requested and (snapshot.offerId ~= state.displayed.offerId or #snapshot.choices == 0)
		and (snapshot.levels[requested] or 0) > (state.displayed.levels[requested] or 0) then
		return { latest = snapshot, displayed = state.displayed, selected = requested, requested = nil }
	end
	if snapshot.offerId ~= state.displayed.offerId then
		return Offer.new(snapshot)
	end
	return { latest = snapshot, displayed = snapshot, requested = requested, selected = nil }
end

function Offer.request(state: State, index: number): State
	if state.requested or state.selected or not state.displayed.choices[index] then
		return state
	end
	return {
		latest = state.latest,
		displayed = state.displayed,
		requested = state.displayed.choices[index],
		selected = nil,
	}
end

function Offer.finish(state: State): State
	return Offer.new(state.latest)
end

return Offer
