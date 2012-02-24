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

function gh_PCisHungry()
	-- Return true if the PC is found and is hungry.
	local pc = gh_GetPC();
	if pc ~= nil then
		return( pc:GetNAtt( NAG_CONDITION , NAS_HUNGER ) > 10 );
	else
		return( false );
	end;
end

function gh_FeedPC()
	-- Set the PC's hunger count to 0, and delay by three minutes.
	local pc = gh_GetPC();
	if pc ~= nil then
		pc:SetNAtt( NAG_CONDITION , NAS_HUNGER , 0 );
		gh_SpendTime( 3600 );
	end;
end;

function gh_CanPayBill( cash_amount )
	-- Check the PC's money. If there's enough to pay the tab, deduct that
	-- amount and return true. Otherwise just return false.
	local pc = gh_GetPC();
	if pc ~= nil then
		if pc:GetNAtt( NAG_EXPERIENCE , NAS_CREDITS ) >= cash_amount then
			pc:AddNAtt( NAG_EXPERIENCE , NAS_CREDITS , -cash_amount );
			return( true );
		else
			return( false );
		end;
	else
		return( false );
	end;
end

function gh_GetCurrentScene()
	-- As above, but we want the current scene.
	local ScenePtr = gh_GetCurrentScenePtr();
	if ScenePtr ~= nil then
		ScenePtr = gh[ ScenePtr ]
	end
	return( ScenePtr )
end

function gh_CreatePart( full_name )
	-- Create a new part, then return its table.
	local NewPart = gh_RawCreatePart( full_name );
	if NewPart ~= nil then
		NewPart = gh[ NewPart ]
	else
		error( "ERROR: CreatePart couldn't create "..full_name );
	end
	return( NewPart )
end

function gh_CreateAndGivePart( full_name )
	-- Create a new part and then immediately give it to the PC.
	local NewPart = gh_CreatePart( full_name );
	if NewPart ~= nil then
		gh_GiveGear( NewPart );
	end;
	return( NewPart );
end;




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
function gh_FollowLink( gear , link_type )
	local NewPart = gh_RawFollowLink( gear , link_type );
	if NewPart ~= nil then
		NewPart = gh[ NewPart ]
	end
	return( NewPart )
end


function gh_LoseRenown()
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

function gh_ChooseAOverB( prompt, option_a, option_b )
	-- Create a menu with option_a and option_b. Return true if the player
	-- selects option_a, or false otherwise.
	gh_InitMenu();
	gh_AddMenuItem( option_a , 1 );
	gh_AddMenuItem( option_b , -1 );
	return( gh_QueryMenu( prompt ) == 1 );
end

function gh_GiveCash( cash_amount )
	-- Give some money to the PC.
	local pc = gh_GetPC();
	if pc ~= nil then
		pc:AddNAtt( NAG_EXPERIENCE , NAS_CREDITS , cash_amount );
		gh_Print( "You receive $"..cash_amount.."." );
	end;
end


function gh_FindGearsPred(predicate)
    -- Find all registered gears for which predicate returns true
    r = {}
    for k,v in pairs(gh) do
        if v~=nil and predicate(v) then
            table.insert(r, v)
        end
    end
    return r
end

function gh_FindGears(attrs)
    -- Find all registered gears matching attrs
    -- attrs should be a table listing key-value pairs the gear should have,
    -- for example:
    -- gh_FindGears{NAME="Crystal Skull"}
    -- the return value is a table whose values are all matching gears
    print(attrs);
    function p(gear)
        S = gh_GetSAtts(gear)
        if S == nil then
            return false
        end
        for k,v in pairs(attrs) do
            if S[k] ~= v then
                return false
            end
        end
        return true
    end
    return gh_FindGearsPred(p)
end

