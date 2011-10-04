-- Lua initialization for GearHead.


--  *****************************
--  ***   TYPE  DEFINITIONS   ***
--  *****************************

	proto_gear = {}
	proto_gear.stat = {}

	proto_stat = {}
	proto_stat.ptr = 0
	proto_stat.__index = function( table , key )
		return( gh_GetStat( table.ptr , key ) )
	end
	proto_stat.__newindex = function( table , key , v )
		gh_SetStat( table.ptr , key , v )
	end

	function proto_gear:new( o )
		o = o or {}
		setmetatable( o , self )
		self.__index = self

		-- The stat table provides easy access to the gear's stats.
		o.stat = {}
		o.stat.ptr = 0
		setmetatable( o.stat , proto_stat )

		-- The gear.v table holds script variables. These get included
		-- in the save file. Only numbers, strings, booleans, and tables
		-- of the above can be included here.
		o.v = {}

		return o
	end
	function proto_gear.USE( self )
		gh_Print( "Using something!" )
	end
	function proto_gear:GetG()
		return gh_GetGearG( self.ptr )
	end
	function proto_gear:GetS()
		return gh_GetGearS( self.ptr )
	end
	function proto_gear:GetV()
		return gh_GetGearV( self.ptr )
	end
	function proto_gear:GetNAtt( g , s )
		return gh_GetNAtt( self.ptr , g , s )
	end
	function proto_gear:SetNAtt( g , s , v )
		return gh_SetNAtt( self.ptr , g , s , v )
	end
	function proto_gear:GetX()
		return gh_GetNAtt( self.ptr , NAG_LOCATION , NAS_X )
	end
	function proto_gear:GetY()
		return gh_GetNAtt( self.ptr , NAG_LOCATION , NAS_Y )
	end


	-- PERSONA
	proto_persona = proto_gear:new()

	function proto_persona.UseNode( self , node , chatnpc )
		-- self is the persona being used
		-- node is the label of the current conversation node
		-- chatnpc is the NPC being spoken with

		-- Start by clearing the menu.
		gh_InitChatMenu( true )

		-- If an effect script exists, run that now.
		if node.effect ~= nil then
			node.effect( self , chatnpc )
		end

		-- Set the chat message.
		gh_SetChatMessage( mutate_message( gh_FormatString( node.msg , self ) , 250 , contextstring_to_contexttable( gh_GetContext( chatnpc , 's' ) ) ) )

		-- If there are any children, add them to the menu.
		if node.prompts ~= nil then
			local k,v
			for k,v in pairs( node.prompts ) do
				if ( v.condition == nil ) or v.condition( self , chatnpc ) then
					gh_AddChatMenuItem( k , gh_FormatString( v.msg ) )
				end
			end
		end
	end

	-- SCENES
	proto_scene = proto_gear:new()
	function proto_scene.NU1( self )
		-- If the number of player units drops to zero, leave the scene.
		if gh_CountActiveModels( NAV_DEFPLAYERTEAM ) < 1 then
			gh_Return();
		end
	end

	-- CHARACTERS
	proto_character = proto_gear:new()

	function proto_character.IsKnown( self )
		return( self:GetNAtt( NAG_PERSONAL , NAS_NUMCONVERSATION ) > 0 );
	end

	-- METATERRAIN: DOOR
	proto_door = proto_gear:new()
	function proto_door.USE( self )
		-- Gonna use this door. The exact effect is going to depend on
		-- whether this door is open or closed already. We can check this
		-- via the door's STAT_PASS stat.
		if self.stat[ STAT_PASS ] < -99 then
			-- The door is closed. Check to see if it's locked as well.
			if gh_GetStat( self.ptr , STAT_LOCK ) == 0 then
				gh_Print( "You open the door." )
				self.stat[ STAT_PASS ] = 0
--				gh_SetStat( self.ptr , STAT_PASS , 0 )
			else
				gh_Print( "The door is locked." )
			end
		else
			-- The door is currently open. Change that.
			gh_Print( "You close the door." )
			gh_SetStat( self.ptr , STAT_PASS , -100 )
		end
	end
	function proto_door.CLUE_CODEBREAKING( self )
		-- Gonna try to unlock this door. Good luck, buddy!
		-- First, check to make sure that the door is even locked...
		if gh_GetStat( self.ptr , STAT_LOCK ) ~= 0 then
			if gh_TrySkillTest( NAS_CODEBREAKING , STAT_CRAFT , gh_GetStat( self.ptr , STAT_LOCK ) ) then
				gh_Print( "You unlock the door." )
				gh_SetStat( self.ptr , STAT_LOCK , 0 )
			else
				gh_Print( "You do not manage to unlock the door." )
			end
		else
			gh_Print( "The door does not appear to be locked." )
		end
	end
	function proto_door.REVEAL( self )
		-- The door was hidden, but has just been revealed.
		-- Set the terrain in this tile to TERRAIN_THRESHOLD.
		gh_DrawTerrain( self.GetX() , self.GetY() , TERRAIN_THRESHOLD )
		gh_Print( "You find a secret door!" )
	end

	-- METATERRAIN: STAIRS UP
	proto_stairsup = proto_gear:new()
	function proto_stairsup.USE( self )
		-- Gonna use the stairs...
		if gh_GetStat( self.ptr , STAT_DESTINATION ) ~= 0 then
			gh_Print( "You go up the stairs." )
			gh_GotoScene( gh_GetStat( self.ptr , STAT_DESTINATION ) )
		end
	end

	-- METATERRAIN: STAIRS DOWN
	proto_stairsdown = proto_gear:new()
	function proto_stairsdown.USE( self )
		-- Gonna use the stairs...
		if gh_GetStat( self.ptr , STAT_DESTINATION ) ~= 0 then
			gh_Print( "You go down the stairs." )
			gh_GotoScene( gh_GetStat( self.ptr , STAT_DESTINATION ) )
		end
	end

	-- METATERRAIN: ELEVATOR
	proto_elevator = proto_gear:new()
	function proto_elevator.USE( self )
		-- Not gonna use the stairs...
		if gh_GetStat( self.ptr , STAT_DESTINATION ) ~= 0 then
			gh_Print( "You board the elevator." )
			gh_GotoScene( gh_GetStat( self.ptr , STAT_DESTINATION ) )
		end
	end

	-- METATERRAIN: TRAPDOOR
	proto_trapdoor = proto_gear:new()
	function proto_trapdoor.USE( self )
		-- Unlike the other entrances on this list, trapdoors can be locked.
		if gh_GetStat( self.ptr , STAT_DESTINATION ) ~= 0 then
			if gh_GetStat( self.ptr , STAT_LOCK ) == 0 then
				gh_Print( "You go down the trapdoor." )
				gh_GotoScene( gh_GetStat( self.ptr , STAT_DESTINATION ) )
			else
				gh_Print( "The trapdoor is locked." )
			end
		end
	end
	function proto_trapdoor.CLUE_CODEBREAKING( self )
		-- Gonna try to unlock this trapdoor. Good luck, buddy!
		-- First, check to make sure that the door is even locked...
		if gh_GetStat( self.ptr , STAT_LOCK ) ~= 0 then
			if gh_TrySkillTest( NAS_CODEBREAKING , STAT_CRAFT , gh_GetStat( self.ptr , STAT_LOCK ) ) then
				gh_Print( "You unlock the trapdoor." )
				gh_SetStat( self.ptr , STAT_LOCK , 0 )
			else
				gh_Print( "You do not manage to unlock the trapdoor." )
			end
		else
			gh_Print( "The trapdoor does not appear to be locked." )
		end
	end


	-- METATERRAIN: BUILDING
	proto_building = proto_gear:new()
	function proto_building.USE( self )
		-- Gonna enter this building, if it has a destination.
		if gh_GetStat( self.ptr , STAT_DESTINATION ) ~= 0 then
			gh_Print( "You enter the building." )
			gh_GotoScene( gh_GetStat( self.ptr , STAT_DESTINATION ) )
		end
	end


	-- The gh_prototypes table sorts the prototypes according to G,S descriptors
	gh_prototypes = {}
	gh_prototypes.default = proto_gear

	gh_prototypes[ GG_PERSONA ] = {}
	gh_prototypes[ GG_PERSONA ].default = proto_persona

	gh_prototypes[ GG_CHARACTER ] = {}
	gh_prototypes[ GG_CHARACTER ].default = proto_character

	gh_prototypes[ GG_METATERRAIN ] = {}
	gh_prototypes[ GG_METATERRAIN ][ GS_METADOOR ] = proto_door
	gh_prototypes[ GG_METATERRAIN ][ GS_METASTAIRSUP ] = proto_stairsup
	gh_prototypes[ GG_METATERRAIN ][ GS_METASTAIRSDOWN ] = proto_stairsdown
	gh_prototypes[ GG_METATERRAIN ][ GS_METAELEVATOR ] = proto_elevator
	gh_prototypes[ GG_METATERRAIN ][ GS_METATRAPDOOR ] = proto_trapdoor
	gh_prototypes[ GG_METATERRAIN ][ GS_METABUILDING ] = proto_building

	gh_prototypes[ GG_SCENE ] = {}
	gh_prototypes[ GG_SCENE ].default = proto_scene

	gh_prototypes[ GG_METASCENE ] = {}
	gh_prototypes[ GG_METASCENE ].default = proto_scene


--   **********************
--   ***   REGISTRIES   ***
--   **********************

	-- The gh table contains all the loaded gears.
	gh = {}
	gh.mt = {}
	setmetatable( gh , gh.mt )
	gh.mt.__index = function( table , key )
		-- If we are passed UserData, that should already have an entry here.
		-- But what if we're passed a number? Use the reverse lookup table to
		-- find the gear it corresponds to, and find its entry in the table.
		if ( type( key ) == "number" ) and ( nid_lookup[key] ~= nil ) then
			return( gh[ nid_lookup[key] ] )
		end
	end

	-- Reverse lookup table. Given a NarrativeID, find the UserData of the
	-- gear it belongs to.
	nid_lookup = {}


--   *******************************
--   ***   STANDARD  FUNCTIONS   ***
--   *******************************

--  Some useful things that can be done with Lua.

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


--   **********************************
--   ***   BITS  WHICH  DO  STUFF   ***
--   **********************************

-- I admit, that's an intentionally bad title for this section. These are the
-- functions which get called by the game engine, as opposed to the functions
-- above which are used inside of Lua.


function gh_register( gearptr, gearscript )
	-- Given a gear pointer and its associated script, store everything
	-- in the gh table.

	-- Determine the prototype for this gear.
	proto = gh_prototypes.default;
	if gh_prototypes[ gh_GetGearG( gearptr ) ] ~= nil then
		if gh_prototypes[ gh_GetGearG( gearptr ) ][ gh_GetGearS( gearptr ) ] ~= nil then
			proto = gh_prototypes[ gh_GetGearG( gearptr ) ][ gh_GetGearS( gearptr ) ]
		elseif gh_prototypes[ gh_GetGearG( gearptr ) ].default ~= nil then
			proto = gh_prototypes[ gh_GetGearG( gearptr ) ].default
		end
	end

	P = proto:new()
	P.ptr = gearptr
	P.stat.ptr = gearptr

	-- If this gear has a Narrative ID, store it in the reverse lookup table.
	local nid = gh_GetNAtt( gearptr , NAG_NARRATIVE , NAS_NID )
	if nid ~= 0 then
		nid_lookup[nid] = gearptr
	end

	a,b = pcall( gearscript )
	gh[gearptr] = P

	if not a then
		error( b )
	end
end

function gh_readvars( gearptr, gearscript )
	-- We've initialized a gear. Time to read its variables.
	-- These variables are stored as Lua code by the export function below.
	P = gh[gearptr]

	if P ~= nil then
		a,b = pcall( gearscript )

		if not a then
			error( b )
		end
	else
		error( 'ERROR: Attempt to read vars for nonexistent gear!' )
	end
end

function gh_deregister( gearptr )
	-- Given a gear pointer, dispose of its entry in the gh table.
	-- Also dispose of its reverse lookup, if appropriate.
	local nid = gh_GetNAtt( gearptr , NAG_NARRATIVE , NAS_NID )
	if nid ~= 0 then
		nid_lookup[nid] = nil
	end

	gh[gearptr] = nil
end

function gh_trigger( gearptr, ghtrigger )
	-- Given a gearptr and a trigger, see if there's a script to run, and if
	-- so go do that.
	local script_found = false
	if gh[gearptr] ~= nil then
		local tmp = gh[gearptr][ghtrigger]
		if tmp ~= nil then
			tmp( gh[gearptr] )
			script_found = true
		end

	end
	return script_found
end

function gh_conversation( gearptr, nodeid , npcptr )
	-- We've been asked to run a conversation node.
	-- 1. Locate the node record.
	-- 2. If it has a conditional script, make sure it evaluates to true.
	--  2a. If false, jump to the node's next sibling instead.
	-- 3. If we have a valid node speak its message, construct its menu,
	--    and execute its effect script if one exists.
	local self = gh[gearptr]
	local chatnpc = gh[npcptr]
	if self ~= nil then
		local pnode = nil

		repeat
			pnode = self[ nodeid ]
			if ( pnode ~= nil ) then
				-- We've found a node, but there's a nontrivial chance
				-- that it's the wrong node. Check to see if it has a
				-- conditional function, and if so see if it's true.
				if pnode.condition ~= nil then
					if not pnode.condition( self , chatnpc ) then
						-- Crap. This node is passing the buck...
						-- Set nodeid to the next sibling.
						nodeid = pnode.nextid
						pnode = nil
					end
				end
			else
				-- The requested node could not be found. This is
				-- a big problem... terminate the loop.
				break
			end

		until ( pnode ~= nil )

		-- Check to see if we have a valid node. If so, do whatever needs
		-- to be done.
		if pnode ~= nil then
			self.UseNode( self , pnode , chatnpc )
		else
			-- Serious problem: if the node can't be found, this means
			-- that the persona is broken. Print an error message.
			error( 'Cannot find persona node ' .. nodeid )
		end
	end
end

function gh_exportvars( gearptr )
	-- Given a gearptr, check its variable table and export all the values
	-- as a string. This string is saved with the savefile and will be run
	-- when the game is restored.
	function serialize ( slist, o )
		-- Convert o to a string and store it in slist, which should
		-- be a table. Code taken + modified from "Programming in Lua"
		-- by Roberto Ierusalimschy
		if type(o) == "number" then
			table.insert( slist , tostring( o ) )
		elseif type(o) == "string" then
			table.insert( slist , string.format("%q", o) )
		elseif type(o) == "boolean" then
			table.insert( slist , tostring( o ) )
		elseif type(o) == "table" then
			table.insert( slist , "{ " )
			for k,v in pairs(o) do
				table.insert( slist , " [" )
				serialize( slist , k )
				table.insert( slist , "] = " )
				serialize( slist , v )
				table.insert( slist , ", ")
			end
			table.insert( slist , "} " )
		else
			error("cannot serialize a " .. type(o) )
		end
	end

	if ( gh[ gearptr ] ~= nil ) and ( gh[ gearptr ].v ~= nil ) then
		thelist = {}
		table.insert( thelist , 'P.v =' )
		serialize( thelist , gh[ gearptr ].v )
		return( table.concat( thelist , ' ' ) )
	else
		return( "" )
	end
end






