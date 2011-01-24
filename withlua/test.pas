program test;

uses lua,gears,gearparser;

var
	it: GearPtr;

Procedure HandleTrigger( MyGear: GearPtr; const T: String );

begin
	lua_getglobal( MyLua , 'gh_trigger' );
	lua_pushlightuserdata( MyLua , @MyGear );
	lua_pushlstring( MyLua , @T[1] , Length( T ) );
	if lua_pcall( MyLua , 2 , 0 , 0 ) <> 0 then RecordError( 'HandleTrigger ERROR: ' + lua_tostring( MyLua , -1 ) );
end;

begin
	writeln( 'So far so good...' );
	it := LoadFile( './tgear.txt' );
	if it <> Nil then begin
		InitGearScript( it );
		HandleTrigger( it , 'test' );
		DisposeGear( it );
	end else begin
		writeln( 'File load failed.' );
	end;
end.
