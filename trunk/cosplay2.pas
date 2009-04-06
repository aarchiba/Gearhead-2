program cosplay2;

uses gears,glgfx,glmenus,colormenu;

Procedure RedrawOpening;
	{ The opening menu redraw procedure. }
begin
	ClrScreen;
	InfoBox( ZONE_Menu );
end;


var
	FileMenu: RPGMenuPtr;
	SpriteName: String;

begin
	FileMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( FileMenu , Graphics_Directory + '*.png' );
	RPMSortAlpha( FileMenu );
	SpriteName := '';

	repeat
		SpriteName := SelectFile( FileMenu , @RedrawOpening );
		if SpriteName <> '' then SelectColorPalette( 0, SpriteName, '200 0 0 200 200 0 0 200 0', 100, 150, @ClrScreen );

	until SpriteName = '';

	DisposeRPGMenu( FileMenu );
end.
