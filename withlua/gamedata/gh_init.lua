-- Lua initialization for GearHead.

-- The gh table contains all the loaded gears.
gh = {}


-- All standard functions should start with a "gh_" prefix.

function gh_register( gearid, gearscript )
	-- Given a gear pointer and its associated script, store everything
	-- in the gh table.
	P = {}
	a,b = pcall( gearscript )
	gh[gearid] = P
	if not a then
		error( b )
	end
end

function gh_deregister( gearid )
	-- Given a gear pointer, dispose of its entry in the gh table.
	gh[gearid] = nil
end

function gh_trigger( gearid, ghtrigger )
	-- Given a GearID and a trigger, see if there's a script to run, and if
	-- so go do that.
	local tmp = gh[gearid][ghtrigger]
	if tmp ~= nil then
		tmp( gearid )
--		gh[gearid]:[ghtrigger]()
	end
end






