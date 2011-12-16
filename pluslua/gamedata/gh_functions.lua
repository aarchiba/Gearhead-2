--
--   *******************************
--   ***   STANDARD  FUNCTIONS   ***
--   *******************************
--
-- This file contains some utility functions for GearHead scripting.
--

function gh_GetPC()
	-- We want the PC's table. Find the PC's pointer, then see if a table exists.
	-- If no PC can be found, return nil.
	local PCPtr = gh_GetPCPtr();
	if PCPtr ~= nil then
		PCPtr = gh[ PCPtr ]
	end
	return( PCPtr )
end

function gh_GetCurrentScene()
	-- As above, but we want the current scene.
	local ScenePtr = gh_GetCurrentScenePtr();
	if ScenePtr ~= nil then
		ScenePtr = gh[ ScenePtr ]
	end
	return( ScenePtr )
end

function gh_GetString( source )
	-- We've been handed something that supposedly contains a string. In
	-- actual fact it may be a string, a table, or something else.
	if type( source ) == "string" then
		-- Yay, it's just a plain string! Return it.
		return( source )

	elseif type( source ) == "table" then
		-- Crap, it's a table. There are a bunch of strings here, some
		-- of which may have conditions attached...

	else
		-- Not a string, and not a table... well, hope you win the
		-- lottery.
		return( tostring( source ) )
	end
end

function gh_FormatString( source , gear )
	-- Given a message source and a gear (optional), locate a string message
	-- and format it correctly.

	-- Step One: Find the message.
	local rawstring = gh_GetString( source )

	-- Step Two: Stepping through rawstring one word at a time, see if there
	-- are any substitutions to make.

	return( rawstring )
end

function gh_Print( source , gear )
	gh_RawPrint( gh_FormatString( source , gear ) )
end

function gh_Alert( source , gear )
	gh_RawAlert( gh_FormatString( source , gear ) )
end

function contextstring_to_contexttable( in_text )
	-- We may have to parse a context string. The format for the string is
	-- a series of "[label]:[description]" phrases, where label is a one char
	-- identifier and description is five characters long.
	-- For each such phrase found, set [label]_[description] in c_table to true.
	-- The context is converted to lowercase for this.
	local c_table = {}
	for w,p in string.gfind( in_text , "([%w]):([%w_][%w_][%w_][%w_][%w_])" ) do
		c_table[ string.lower( w ) .. '_' .. string.lower( p ) ] = true
	end
	return( c_table )
end

function gh_LowerRenown()
	-- The PC has just lost a fight or somesuch. Lower their renown.
	local PC = gh_GetPC();
	if PC ~= nil then
		local Renown = PC:GetNAtt( NAG_CHARDESCRIPTION , NAS_RENOWNED );
		if Renown > 23 then
			PC:AddNAtt( NAG_CHARDESCRIPTION , NAS_RENOWNED , -( Renown / 4 ) );
		else
			PC:AddNAtt( NAG_CHARDESCRIPTION , NAS_RENOWNED , -5 );
		end

	end
end



