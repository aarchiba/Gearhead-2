-- Lua initialization for GearHead.

--  *****************************
--  ***   SCRIPT  FUNCTIONS   ***
--  *****************************

	function xpos( gearptr )
		return gh_getnatt( gearptr , NAG_LOCATION , NAS_X )
	end

	function ypos( gearptr )
		return gh_getnatt( gearptr , NAG_LOCATION , NAS_Y )
	end

--  *****************************
--  ***   TYPE  DEFINITIONS   ***
--  *****************************

	proto_gear = {}
	proto_gear.stat = {}

	proto_stat = {}
	proto_stat.ptr = 0
	proto_stat.__index = function( table , key )
		return( gh_getstat( table.ptr , key ) )
	end

	function proto_gear:new( o )
		o = o or {}
		setmetatable( o , self )
		self.__index = self
		o.stat = {}
		setmetatable( o.stat , proto_stat )
		return o
	end
	function proto_gear.use( self )
		gh_print( "Using something!" )
	end
	function proto_gear:g()
		return gh_gearg( self.ptr )
	end


	-- SCENES
	proto_scene = proto_gear:new()
	function proto_scene.nu1( self )
		-- If the number of player units drops to zero, leave the scene.
		if gh_numunits( NAV_DEFPLAYERTEAM ) < 1 then
			gh_return();
		end
	end

	-- METATERRAIN: DOOR
	proto_door = proto_gear:new()
	function proto_door.use( self )
		-- Gonna use this door. The exact effect is going to depend on
		-- whether this door is open or closed already. We can check this
		-- via the door's STAT_PASS stat.
		if gh_getstat( self.ptr , STAT_PASS ) < -99 then
			-- The door is closed. Check to see if it's locked as well.
			if gh_getstat( self.ptr , STAT_LOCK ) == 0 then
				gh_print( "You open the door." )
				gh_setstat( self.ptr , STAT_PASS , 0 )
			else
				gh_print( "The door is locked." )
			end
		else
			-- The door is currently open. Change that.
			gh_print( "You close the door." )
			gh_setstat( self.ptr , STAT_PASS , -100 )
		end
	end
	function proto_door.clue_codebreaking( self )
		-- Gonna try to unlock this door. Good luck, buddy!
		-- First, check to make sure that the door is even locked...
		if gh_getstat( self.ptr , STAT_LOCK ) ~= 0 then
			if gh_uskilltest( NAS_CODEBREAKING , STAT_CRAFT , gh_getstat( self.ptr , STAT_LOCK ) ) then
				gh_print( "You unlock the door." )
				gh_setstat( self.ptr , STAT_LOCK , 0 )
			else
				gh_print( "You do not manage to unlock the door." )
			end
		else
			gh_print( "The door does not appear to be locked." )
		end
	end
	function proto_door.reveal( self )
		-- The door was hidden, but has just been revealed.
		-- Set the terrain in this tile to TERRAIN_THRESHOLD.
		gh_drawterr( xpos( self.ptr ) , ypos( self.ptr ) , TERRAIN_THRESHOLD )
		gh_print( "You find a secret door!" )
	end

	-- METATERRAIN: STAIRS UP
	proto_stairsup = proto_gear:new()
	function proto_stairsup.use( self )
		-- Gonna use the stairs...
		if gh_getstat( self.ptr , STAT_DESTINATION ) ~= 0 then
			gh_print( "You go up the stairs." )
			gh_exit( gh_getstat( self.ptr , STAT_DESTINATION ) )
		end
	end

	-- METATERRAIN: STAIRS DOWN
	proto_stairsdown = proto_gear:new()
	function proto_stairsdown.use( self )
		-- Gonna use the stairs...
		if gh_getstat( self.ptr , STAT_DESTINATION ) ~= 0 then
			gh_print( "You go down the stairs." )
			gh_exit( gh_getstat( self.ptr , STAT_DESTINATION ) )
		end
	end

	-- METATERRAIN: ELEVATOR
	proto_elevator = proto_gear:new()
	function proto_elevator.use( self )
		-- Not gonna use the stairs...
		if gh_getstat( self.ptr , STAT_DESTINATION ) ~= 0 then
			gh_print( "You board the elevator." )
			gh_exit( gh_getstat( self.ptr , STAT_DESTINATION ) )
		end
	end

	-- METATERRAIN: TRAPDOOR
	proto_trapdoor = proto_gear:new()
	function proto_trapdoor.use( self )
		-- Unlike the other entrances on this list, trapdoors can be locked.
		if gh_getstat( self.ptr , STAT_DESTINATION ) ~= 0 then
			if gh_getstat( self.ptr , STAT_LOCK ) == 0 then
				gh_print( "You go down the trapdoor." )
				gh_exit( gh_getstat( self.ptr , STAT_DESTINATION ) )
			else
				gh_print( "The trapdoor is locked." )
			end
		end
	end
	function proto_trapdoor.clue_codebreaking( self )
		-- Gonna try to unlock this trapdoor. Good luck, buddy!
		-- First, check to make sure that the door is even locked...
		if gh_getstat( self.ptr , STAT_LOCK ) ~= 0 then
			if gh_uskilltest( NAS_CODEBREAKING , STAT_CRAFT , gh_getstat( self.ptr , STAT_LOCK ) ) then
				gh_print( "You unlock the trapdoor." )
				gh_setstat( self.ptr , STAT_LOCK , 0 )
			else
				gh_print( "You do not manage to unlock the trapdoor." )
			end
		else
			gh_print( "The trapdoor does not appear to be locked." )
		end
	end


	-- METATERRAIN: BUILDING
	proto_building = proto_gear:new()
	function proto_building.use( self )
		-- Gonna enter this building, if it has a destination.
		if gh_getstat( self.ptr , STAT_DESTINATION ) ~= 0 then
			gh_print( "You enter the building." )
			gh_exit( gh_getstat( self.ptr , STAT_DESTINATION ) )
		end
	end


	-- The gh_prototypes table sorts the prototypes according to G,S descriptors
	gh_prototypes = {}
	gh_prototypes.default = proto_gear

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
	if gh_prototypes[ gh_gearg( gearptr ) ] ~= nil then
		if gh_prototypes[ gh_gearg( gearptr ) ][ gh_gears( gearptr ) ] ~= nil then
			proto = gh_prototypes[ gh_gearg( gearptr ) ][ gh_gears( gearptr ) ]
		elseif gh_prototypes[ gh_gearg( gearptr ) ].default ~= nil then
			proto = gh_prototypes[ gh_gearg( gearptr ) ].default
		end
	end

	P = proto:new()
	P.ptr = gearptr
	P.stat.ptr = gearptr

	-- If this gear has a Narrative ID, store it in the reverse lookup table.
	local nid = gh_getnatt( gearptr , NAG_NARRATIVE , NAS_NID )
	if nid ~= 0 then
		nid_lookup[nid] = gearptr
	end

	a,b = pcall( gearscript )
	gh[gearptr] = P

	if not a then
		error( b )
	end
end

function gh_deregister( gearptr )
	-- Given a gear pointer, dispose of its entry in the gh table.
	-- Also dispose of its reverse lookup, if appropriate.
	local nid = gh_getnatt( gearptr , NAG_NARRATIVE , NAS_NID )
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
		end--   **********************

	end
	return script_found
end






