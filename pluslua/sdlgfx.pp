unit sdlgfx;
{
	Dungeone Monkey Unlimited, a tactics combat CRPG
	Copyright (C) 2010 Joseph Hewitt

	This library is free software; you can redistribute it and/or modify it
	under the terms of the GNU Lesser General Public License as published by
	the Free Software Foundation; either version 2.1 of the License, or (at
	your option) any later version.

	The full text of the LGPL can be found in license.txt.

	This library is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
	General Public License for more details. 

	You should have received a copy of the GNU Lesser General Public License
	along with this library; if not, write to the Free Software Foundation,
	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA 
}
{
	2D graphics unit ripped from GearHead, because I can.
}

{$MODE FPC}
{$LONGSTRINGS ON}

interface

uses SDL,SDL_TTF,SDL_Image,gears,texutil,dos,sysutils;

Type
	SensibleSpritePtr = ^SensibleSprite;
	SensibleSprite = Record
		Name,Color: String;
		W,H: Integer;	{ Width and Height of each cell. }
		Img: PSDL_Surface;
		Basically_Unimportant: Boolean;	{ Sprite will be removed during regular upkeep. }
		Next: SensibleSpritePtr;
	end;

	RedrawProcedureType = Procedure;


const
	TextColor: TSDL_Color =		( r:240; g:240; b: 50 );
	GoodGreen: TSDL_Color =		( r:90; g:240; b: 50 );
	BadRed: TSDL_Color =		( r:240; g:50; b: 0 );
	PlayerBlue: TSDL_Color =	( r:  0; g:141; b:211 );
	BorderBlue: TSDL_Color =	( r:  0; g:101; b:151 );
	InfoGreen: TSDL_Color =		( r:  0; g:240; b:  0 );
	InfoHiLight: TSDL_Color =	( r: 70; g:255; b: 70 );

	StdBlack: TSDL_Color =		( r:  5; g:  5; b:  5 );
	StdWhite: TSDL_Color =		( r:255; g:255; b:255 );
	MenuItem: TSDL_Color =		( r:150; g:145; b:130 );
	MenuSelect: TSDL_Color =	( r:250; g:250; b:125 );
	NeutralGrey: TSDL_Color =	( r:150; g:150; b:150 );
	EnemyRed: TSDL_Color =		( r:230; g:  0; b:  0 );
	MelodyYellow: TSDL_Color = 	( r:250; g:200; b: 0  );


	Parchment: TSDL_Color = 	( r:255; g:255; b:204 );

	FontSize = 11;
	SmallFontSize = 8;

	KEY_REPEAT_DELAY = 200;
	KEY_REPEAT_INTERVAL = 75;

	Console_History_Length = 240;

	Animation_Phase_Period = 6000;


var
	Game_Screen: PSDL_Surface;
	Game_Font,Small_Font: PTTF_Font;
	Game_Sprites: SensibleSpritePtr;
	Last_Clock_Update: QWord;
	Animation_Phase: Integer;
	Mouse_X, Mouse_Y: LongInt;
	Cursor_Sprite: SensibleSpritePtr;
	Console_History: SAttPtr;
	Title_Screen: SensibleSpritePtr;
	Ersatz_Mouse_Sprite: SensibleSpritePtr;
	Mapbox_Border: SensibleSpritePtr;

	RK_NumKeys:	PInt;
	RK_KeyState:	PUInt8;

	Right_Column_Width: Integer;
	Model_Status_Width: Integer;
	Model_Status_Height: Integer;

	Dialog_Height: Integer;

	Dialog_Area_Height: Integer;

	ScreenWidth: Integer;
	ScreenHeight: Integer;
	ZONE_MainMenu: TSDL_Rect;

	ZONE_TextInputPrompt: TSDL_Rect;
	ZONE_TextInput: TSDL_Rect;
	ZONE_TextInputBigBox: TSDL_Rect;
	ZONE_TextInputSmallBox: TSDL_Rect;

	ZONE_Dialog: TSDL_Rect;

	ZONE_MoreText: TSDL_Rect;
	ZONE_MorePrompt: TSDL_Rect;

	ZONE_Info: TSDL_Rect;
	ZONE_Menu: TSDL_Rect;
	ZONE_Menu1: TSDL_Rect;
	ZONE_Menu2: TSDL_Rect;

	ZONE_CharGenMenu: TSDL_Rect;
	ZONE_CharGenCaption: TSDL_Rect;
	ZONE_CharGenDesc: TSDL_Rect;
	ZONE_CharGenPrompt: TSDL_Rect;

	ZONE_InteractStatus: TSDL_Rect;
	ZONE_InteractMsg: TSDL_Rect;
	ZONE_InteractPhoto: TSDL_Rect;
	ZONE_InteractInfo: TSDL_Rect;
	ZONE_InteractMenu: TSDL_Rect;
	ZONE_InteractTotal: TSDL_Rect;

	{ The ITEMS ZONE is used for both the backpack and shopping interfaces. }
	ItemsLeftWidth: Integer;
	ItemsRightWidth: Integer;
	ItemsZoneLeftTab: Integer;
	ItemsZoneRightTab: Integer;

	ZONE_ItemsTotal: TSDL_Rect;

	ZONE_ShopCaption: TSDL_Rect;
	ZONE_ShopMsg: TSDL_Rect;
	ZONE_ShopMenu: TSDL_Rect;

	ZONE_ItemsInfo: TSDL_Rect;
	ZONE_ItemsPCInfo: TSDL_Rect;

	ZONE_FieldHQMenu: TSDL_Rect;

	ZONE_BackpackInstructions: TSDL_Rect;
	ZONE_EqpMenu: TSDL_Rect;
	ZONE_InvMenu: TSDL_Rect;

	CaptionWidth: Integer;
	SubCaptionWidth: Integer;
	SideInfoWidth: Integer;
	SideInfoHeight: Integer;
	ZONE_Caption: TSDL_Rect;
	ZONE_SubCaption: TSDL_Rect;

	ZONE_CharacterInfo: TSDL_Rect;

	ZONE_RightInfo: TSDL_Rect;
	ZONE_LeftInfo: TSDL_Rect;

	ZONE_SuperGetItem: TSDL_Rect;
	ZONE_GetItemMenu: TSDL_Rect;

	ZONE_UsagePrompt: TSDL_Rect;
	ZONE_UsageMenu: TSDL_Rect;

	ZONE_MemoTotal: TSDL_Rect;
	ZONE_MemoText: TSDL_Rect;
	ZONE_MemoMenu: TSDL_Rect;

	{ The SelectArenaMission zones. }
	ZONE_SAMMenu: TSDL_Rect;
	ZONE_SAMText: TSDL_Rect;

	ZONE_Clock: TSDL_Rect;

	Concert_Zone_Width: Integer;
	Concert_X0: Integer;
	Concert_X1: Integer;
	Concert_Text_Width: Integer;
	Concert_Zone_Height: Integer;
	Concert_y0: Integer;
	Concert_Audience_Height: Integer;
	Concert_Y1: Integer;
	ZONE_ConcertTotal: TSDL_Rect;
	ZONE_ConcertAudience: TSDL_Rect;
	ZONE_ConcertCaption: TSDL_Rect;
	ZONE_ConcertMenu: TSDL_Rect;
	ZONE_ConcertDesc: TSDL_Rect;
	ZONE_ConcertPhoto:  TSDL_Rect;


	Monologue_Width: Integer;
	Monologue_Height: Integer;
	ZONE_MonologueTotal: TSDL_Rect;
	ZONE_MonologueInfo: TSDL_Rect;
	ZONE_MonologueText: TSDL_Rect;
	ZONE_MonologuePortrait: TSDL_Rect;

	Arena_List_Width: Integer;
	Arena_List_Height: Integer;
	ZONE_ArenaPilotMenu: TSDL_Rect;
	ZONE_ArenaMechaMenu: TSDL_Rect;
	ZONE_ArenaInfo: TSDL_Rect;

	ZONE_Title_Screen_Version:  TSDL_Rect;
	ZONE_Title_Screen_Menu:  TSDL_Rect;

	ZONE_PCStatus: TSDL_Rect;


Procedure DoFlip;
Procedure AnimDelay;

Procedure QuickText( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
Procedure QuickTextC( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
Procedure QuickTextRJ( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
Procedure QuickCaption( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );

Procedure DisposeSpriteList(var LList: SensibleSpritePtr);
Procedure RemoveSprite(var LMember: SensibleSpritePtr);

procedure DrawSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
procedure DrawSprite( Spr: SensibleSpritePtr; MyCanvas: PSDL_Surface; MyDest: TSDL_Rect; Frame: Integer );

Function CreateBlankSprite( W,H,Img_W,Img_H: Integer ): SensibleSpritePtr;
function LocateSprite( const Name, Color: String; W,H: Integer ): SensibleSpritePtr;
function LocateSprite( const Name: String; W,H: Integer ): SensibleSpritePtr;
function LocateBUSprite( const Name: String; W,H: Integer ): SensibleSpritePtr;

Procedure CleanSpriteList;

function RPGKey: Char;
procedure ActionKey;


Procedure ClrZone( const Z: TSDL_Rect );
Procedure ClrScreen;
Procedure PrettyPictureDisplay;

Procedure GetNextLine( var TheLine , msg , NextWord: String; Width: Integer );
Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean ): PSDL_Surface;
Procedure CMessage( msg: String; Z: TSDL_Rect; var C: TSDL_Color );
Procedure GameMSG( msg: string; Z: TSDL_Rect; var C: TSDL_Color );

Function IsMoreKey( A: Char ): Boolean;
Procedure MoreKey;
Function TextLength( F: PTTF_Font; msg: String ): LongInt;

Function GetStringFromUser( Prompt: String; ReDrawer: RedrawProcedureType ): String;

Function MoreHighFirstLine( LList: SAttPtr ): Integer;
Procedure MoreText( LList: SAttPtr; FirstLine: Integer );

Procedure RedrawConsole;
Procedure DialogMSG(msg: string);

Procedure InfoBox( Dest: TSDL_Rect );
Procedure MapBox( Dest: TSDL_Rect );
Procedure GotoNextLine( var Z: TSDL_Rect );


Procedure ClearExtendedBorder( Dest: TSDL_Rect );
Procedure DrawBPBorder;
Procedure DrawGetItemBorder;
Procedure SetupInteractDisplay( TeamColor: TSDL_Color );
Procedure SetupServicesDisplay;
Procedure SetupFHQDisplay;
Procedure SetupMemoDisplay;
Procedure DrawMonologueBorder;
Procedure Idle_Display;
Procedure SetupArenaDisplay;
Procedure SetupArenaMissionMenu;
Procedure SetupConcertDisplay;
Procedure SetupTitleScreenDisplay;


implementation

uses uiconfig;

const
	WindowName: PChar = 'GearHead II';
	IconName: PChar = 'GH2';

var
	New_Sprite_Num: LongInt;
	Infobox_Border,Infobox_Backdrop: SensibleSpritePtr;

Procedure SetZones(w, h: Integer);
var
	CenterX: Integer;
	CenterY: Integer;
begin
	ScreenWidth := w;
	ScreenHeight := h;

	CenterX := w div 2;
	CenterY := h div 2;
	Right_Column_Width := 180;
	Model_Status_Width :=   250;
	Model_Status_Height :=  120;

	Dialog_Height := 100;

	Dialog_Area_Height := Model_Status_Height;


	with ZONE_MainMenu do begin x:=CenterX+200; y:=CenterY; w:=200; h:=100; end;

	with ZONE_TextInputPrompt do begin x:=screenwidth div 2 - 210; y:= screenheight div 2 - 35; w:=420; h:=30 ; end;
	with ZONE_TextInput do begin x:=screenwidth div 2 - 210; y:=screenheight div 2 + 5; w:=420; h:=30 ; end;
	with ZONE_TextInputBigBox do begin x:=screenwidth div 2 - 210; y:=screenheight div 2 - 35; w:=420; h:=75 ; end;
	with ZONE_TextInputSmallBox do begin x:=screenwidth div 2 - 215; y:=screenheight div 2; w:=430; h:=40 ; end;

	with ZONE_Dialog do begin x:= 30 + Model_Status_Width; y:= ScreenHeight - Dialog_Height - 10; w:= ScreenWidth - 60 - Model_Status_Width ; h:= Dialog_Height ; end;

	with ZONE_MoreText do begin x:=10; y:=10; w:= ScreenWidth - 20 ; h:= ScreenHeight - 50 ; end;
	with ZONE_MorePrompt do begin x:=10; y:= ScreenHeight - 40 ; w:=ScreenWidth - 20; h:=30 ; end;

	with ZONE_Info do begin x:=  ScreenWidth - Right_Column_Width - 10 ; y:=10; w:=Right_Column_Width; h:=150 ; end;
	with ZONE_Menu do begin x:=  ScreenWidth - Right_Column_Width - 10 ; y:=170; w:=Right_Column_Width; h:=ScreenHeight - 220 - Dialog_Area_Height ; end;
	with ZONE_Menu1 do begin x:=  ScreenWidth - Right_Column_Width - 10 ; y:=170; w:=Right_Column_Width; h:=130 ; end;
	with ZONE_Menu2 do begin x:=  ScreenWidth - Right_Column_Width - 10 ; y:=310; w:=Right_Column_Width; h:=ScreenHeight - 350 - Dialog_Area_Height ; end;

	with ZONE_CharGenMenu do begin x:=ScreenWidth - Right_Column_Width - 20; y:=190; w:=Right_Column_Width; h:=ScreenHeight-250 ; end;
	with ZONE_CharGenCaption do begin x:=ScreenWidth - Right_Column_Width - 20; y:=ScreenHeight-40; w:=Right_Column_Width; h:=20 ; end;
	with ZONE_CharGenDesc do begin x:=10; y:=ScreenHeight - Dialog_Area_Height; w:=ScreenWidth - Right_Column_Width - 50; h:=Dialog_Area_Height-10 ; end;
	with ZONE_CharGenPrompt do begin x:=ScreenWidth - Right_Column_Width - 20; y:=10; w:=Right_Column_Width; h:=160 ; end;

	with ZONE_InteractStatus do begin x:= ScreenWidth div 2 - 225; y:=ScreenHeight Div 2 - 210; w:=345; h:=30 ; end;
	with ZONE_InteractMsg do begin x:= ScreenWidth div 2 - 225; y:=ScreenHeight Div 2 - 140; w:=345; h:= 105 ; end;
	with ZONE_InteractPhoto do begin x:= ScreenWidth div 2 + 125; y:=ScreenHeight Div 2 - 200; w:= 100; h:= 150 ; end;
	with ZONE_InteractInfo do begin x:=ScreenWidth div 2 - 225; y:=ScreenHeight Div 2 - 175; w:= 345; h:= 30 ; end;
	with ZONE_InteractMenu do begin x:= ScreenWidth div 2 - 225; y:=ScreenHeight Div 2 - 30; w:=450; h:= 120 ; end;
	with ZONE_InteractTotal do begin x:= ScreenWidth div 2 - 230; y:= ScreenHeight Div 2 - 215; w:= 460; h:= 310 ; end;

	{ The ITEMS ZONE is used for both the backpack and shopping interfaces. }
	ItemsLeftWidth := 345;
	ItemsRightWidth := 225;
	ItemsZoneLeftTab := ( ScreenWidth - ItemsLeftWidth - ItemsRightWidth - 10 ) div 2;
	ItemsZoneRightTab := ItemsZoneLeftTab + ItemsLeftWidth + 10;

	with ZONE_ItemsTotal do begin x:= ItemsZoneLeftTab - 10; y:=ScreenHeight Div 2 - 220; w:= ItemsLeftWidth + ItemsRightWidth + 30; h:= 330 ; end;

	with ZONE_ShopCaption do begin x:= ItemsZoneLeftTab; y:=ScreenHeight Div 2 - 210; w:= ItemsLeftWidth; h:= 30 ; end;
	with ZONE_ShopMsg do begin x:= ItemsZoneLeftTab; y:=ScreenHeight Div 2 - 140; w:=ItemsLeftWidth; h:= 105 ; end;
	with ZONE_ShopMenu do begin x:= ItemsZoneLeftTab; y:=ScreenHeight Div 2 - 30; w:=ItemsLeftWidth; h:= 120 ; end;

	with ZONE_ItemsInfo do begin x:= ItemsZoneRightTab; y:=ScreenHeight Div 2 - 210; w:= ItemsRightWidth; h:= 275 ; end;
	with ZONE_ItemsPCInfo do begin x:= ItemsZoneRightTab; y:=ScreenHeight Div 2 + 70; w:= ItemsRightWidth; h:= 30 ; end;

	with ZONE_FieldHQMenu do begin x:= ItemsZoneLeftTab; y:=ScreenHeight Div 2 - 210; w:=ItemsLeftWidth; h:= 275 ; end;

	with ZONE_BackpackInstructions do begin x:= ItemsZoneLeftTab; y:=ScreenHeight Div 2 - 210; w:= ItemsLeftWidth; h:= 30 ; end;
	with ZONE_EqpMenu do begin x:= ItemsZoneLeftTab; y:=ScreenHeight Div 2 - 140; w:=ItemsLeftWidth; h:= 105 ; end;
	with ZONE_InvMenu do begin x:= ItemsZoneLeftTab; y:=ScreenHeight Div 2 - 30; w:=ItemsLeftWidth; h:= 120 ; end;

	CaptionWidth := Model_Status_Width;
	with ZONE_Caption do begin x:= ScreenWidth div 2 - ( CaptionWidth div 2 ); y:= 20; w:= CaptionWidth; h:= Model_Status_Height ; end;
	SubCaptionWidth := FontSize * 20;
	with ZONE_SubCaption do begin x:= ScreenWidth div 2 - ( SubCaptionWidth div 2 ); y:= 35 + Model_Status_Height; w:= SubCaptionWidth; h:= FontSize + 2 ; end;

	with ZONE_CharacterInfo do begin x:= ScreenWidth div 2 - 275; y:= ScreenHeight Div 2 - 200; w:= 450; h:= 295 ; end;

	SideInfoWidth := FontSize * 16;
	SideInfoHeight := ( FontSize + 2 ) * 6;
	with ZONE_RightInfo do begin x:= ScreenWidth - SideInfoWidth - 10; y:= 15; w:= SideInfoWidth; h:= SideInfoHeight ; end;
	with ZONE_LeftInfo do begin x:= 10; y:= 15; w:= SideInfoWidth; h:= SideInfoHeight ; end;

	with ZONE_SuperGetItem do begin x:=Screenwidth div 2 - 110; y:=Screenheight div 2 - 135; w:=220; h:=270 ; end;
	with ZONE_GetItemMenu do begin x:=Screenwidth div 2 - 100; y:=Screenheight div 2 - 125; w:=200; h:=250 ; end;

	with ZONE_UsagePrompt do begin x:=CenterX+100; y:=CenterY-300+190; w:=130; h:=170 ; end;
	with ZONE_UsageMenu do begin x:=50; y:=CenterY-300+155; w:=380; h:=245 ; end;

	with ZONE_MemoTotal do begin x:=ScreenWidth div 2 - 205; y:=ScreenHeight div 2 - 195; w:= 410; h:=280 ; end;
	with ZONE_MemoText do begin x:=ScreenWidth div 2 - 200; y:=ScreenHeight div 2 - 190; w:=400; h:=200 ; end;
	with ZONE_MemoMenu do begin x:=ScreenWidth div 2 - 200; y:=ScreenHeight div 2 + 25; w:=400; h:=50 ; end;

	{ The SelectArenaMission zones. }
	with ZONE_SAMMenu do begin x:=ScreenWidth div 2 - 200; y:=ScreenHeight div 2 - 190; w:=400; h:=200 ; end;
	with ZONE_SAMText do begin x:=ScreenWidth div 2 - 200; y:=ScreenHeight div 2 + 25; w:=400; h:=50 ; end;

	with ZONE_Clock do begin x:= ScreenWidth - 150; y:= 30; w:= 120; h:=20 ; end;

	Concert_Zone_Width := 500;
	Concert_X0 := ( ScreenWidth - Concert_Zone_Width ) div 2;
	Concert_X1 := Concert_X0 + 110;
	Concert_Text_Width := Concert_Zone_Width - 110;
	Concert_Zone_Height := 300;
	Concert_y0 := ( ScreenHeight - Concert_Zone_Height - Dialog_Area_Height - 20 ) div 2;
	Concert_Audience_Height := 140;
	Concert_Y1 := Concert_Y0 + Concert_Audience_Height + 10;
	with ZONE_ConcertTotal do begin x:= Concert_X0 ; y:= Concert_Y0; w:= Concert_Zone_Width; h:= Concert_Zone_Height ; end;
	with ZONE_ConcertAudience do begin x:= Concert_X0 ; y:= Concert_Y0; w:= Concert_Zone_Width; h:= Concert_Audience_Height ; end;
	with ZONE_ConcertCaption do begin x:= Concert_X1 ; y:= Concert_Y1; w:= Concert_Text_Width; h:= 40 ; end;
	with ZONE_ConcertMenu do begin x:= Concert_X1 ; y:= Concert_Y1 + 45; w:= Concert_Text_Width; h:= 80 ; end;
	with ZONE_ConcertDesc do begin x:= Concert_X1 ; y:= Concert_Y1 + 130; w:= Concert_Text_Width; h:= 20 ; end;
	with ZONE_ConcertPhoto do begin x:= Concert_X0 ; y:= Concert_Y1; w:= 100; h:= 150 ; end;


	Monologue_Width := 400;
	Monologue_Height := 205;
	with ZONE_MonologueTotal do begin x:= Screenwidth div 2 - Monologue_Width div 2 - 10; y:= ScreenHeight div 3 - Monologue_Height div 2 - 10; w:= Monologue_Width + 20; h:= Monologue_Height + 20 ; end;
	with ZONE_MonologueInfo do begin x:= Screenwidth div 2 - Monologue_Width div 2; y:= ScreenHeight div 3 - Monologue_Height div 2; w:= Monologue_Width; h:=30 ; end;
	with ZONE_MonologueText do begin x:= Screenwidth div 2 - Monologue_Width div 2; y:= ScreenHeight div 3 - Monologue_Height div 2 + 40; w:= Monologue_Width - 110; h:= Monologue_Height - 40 ; end;
	with ZONE_MonologuePortrait do begin x:= Screenwidth div 2 + Monologue_Width div 2 - 100; y:= ScreenHeight div 3 - Monologue_Height div 2 + 40; w:= 100; h:= 150 ; end;

	Arena_List_Width := 240;
	Arena_List_Height := ScreenHeight - ( Dialog_Area_Height + 40 );
	with ZONE_ArenaPilotMenu do begin x:= 10; y:= 10; w:= Arena_List_Width; h:= Arena_List_Height ; end;
	with ZONE_ArenaMechaMenu do begin x:= 50 + Arena_List_Width; y:= 10; w:= Arena_List_Width; h:= Arena_List_Height ; end;
	with ZONE_ArenaInfo do begin x:= screenwidth - 10 - ItemsRightWidth; y:= 10; w:= ItemsRightWidth; h:= Arena_List_Height ; end;

	with ZONE_Title_Screen_Version do begin x:= CenterX+155 ; y:= CenterY-300+222; w:= 50; h:= 20 ; end;
	with ZONE_Title_Screen_Menu do begin x:= CenterX+185 ; y:= CenterY-300+255; w:= 160; h:= 140 ; end;

	with ZONE_PCStatus do begin x:= 20; y:= ScreenHeight - Model_Status_Height - 10; w:= Model_Status_Width; h:= Model_Status_Height ; end;


end;

Procedure DoFlip;
	{ Flip out, man! This flips from the newly drawn screen to the physical screen. }
	{ Go look up Double Buffering on Wikipedia for more info. }
var
	MyDest: TSDL_Rect;
begin
	if Ersatz_Mouse then begin
		MyDest.X := Mouse_X;
		MyDest.Y := Mouse_Y;
		DrawSprite( Ersatz_Mouse_Sprite , MyDest , 0 );
	end;
	SDL_Flip( Game_Screen );
	Animation_Phase := ( Animation_Phase + 1 ) mod Animation_Phase_Period;
end;

Procedure AnimDelay;
	{ Sleep for a short time- long enough to do animations, anyhow. }
var
	D: QWord;
begin
	if ( FrameDelay > 0 ) then begin
		if SDL_GetTicks < Last_Clock_Update then begin
			D := Last_Clock_Update - SDL_GetTicks;
			SDL_Delay( D );
		end;
		Last_Clock_Update := SDL_GetTicks + FrameDelay;
	end;
	SDL_GetMouseState( Mouse_X , Mouse_Y );
end;

Procedure QuickText( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( F , pline , C );
{$IFDEF LINUX}
	if MyText <> Nil then SDL_SetColorKey( MyText , SDL_SRCCOLORKEY , SDL_MapRGB( MyText^.Format , 0 , 0, 0 ) );
{$ENDIF}
	Dispose( pline );
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure QuickTextC( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
	{ The text will be centered in the given zone. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	if msg = '' then Exit;
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( F , pline , C );
{$IFDEF LINUX}
	if MyText <> Nil then SDL_SetColorKey( MyText , SDL_SRCCOLORKEY , SDL_MapRGB( MyText^.Format , 0 , 0, 0 ) );
{$ENDIF}
	Dispose( pline );
	MyDest.X := MyDest.X + ( MyDest.W - MyText^.W ) div 2;
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure QuickTextRJ( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
	{ This variation on the procedure is right-justified. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( F , pline , C );
{$IFDEF LINUX}
	if MyText <> Nil then SDL_SetColorKey( MyText , SDL_SRCCOLORKEY , SDL_MapRGB( MyText^.Format , 0 , 0, 0 ) );
{$ENDIF}
	Dispose( pline );
	MyDest.X := MyDest.X - MyText^.W;
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure QuickCaption( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
	{ The text will be centered in the given zone. }
var
	pline: PChar;
	MyText: PSDL_Surface;
	MyZone: TSDL_Rect;
begin
	if msg = '' then Exit;
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( F , pline , C );
{$IFDEF LINUX}
	if MyText <> Nil then SDL_SetColorKey( MyText , SDL_SRCCOLORKEY , SDL_MapRGB( MyText^.Format , 0 , 0, 0 ) );
{$ENDIF}
	Dispose( pline );
	MyDest.X := MyDest.X + ( MyDest.W - MyText^.W ) div 2;
	MyZone.X := MyDest.X - 3;
	MyZone.Y := MyDest.Y - 1;
	MyZone.W := MyText^.W + 6;
	MyZone.H := MyText^.H + 2;
	SDL_FillRect( game_screen , @MyZone , SDL_MapRGB( Game_Screen^.Format , 36 , 37 , 36 ) );
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure DrawAnimImage( Image,Canvas: PSDL_Surface; W,H,Frame: Integer; var MyDest: TSDL_Rect );
	{ This procedure is modeled after the command from Blitz Basic. }
var
	MySource: TSDL_Rect;
begin
	MySource.W := W;
	MySource.H := H;
	if W > Image^.W then W := Image^.W;
	MySource.X := ( Frame mod ( Image^.W div W ) ) * W;
	MySource.Y := ( Frame div ( Image^.W div W ) ) * H;

	SDL_BlitSurface( Image , @MySource , Canvas , @MyDest );
end;

Function ScaleColorValue( V , I: Integer ): Byte;
	{ Scale a color value. }
begin
	V := ( V * I ) div 200;
	if V > 255 then V := 255;
	if V < 0 then V := 0;
	ScaleColorValue := V;
end;


Function MakeSwapBitmap( MyImage: PSDL_Surface; RSwap,YSwap,GSwap: PSDL_Color ): PSDL_Surface;
var
	X,Y: Integer;
	MyImage2: PSDL_Surface;
	pixel: ^LONGWORD;
	R,G,B,A: Byte;
	Ri, Gi, Bi: Integer;
	C1, C2, C3: Integer;
	pitch: Integer;
	flags: LONGWORD;
	alpha: Byte;
begin
	{Make 32-bit copy}
	MyImage2 := SDL_CreateRGBSurface( SDL_SWSURFACE or SDL_SRCALPHA , MyImage^.W , MyImage^.H , 
					32 , $ff000000 , $00ff0000 , $0000ff00 , $000000ff );

	flags := MyImage^.flags;
	alpha := MyImage^.format^.alpha;
	{ Turn off SDL_SRCALPHA so the blit is a copy }
	SDL_SetAlpha( MyImage , flags and not SDL_SRCALPHA and not SDL_SRCCOLORKEY , 255 );
	SDL_BlitSurface( MyImage , Nil , MyImage2 , Nil );
	SDL_SetAlpha( MyImage , flags , alpha );
	{Lock}
	SDL_LockSurface(MyImage2);
	pitch := MyImage2^.pitch;
	{Remap colors}
	for X := 1 to MyImage^.W do begin
		for Y := 1 to MyImage^.H do begin
			{Extract color}
			pixel := MyImage2^.pixels+(X-1)*4+(Y-1)*pitch;
			SDL_GetRGBA(pixel^, MyImage2^.format, @R, @G, @B, @A);
			{If it's pure Y R or G, remap it}
			{If it's blue, set alpha}
			if (B>240) and (R<16) and (G<16) then begin
				A := 0;
			end else if (RSwap <> Nil) and (GSwap <> Nil) and (YSwap <> Nil) then begin
				Ri := R;
				Gi := G;
				Bi := B;
				if (R>G) then begin
					{Between yellow and red}
					C1 := B;
					C2 := G-B;
					C3 := R-G;
					if (C2<0) then C2 := 0;
					Ri := C1 + ScaleColorValue( RSwap^.R , C3 ) + ScaleColorValue( YSwap^.R , C2 ) ;
					Gi := C1 + ScaleColorValue( RSwap^.G , C3 ) + ScaleColorValue( YSwap^.G , C2 ) ;
					Bi := C1 + ScaleColorValue( RSwap^.B , C3 ) + ScaleColorValue( YSwap^.B , C2 ) ;
				end else begin
					{Between green and yellow}
					C1 := B;
					C2 := R-B;
					C3 := G-R;
					if (C2<0) then C2 := 0;
					Ri := C1 + ScaleColorValue( GSwap^.R , C3 ) + ScaleColorValue( YSwap^.R , C2 ) ;
					Gi := C1 + ScaleColorValue( GSwap^.G , C3 ) + ScaleColorValue( YSwap^.G , C2 ) ;
					Bi := C1 + ScaleColorValue( GSwap^.B , C3 ) + ScaleColorValue( YSwap^.B , C2 ) ;
				end;
				if (Ri>255) then R := 255 else if (Ri<0) then R := 0 else R := Ri;
				if (Gi>255) then G := 255 else if (Gi<0) then G := 0 else G := Gi;
				if (Bi>255) then B := 255 else if (Bi<0) then B := 0 else B := Bi;
			end;
			{Write color to surface}
			pixel^ := SDL_MapRGBA(MyImage2^.format, R, G, B, A);
		end
	end;
	{Unlock}
	SDL_UnlockSurface(MyImage2);
	{FIXME: convert to a good format for blitting to the screen? }
	{Return new surface}
	MakeSwapBitmap := MyImage2;
end;

Function MakeSwapBitmapPaletted( MyImage: PSDL_Surface; RSwap,YSwap,GSwap: PSDL_Color ): PSDL_Surface;
	{ Given a bitmap, create an 8-bit copy with pure colors. }
	{         0 : Transparent (0,0,255) }
	{   1 -  63 : Grey Scale            }
	{  64 - 127 : Pure Red              }
	{ 128 - 191 : Pure Yellow           }
	{ 192 - 255 : Pure Green            }
	{ Then, swap those colors out for the requested colors. }
var
	MyPal: Array [0..255] of TSDL_Color;
	T: Integer;
	MyImage2: PSDL_Surface;
begin
	{ Initialize the palette. }
	for t := 1 to 64 do begin
		MyPal[ T - 1 ].r := ( t * 4 ) - 1;
		MyPal[ T - 1 ].g := ( t * 4 ) - 1;
		MyPal[ T - 1 ].b := ( t * 4 ) - 1;

		MyPal[ T + 63 ].r := ( t * 4 ) - 1;
		MyPal[ T + 63 ].g := 0;
		MyPal[ T + 63 ].b := 0;

		MyPal[ T + 127 ].r := ( t * 4 ) - 1;
		MyPal[ T + 127 ].g := ( t * 4 ) - 1;
		MyPal[ T + 127 ].b := 0;

		MyPal[ T + 191 ].r := 0;
		MyPal[ T + 191 ].g := ( t * 4 ) - 1;
		MyPal[ T + 191 ].b := 0;
	end;
	MyPal[ 0 ].r := 0;
	MyPal[ 0 ].g := 0;
	MyPal[ 0 ].b := 255;

	{ Create replacement surface. }
	MyImage2 := SDL_CreateRGBSurface( SDL_SWSURFACE , MyImage^.W , MyImage^.H , 8 , 0 , 0 , 0 , 0 );
	SDL_SetPalette( MyImage2 , SDL_LOGPAL or SDL_PHYSPAL , MyPal , 0 , 256 );
	SDL_FillRect( MyImage2 , Nil , SDL_MapRGB( MyImage2^.Format , 0 , 0 , 255 ) );
	SDL_SetColorKey( MyImage2 , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( MyImage2^.Format , 0 , 0, 255 ) );

	{ Blit from the original to the copy. }
	SDL_BlitSurface( MyImage , Nil , MyImage2 , Nil );

	{ Redefine the palette. }
	for t := 1 to 64 do begin
		MyPal[ T + 63 ].r := ScaleColorValue( RSwap^.R , t * 4 );
		MyPal[ T + 63 ].g := ScaleColorValue( RSwap^.G , t * 4 );
		MyPal[ T + 63 ].b := ScaleColorValue( RSwap^.B , t * 4 );

		MyPal[ T + 127 ].r := ScaleColorValue( YSwap^.R , t * 4 );
		MyPal[ T + 127 ].g := ScaleColorValue( YSwap^.G , t * 4 );
		MyPal[ T + 127 ].b := ScaleColorValue( YSwap^.B , t * 4 );

		MyPal[ T + 191 ].r := ScaleColorValue( GSwap^.R , t * 4 );
		MyPal[ T + 191 ].g := ScaleColorValue( GSwap^.G , t * 4 );
		MyPal[ T + 191 ].b := ScaleColorValue( GSwap^.B , t * 4 );
	end;
	SDL_SetPalette( MyImage2 , SDL_LOGPAL or SDL_PHYSPAL , MyPal , 0 , 256 );

	MakeSwapBitmapPaletted := MyImage2;
end;

Procedure GenerateColor( var ColorString: String; var ColorStruct: TSDL_Color );
	{ Generate the color from the string. }
var
	n: Integer;
begin
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.R := n;
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.G := n;
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.B := n;
end;


Function LocateSpriteByNameColor( const name,color: String ): SensibleSpritePtr;
	{ Locate the sprite which matches the name provided. }
	{ If no such sprite exists, return Nil. }
var
	S: SensibleSpritePtr;
begin
	S := Game_Sprites;
	while ( S <> Nil ) and ( ( S^.Name <> name ) or ( S^.Color <> Color ) ) do begin
		S := S^.Next;
	end;
	LocateSpriteByNameColor := S;
end;

Function NewSprite: SensibleSpritePtr;
	{ Add an empty sprite description to the list. }
var
	it: SensibleSpritePtr;
begin
	New(it);
	if it = Nil then exit( Nil );
	{Initialize values.}
	it^.Next := Game_Sprites;
	it^.Basically_Unimportant := False;
	Game_Sprites := it;
	NewSprite := it;
end;

Function AddSprite( name, color: String; W,H: Integer ): SensibleSpritePtr;
	{ Add a new element to the Sprite List. Load the image for this sprite }
	{ from disk, if possible. }
var
	fname: PChar;
	it: SensibleSpritePtr;
	tmp: PSDL_Surface;
	RSwap,YSwap,GSwap: TSDL_Color;
begin
	{Allocate memory for our new element.}
	it := NewSprite;
	if it = Nil then Exit( Nil );
	it^.Name := Name;
	it^.Color := Color;
	it^.W := W;
	it^.H := H;

	name := FSearch( name , Graphics_Directory );

	if name <> '' then begin
		fname := QuickPCopy( name );

		{ Attempt to load the image. }
		it^.Img := IMG_Load( fname );

		if it^.Img <> Nil then begin
			{ Set transparency color. }
			{ SDL_SetColorKey( it^.Img , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( it^.Img^.Format , 0 , 0, 255 ) ); }

			{ If W or H are zero, use the image's total W and H. }
			if ( W = 0 ) or ( H = 0 ) then begin
				it^.w := it^.Img^.w;
				it^.h := it^.Img^.h;
			end;

			{ If a color swap has been specified, handle that here. }
			if (Color = '') then begin
				tmp := MakeSwapBitmap( it^.Img , Nil , Nil , Nil );
			end else begin
				GenerateColor( Color , RSwap );
				GenerateColor( Color , YSwap );
				GenerateColor( Color , GSwap );
				tmp := MakeSwapBitmap( it^.Img , @RSwap , @YSwap , @GSwap );
			end;

			SDL_FreeSurface( it^.Img );
			it^.img := tmp;

			{ Convert to the screen mode. }
			{ This will make blitting far quicker. }
			tmp := SDL_DisplayFormatAlpha( it^.Img );
			SDL_FreeSurface( it^.Img );
			it^.Img := TMP;
		end;

		Dispose( fname );
	end else begin
		it^.Img := Nil;

	end;

	{Return a pointer to the new element.}
	AddSprite := it;
end;

Function CreateBlankSprite( W,H,Img_W,Img_H: Integer ): SensibleSpritePtr;
	{ Add a new element to the Sprite List. Give it a unique name and }
	{ a blank image of the requested dimensions. }
var
	it: SensibleSpritePtr;
	tmp: PSDL_Surface;
begin
	{Allocate memory for our new element.}
	it := NewSprite;
	if it = Nil then Exit( Nil );
	it^.Name := 'CBS-' + BStr( New_Sprite_Num );
	Inc( New_Sprite_Num );
	it^.Color := '';
	it^.W := W;
	if Img_W < W then Img_W := W;
	it^.H := H;
	if Img_H < H then Img_H := H;

	{ Create the image. }
	it^.Img := SDL_CreateRGBSurface( SDL_SWSURFACE , Img_W, Img_H, 32 , $000000ff , $0000ff00 , $00ff0000 , $ff000000 );
	SDL_SetColorKey( it^.Img , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( it^.Img^.Format , 0 , 0, 255 ) );
	SDL_FillRect( it^.Img , Nil , SDL_MapRGBA( It^.Img^.Format , 255 , 0 , 255 , 0 ) );

	{ Convert to the screen mode. }
	{ This will make blitting far quicker. }
	tmp := SDL_ConvertSurface( it^.Img , Game_Screen^.Format , SDL_SRCCOLORKEY );
	SDL_FreeSurface( it^.Img );
	it^.Img := TMP;


	{Return a pointer to the new element.}
	CreateBlankSprite := it;
end;

Procedure DisposeSpriteList(var LList: SensibleSpritePtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: SensibleSpritePtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;

		if LList^.Img <> Nil then SDL_FreeSurface( LList^.Img );

		Dispose(LList);
		LList := LTemp;
	end;
end;


Procedure RemoveSprite(var LMember: SensibleSpritePtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: SensibleSpritePtr;
begin
	{Initialize A and B}
	B := Game_Sprites;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- RemoveLink asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		Game_Sprites := B^.Next;
		B^.Next := Nil;
		DisposeSpriteList(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		B^.Next := Nil;
		DisposeSpriteList(B);
	end;

	LMember := Nil;
end;

procedure DrawSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
	{ Draw a sensible sprite. }
begin
	{ First make sure that we have some valid sprite data... }
	if ( Spr <> Nil ) and ( Spr^.Img <> Nil ) then begin
		{ All the info checks out. Print it. }
		DrawAnimImage( Spr^.Img , Game_Screen , Spr^.W , Spr^.H , Frame , MyDest );
	end;
end;

procedure DrawSprite( Spr: SensibleSpritePtr; MyCanvas: PSDL_Surface; MyDest: TSDL_Rect; Frame: Integer );
	{ Draw a sensible sprite to an arbitrary canvas. }
begin
	{ First make sure that we have some valid sprite data... }
	if ( Spr <> Nil ) and ( Spr^.Img <> Nil ) then begin
		{ All the info checks out. Print it. }
		DrawAnimImage( Spr^.Img , MyCanvas , Spr^.W , Spr^.H , Frame , MyDest );
	end;
end;

function LocateSprite( const Name,Color: String; W,H: Integer ): SensibleSpritePtr;
	{ Try to locate the requested sprite in the requested color. If the sprite }
	{ is already loaded, then return its address. If not, load it and color it. }
var
	S: SensibleSpritePtr;
begin
	{ First, find the sprite. If by some strange chance it hasn't been }
	{ loaded yet, load it now. }
	S := LocateSpriteByNameColor( Name , Color );
	if S = Nil then S := AddSprite( Name , Color , W , H );
	S^.Basically_Unimportant := False;

	LocateSprite := S;
end;

function LocateSprite( const Name: String; W,H: Integer ): SensibleSpritePtr;
	{ Find the requested sprite, either in memory or from disk. }
var
	S: SensibleSpritePtr;
	i: Integer;
	n, c: String;
begin
	n := Name;
	c := '';
	{ Check whether sprite name specifies a color }
	for i:=1 to length(Name) do begin
		if Name[i]=':' then begin
			n := LeftStr(Name, i-1);
			c := RightStr(Name, length(Name)-i);
			Break;
		end;
	end;

	{ First, find the sprite. If by some strange chance it hasn't been }
	{ loaded yet, load it now. }
	LocateSprite := LocateSprite( n , c , W , H );
end;

function LocateBUSprite( const Name: String; W,H: Integer ): SensibleSpritePtr;
	{ Locate a basically unimportant sprite. If found, return it. }
	{ If it has to be loaded from disk, mark it as basically unimportant. }
var
	S: SensibleSpritePtr;
begin
	S := LocateSpriteByNameColor( Name , '' );
	if S = Nil then begin
		S := AddSprite( Name , '' , W , H );
		S^.Basically_Unimportant := True;
	end;

	LocateBUSprite := S;
end;

Procedure CleanSpriteList;
	{ Go through the sprite list and remove those sprites we aren't likely to }
	{ need immediately... i.e., erase those ones which have a COLOR string defined. }
var
	S,S2: SensibleSpritePtr;
begin
	S := Game_Sprites;
	while S <> Nil do begin
		S2 := S^.Next;

		if S^.Basically_Unimportant then begin
			RemoveSprite( S );
		end;

		S := S2;
	end;
end;

function RPGKey: Char;
	{ Read a readable key from the keyboard and return its ASCII value. }
	{ This function will always return within a close approximation of 30ms }
	{ from the last time it was called. It will also update the array of }
	{ keypresses. }
var
	a: String;
	event : TSDL_Event;
	Procedure ProcessThatEvent;
		{ An event has been recieved. Process it. }
	begin
		if event.type_ = SDL_KEYDOWN then begin
			{ Check to see if it was an ASCII character we recieved. }
			case event.key.keysym.sym of
				SDLK_Up,SDLK_KP8:	a := RPK_Up;
				SDLK_Down,SDLK_KP2:	a := RPK_Down;
				SDLK_Left,SDLK_KP4:	a := RPK_Left;
				SDLK_Right,SDLK_KP6:	a := RPK_Right;
				SDLK_KP7:		a := RPK_UpLeft;
				SDLK_KP9:		a := RPK_UpRight;
				SDLK_KP1:		a := RPK_DownLeft;
				SDLK_KP3:		a := RPK_DownRight;
				SDLK_Backspace:		a := #8;
				SDLK_KP_Enter:		a := #10;
				SDLK_KP5:		a := '5';
			else
				if( event.key.keysym.unicode <  $80 ) and ( event.key.keysym.unicode > 0 ) then begin
					a := Char( event.key.keysym.unicode );
				end;
			end;

		end else if ( event.type_ = SDL_MOUSEButtonDown ) then begin
			{ Return a mousebutton event, and call GHFlip to set the mouse position }
			{ variables. }
			if event.button.button = SDL_BUTTON_LEFT then begin
				a := RPK_MouseButton;
			end else if event.button.button = SDL_BUTTON_RIGHT then begin
				a := RPK_RightButton;
			end;
		end else if ( event.type_ = SDL_VIDEORESIZE ) then begin
			writeln('Resizing');
			if DoFullScreen then begin
				Game_Screen := SDL_SetVideoMode(event.resize.w, event.resize.h, 32, SDL_RESIZABLE or SDL_DOUBLEBUF or SDL_FULLSCREEN );
			end else begin
				Game_Screen := SDL_SetVideoMode(event.resize.w, event.resize.h, 32, SDL_RESIZABLE or SDL_DOUBLEBUF );
			end;
			SetZones(Game_Screen^.w,Game_Screen^.h);
		end;
	end;
var
	D: QWord;
	PResult: Integer;
begin
	{ Go through the accumulated events looking for good ones. }
	a := RPK_TimeEvent;
	repeat
		PResult := SDL_PollEvent( @event );
		if PResult = 1 then begin
			{ See if this event is a keyboard one... }
			ProcessThatEvent;
		end;
	until ( PResult <> 1 ) or ( a <> RPK_TimeEvent );

	{ If necessary, do a delay. }
	if SDL_GetTicks < Last_Clock_Update then begin
		D := Last_Clock_Update - SDL_GetTicks;
		SDL_Delay( D );
	end;
	Last_Clock_Update := SDL_GetTicks + 30;

	RK_KeyState := SDL_GetKeyState( RK_NumKeys );
	SDL_GetMouseState( Mouse_X , Mouse_Y );

	if a <> '' then RPGKey := a[1]
	else RPGKey := 'Z';
end;

procedure ActionKey;
	{ Do the anim delay and update the keyboard map. }
var
	event : TSDL_Event;
	D: QWord;
	PResult: Integer;
begin
	{ Go through the accumulated events looking for good ones. }
	repeat
		PResult := SDL_PollEvent( @event );
	until ( PResult <> 1 );

	{ If necessary, do a delay. }
	if SDL_GetTicks < Last_Clock_Update then begin
		D := Last_Clock_Update - SDL_GetTicks;
		SDL_Delay( D );
	end;
	Last_Clock_Update := SDL_GetTicks + 20;

	RK_KeyState := SDL_GetKeyState( RK_NumKeys );
	SDL_GetMouseState( Mouse_X , Mouse_Y );
end;


Procedure ClrZone( const Z: TSDL_Rect );
	{ Clear the specified screen zone. }
begin
	SDL_FillRect( game_screen , @Z , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
end;

Procedure ClrScreen;
	{ Clear the specified screen zone. }
begin
	SDL_FillRect( game_screen , Nil , SDL_MapRGBA( Game_Screen^.Format , 0 , 0 , 0 , 0 ) );
end;

Procedure PrettyPictureDisplay;
	{ Draw a pretty picture for use as a backdrop in the main menu, when }
	{ creating characters, and so forth. }
begin
	SDL_BlitSurface( Title_Screen^.Img , Nil , Game_Screen , Nil );
end;

Function TextLength( F: PTTF_Font; msg: String ): LongInt;
	{ Determine how long "msg" will be using the default "game_font". }
var
	pmsg: PChar;	{ Gotta convert to pchar, pain in the ass... }
	W,Y: LongInt;	{ W means width I guess... Y is anyone's guess. Height? }
begin
	{ Convert the string to a pchar. }
	pmsg := QuickPCopy( msg );

	{ Call the alleged size calculation function. }
	TTF_SizeText( F , pmsg , W , Y );

	{ get rid of the PChar, since it's served its usefulness. }
	Dispose( pmsg );

	TextLength := W;
end;

Procedure GetNextLine( var TheLine , msg , NextWord: String; Width: Integer );
	{ Get a line of text of maximum width "Width". }
var
	LC: Boolean;	{ Loop Condition. So I wasn't very creative when I named it, so what? }
begin
	{ Loop condition starts out as TRUE. }
	LC := True;

	{ Start building the line. }
	repeat
		NextWord := ExtractWord( Msg );

		if TextLength( Game_Font , THEline + ' ' + NextWord) < Width then
			THEline := THEline + ' ' + NextWord
		else
			LC := False;

	until (not LC) or (NextWord = '') or ( TheLine[Length(TheLine)] = #13 );

	{ If the line ended due to a line break, deal with it. }
	if ( TheLine[Length(TheLine)] = #13 ) then begin
		{ Display the line break as a space. }
		TheLine[Length(TheLine)] := ' ';
		NextWord := ExtractWord( msg );
	end;

end;

Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean ): PSDL_Surface;
	{ Create a SDL_Surface containing all the text within "msg" formatted }
	{ in lines of no longer than "width" pixels. Sound simple? Mostly just }
	{ tedious, I'm afraid. }
var
	SList,SA: SAttPtr;
	S_Total,S_Temp: PSDL_Surface;
	MyDest: SDL_Rect;
	pline: PChar;
	NextWord: String;
	THELine: String;	{The line under construction.}
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	if msg = '' then Exit( Nil );

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );
	NextWord := '';
	SList := Nil;

	{Start the main processing loop.}
	while TheLine <> '' do begin
		GetNextLine( TheLine , msg , NextWord , Width );

		{ Output the line. }
		{ Next append it to whatever has already been created. }
		StoreSAtt( SList , TheLine );

		{ Prepare for the next iteration. }
		TheLine := NextWord;
	end; { while TheLine <> '' }

	{ Create a bitmap for the message. }
	if SList <> Nil then begin
		{ Create a big bitmap to hold everything. }
		S_Total := SDL_CreateRGBSurface( SDL_SWSURFACE , width , TTF_FontLineSkip( game_font ) * NumSAtts( SList ) , 32 , $FF000000 , $00FF0000 , $0000FF00 , $000000FF );

		MyDest.X := 0;
		MyDest.Y := 0;

		{ Add each stored string to the bitmap. }
		SA := SList;
		while SA <> Nil do begin
			pline := QuickPCopy( SA^.Info );
			S_Temp := TTF_RenderText_Solid( game_font , pline , fg );
{$IFDEF LINUX}
			SDL_SetColorKey( S_Temp , SDL_SRCCOLORKEY , SDL_MapRGB( S_Temp^.Format , 0 , 0, 0 ) );
{$ENDIF}

			Dispose( pline );

			{ We may or may not be required to do centering of the text. }
			if DoCenter then begin
				MyDest.X := ( Width - TextLength( Game_Font , SA^.Info ) ) div 2;
			end else begin
				MyDest.X := 0;
			end;

			SDL_BlitSurface( S_Temp , Nil , S_Total , @MyDest );
			SDL_FreeSurface( S_Temp );
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( game_font );
			SA := SA^.Next;
		end;
		DisposeSAtt( SList );
	end else begin
		S_Total := Nil;
	end;


	PrettyPrint := S_Total;
end;

Procedure CMessage( msg: String; Z: TSDL_Rect; var C: TSDL_Color );
	{ Print a message to the screen, centered in the requested rect. }
	{ Clear the specified zone before doing so. }
var
	MyText: PSDL_Surface;
	MyDest: TSDL_Rect;
begin
	if msg = '' then Exit;
	MyText := PrettyPrint( msg , Z.W , C , True );
	if MyText <> Nil then begin
		MyDest := Z;
		MyDest.Y := MyDest.Y + ( Z.H - MyText^.H ) div 2;
		SDL_SetClipRect( Game_Screen , @Z );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;

Procedure GameMSG( msg: string; Z: TSDL_Rect; var C: TSDL_Color );
	{ As above, but no pageflip. }
var
	MyText: PSDL_Surface;
begin
	if msg = '' then Exit;
	MyText := PrettyPrint( msg , Z.W , C , True );
	if MyText <> Nil then begin
		SDL_SetClipRect( Game_Screen , @Z );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @Z );
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;

Function IsMoreKey( A: Char ): Boolean;
	{ Return TRUE if A is a "more" key, that should skip to the next message in a list. }
begin
	IsMoreKey := ( A = ' ' ) or ( A = #27 ) or ( A = RPK_MouseButton );
end;

Procedure MoreKey;
	{ Wait for the user to press either the space bar or the ESC key. }
var
	A: Char;
begin
	{ Keep reading keypresses until either a space or an ESC is found. }
	repeat
		A := RPGKey;
	until IsMoreKey( A );
end;

Function GetStringFromUser( Prompt: String; ReDrawer: RedrawProcedureType ): String;
	{ Does what it says. }
const
	AllowableCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890()-=_+,.?"';
	MaxInputLength = 80;
var
	A: Char;
	it: String;
	MyDest: TSDL_Rect;
begin
	{ Initialize string. }
	it := '';

	repeat
		{ Set up the display. }
		if ReDrawer <> Nil then ReDrawer;
		InfoBox( ZONE_TextInputBigBox );
		SDL_FillRect( game_screen , @ZONE_TextInputSmallBox , SDL_MapRGB( Game_Screen^.Format , StdBlack.R , StdBlack.G , StdBlack.B ) );

		CMessage( Prompt , ZONE_TextInputPrompt , StdWhite );
		CMessage( it , ZONE_TextInput , TextColor );
		MyDest.Y := ZONE_TextInput.Y + 2;
		MyDest.X := ZONE_TextInput.X + ( ZONE_TextInput.W div 2 ) + ( TextLength( Game_Font , it ) div 2 );
		DrawSprite( Cursor_Sprite , MyDest , ( Animation_Phase div 2 ) mod 4 );

		DoFlip;
		A := RPGKey;

		if ( A = #8 ) and ( Length( it ) > 0 ) then begin
			it := Copy( it , 1 , Length( it ) - 1 );
		end else if ( Pos( A , AllowableCharacters ) > 0 ) and ( Length( it ) < MaxInputLength ) then begin
			it := it + A;
		end;
	until ( A = #13 ) or ( A = #27 );

	GetStringFromUser := it;
end;

Function MoreHighFirstLine( LList: SAttPtr ): Integer;
	{ Determine the highest possible FirstLine value. }
var
	it: Integer;
begin
	it := NumSAtts( LList ) - ( ZONE_MoreText.H  div  TTF_FontLineSkip( game_font ) ) + 1;
	if it < 1 then it := 1;
	MoreHighFirstLine := it;
end;

Procedure MoreText( LList: SAttPtr; FirstLine: Integer );
	{ Browse this text file across the majority of the screen. }
	{ Clear the screen upon exiting, though restoration of the }
	{ previous display is someone else's responsibility. }
	Procedure DisplayTextHere;
	var
		T: Integer;
		MyDest: TSDL_Rect;
		MyImage: PSDL_Surface;
		CLine: SAttPtr;	{ Current Line }
		PLine: PChar;
	begin
		ClrScreen;
		InfoBox( ZONE_MorePrompt );
		InfoBox( ZONE_MoreText );
		CMessage( 'Up, Down, You know...' , ZONE_MorePrompt , TextColor );

		{ Set the clip area. }
		SDL_SetClipRect( Game_Screen , @ZONE_MoreText );
		MyDest := ZONE_MoreText;

		{ Error check. }
		if FirstLine < 1 then FirstLine := 1
		else if FirstLine > MoreHighFirstLine( LList ) then FirstLine := MoreHighFirstLine( LList );

		CLine := RetrieveSATt( LList , FirstLine );
		for t := 1 to ( ZONE_MoreText.H  div  TTF_FontLineSkip( game_font ) ) do begin
			if CLine <> Nil then begin
				pline := QuickPCopy( CLine^.Info );
				MyImage := TTF_RenderText_Solid( game_font , pline , NeutralGrey );
				Dispose( pline );
				SDL_BlitSurface( MyImage , Nil , Game_Screen , @MyDest );
				SDL_FreeSurface( MyImage );
				MyDest.Y := MyDest.Y + TTF_FontLineSkip( game_font );
				CLine := CLine^.Next;
			end;
		end;

		{ Restore the clip area. }
		SDL_SetClipRect( Game_Screen , Nil );
		DoFlip;
	end;
var
	A: Char;
begin
	{ Display the screen. }
	DisplayTextHere;

	repeat
		{ Get input from user. }
		A := RPGKey;

		{ Possibly process this input. }
		if ( A = '2' ) or ( A = RPK_Down ) then begin
			Inc( FirstLine );
			DisplayTextHere;
		end else if ( A = '8' ) or ( A = RPK_Up ) then begin
			Dec( FirstLine );
			DisplayTextHere;
		end;

	until ( A = #27 ) or ( A = 'Q' ) or ( A = #8 );
end;

Procedure RedrawConsole;
	{ Redraw the console. Yay! }
var
	SL: SAttPtr;
	MyDest: TSDL_Rect;
	NumLines,LineNum: Integer;
begin
	{Clear the message area, and set clipping bounds.}
	InfoBox( ZONE_Dialog );
	SDL_SetClipRect( Game_Screen , @ZONE_Dialog );

	MyDest := ZONE_Dialog;
	NumLines := ( ZONE_Dialog.H div TTF_FontLineSkip( game_font ) ) + 1;
	LineNum := NumLines;
	SL := RetrieveSAtt( Console_History , NumSAtts( Console_History ) - NumLines + 1 );
	if SL = Nil then begin
		SL := Console_History;
		LineNum := NumSAtts( Console_History );
	end;

	while LineNum > 0 do begin
		{ Set the coords for this line. }
		MyDest.X := ZONE_Dialog.X;
		MyDest.Y := ZONE_Dialog.Y + ZONE_Dialog.H - LineNum * TTF_FontLineSkip( game_font );

		{ Output the line. }
		QuickText( SL^.Info , MyDest , TextColor , Game_font );

		Dec( LineNum );
		SL := SL^.Next;
	end;

	{ Restore the clip zone to the full screen. }
	SDL_SetClipRect( Game_Screen , Nil );
end;

Procedure DialogMSG( msg: string );
	{ Print a message in the scrolling dialog box, }
	{ then store the line in Console_History. }
	{ Don't worry about screen output since the console will be redrawn the next time }
	{ the screen updates. }
var
	NextWord: String;
	THELine: String;	{The line under construction.}
	SA: SAttPtr;
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	if msg = '' then Exit;
	msg := '> ' + Msg;

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );
	NextWord := '';

	{Start the main processing loop.}
	while TheLine <> '' do begin
		GetNextLine( TheLine , msg , NextWord , ZONE_Dialog.w );

		{ If appropriate, save the line. }
		if TheLine <> '' then begin
			if NumSAtts( Console_History ) >= Console_History_Length then begin
				SA := Console_History;
				RemoveSAtt( Console_History , SA );
			end;
			StoreSAtt( Console_History , TheLine );
		end;


		{ Prepare for the next iteration. }
		TheLine := NextWord;
	end; { while TheLine <> '' }
end;

Procedure MapBox( Dest: TSDL_Rect );
	{ Do a box for the minimap display. }
var
	X0,Y0,W32,H32,X,Y: Integer;
	MyDest: TSDL_Rect;
begin
	{ Step one: Determine the size of our box. Both dimensions should be }
	{ a multiple of 32. }
	{ W32 and H32 will store the number of 32-pixel columns/rows. }
	W32 := ( Dest.W + 16 ) div 32 + 1;
	H32 := ( Dest.H + 16 ) div 32 + 1;

	{ X0 and Y0 will store the upper left corner of the box. }
	X0 := Dest.X - ( ( ( w32 * 32 ) - Dest.W ) div 2 );
	Y0 := Dest.Y - ( ( ( h32 * 32 ) - Dest.H ) div 2 );

	{ Draw the backdrop. }
	MyDest.X := X0;
	MyDest.Y := Y0;
	MyDest.W := W32 * 32;
	MyDest.H := H32 * 32;
	SDL_FillRect( game_screen , @MyDest , SDL_MapRGB( Game_Screen^.Format , Parchment.R , Parchment.G , Parchment.B ) );

	{ Draw the border. }
	Dest.X := X0 - 8;
	Dest.Y := Y0 - 8;
	DrawSprite( Mapbox_Border , Dest , 0 );

	Dest.X := X0 - 8;
	Dest.Y := Y0 - 8 + H32 * 32;
	DrawSprite( Mapbox_Border , Dest , 2 );

	Dest.X := X0 - 8 + W32 * 32;
	Dest.Y := Y0 - 8;
	DrawSprite( Mapbox_Border , Dest , 1 );

	Dest.X := X0 - 8 + W32 * 32;
	Dest.Y := Y0 - 8 + H32 * 32;
	DrawSprite( Mapbox_Border , Dest , 3 );

	for X := 1 to ( W32 * 2 - 1 ) do begin
		Dest.X := X0 + X * 16 - 8;
		Dest.Y := Y0 - 8;
		DrawSprite( Mapbox_Border , Dest , 4 );
		Dest.Y := Y0 - 8 + H32 * 32;
		DrawSprite( Mapbox_Border , Dest , 6 );
	end;
	for Y := 1 to ( H32 * 2 - 1 ) do begin
		Dest.Y := Y0 + Y * 16 - 8;
		Dest.X := X0 - 8;
		DrawSprite( Mapbox_Border , Dest , 7 );
		Dest.X := X0 - 8 + W32 * 32;
		DrawSprite( Mapbox_Border , Dest , 5 );
	end;
end;

Procedure InfoBox( Dest: TSDL_Rect );
	{ Do a box for drawing something else inside of. }
const
	tex_width = 16;
	border_width = tex_width div 2;
	half_dat = border_width div 2;
var
	X0,Y0,W32,H32,X,Y: Integer;
begin
	{ Step one: Determine the size of our box. Both dimensions should be }
	{ a multiple of 32. }
	{ W32 and H32 will store the number of 16-pixel columns/rows. }
	W32 := ( Dest.W + border_width ) div tex_width + 1;
	H32 := ( Dest.H + border_width ) div tex_width + 1;

	{ X0 and Y0 will store the upper left corner of the box. }
	X0 := Dest.X - ( ( ( w32 * tex_width ) - Dest.W ) div 2 );
	Y0 := Dest.Y - ( ( ( h32 * tex_width ) - Dest.H ) div 2 );

	{ Draw the backdrop. }
	for X := 0 to ( W32 - 1 ) do begin
		Dest.X := X0 + X * tex_width;
		for Y := 0 to ( H32 - 1 ) do begin
			Dest.Y := Y0 + Y * tex_width;
			DrawSprite( Infobox_Backdrop , Dest , 0 );
		end;
	end;

	{ Draw the border. }
	Dest.X := X0 - half_dat;
	Dest.Y := Y0 - half_dat;
	DrawSprite( Infobox_Border , Dest , 0 );

	Dest.X := X0 - half_dat;
	Dest.Y := Y0 + H32 * tex_width - half_dat;
	DrawSprite( Infobox_Border , Dest , 4 );

	Dest.X := X0 + W32 * tex_width - half_dat;
	Dest.Y := Y0 - half_dat;
	DrawSprite( Infobox_Border , Dest , 3 );

	Dest.X := X0 + W32 * tex_width - half_dat;
	Dest.Y := Y0 + H32 * tex_width - half_dat;
	DrawSprite( Infobox_Border , Dest , 5 );

	for X := 1 to ( W32 * 2 - 1 ) do begin
		Dest.X := X0 + X * border_width - half_dat;
		Dest.Y := Y0 - half_dat;
		DrawSprite( Infobox_Border , Dest , 1 );
		Dest.Y := Y0 + H32 * tex_width - half_dat;
		DrawSprite( Infobox_Border , Dest , 1 );
	end;
	for Y := 1 to ( H32 * 2 - 1 ) do begin
		Dest.Y := Y0 + Y * border_width - half_dat;
		Dest.X := X0 - half_dat;
		DrawSprite( Infobox_Border , Dest , 2 );
		Dest.X := X0 + W32 * tex_width - half_dat;
		DrawSprite( Infobox_Border , Dest , 2 );
	end;
end;

Procedure GotoNextLine( var Z: TSDL_Rect );
	{ We're printing a list of information. Go to the next line. }
begin
	Z.Y := Z.Y + TTF_FontLineSkip( game_font );
end;


Procedure ClearExtendedBorder( Dest: TSDL_Rect );
	{ Draw the inner box for border displays. }
begin
	Dest.X := Dest.X - 1;
	Dest.Y := Dest.Y - 1;
	Dest.W := Dest.W + 2;
	Dest.H := Dest.H + 2;
	SDL_FillRect( game_screen , @Dest , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
end;

Procedure DrawBPBorder;
	{ Draw borders for the backpack display. }
begin
	ClearExtendedBorder( ZONE_ItemsTotal );
	SDL_FillRect( game_screen , @ZONE_ItemsTotal , SDL_MapRGB( Game_Screen^.Format , PlayerBlue.R , PlayerBlue.G , PlayerBlue.B ) );
	ClearExtendedBorder( ZONE_BackpackInstructions );
	ClearExtendedBorder( ZONE_InvMenu );
	ClearExtendedBorder( ZONE_EqpMenu );
	ClearExtendedBorder( ZONE_ItemsInfo );
	ClearExtendedBorder( ZONE_ItemsPCInfo );
end;

Procedure DrawGetItemBorder;
	{ Draw borders for the get item display. }
begin
	ClearExtendedBorder( ZONE_SuperGetItem );
	SDL_FillRect( game_screen , @ZONE_SuperGetItem , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );
	InfoBox( ZONE_GetItemMenu );
end;


Procedure SetupInteractDisplay( TeamColor: TSDL_Color );
	{ Draw the display for the interaction interface. }
begin
	ClearExtendedBorder( ZONE_InteractTotal );
	SDL_FillRect( game_screen , @ZONE_InteractTotal , SDL_MapRGB( Game_Screen^.Format , TeamColor.R , TeamColor.G , TeamColor.B ) );
	ClearExtendedBorder( ZONE_InteractStatus );
	ClearExtendedBorder( ZONE_InteractMsg );
	ClearExtendedBorder( ZONE_InteractMenu );
	ClearExtendedBorder( ZONE_InteractPhoto );
	ClearExtendedBorder( ZONE_InteractInfo );
end;

Procedure SetupServicesDisplay;
	{ Draw the display for the services interface. }
begin
	ClearExtendedBorder( ZONE_ItemsTotal );
	SDL_FillRect( game_screen , @ZONE_ItemsTotal , SDL_MapRGB( Game_Screen^.Format , PlayerBlue.R , PlayerBlue.G , PlayerBlue.B ) );
	ClearExtendedBorder( ZONE_ShopCaption );
	ClearExtendedBorder( ZONE_ShopMsg );
	ClearExtendedBorder( ZONE_ShopMenu );
	ClearExtendedBorder( ZONE_ItemsInfo );
	ClearExtendedBorder( ZONE_ItemsPCInfo );
end;

Procedure SetupFHQDisplay;
	{ Draw the display for the services interface. }
begin
	ClearExtendedBorder( ZONE_ItemsTotal );
	SDL_FillRect( game_screen , @ZONE_ItemsTotal , SDL_MapRGB( Game_Screen^.Format , PlayerBlue.R , PlayerBlue.G , PlayerBlue.B ) );
	ClearExtendedBorder( ZONE_FieldHQMenu );
	ClearExtendedBorder( ZONE_ItemsInfo );
	ClearExtendedBorder( ZONE_ItemsPCInfo );
end;

Procedure SetupMemoDisplay;
	{ Set up the memo display. }
begin
	InfoBox( ZONE_MemoTotal );
	ClearExtendedBorder( ZONE_MemoText );
	ClearExtendedBorder( ZONE_MemoMenu );
end;

Procedure DrawMonologueBorder;
	{ Draw the border for the monologue. }
begin
	ClearExtendedBorder( ZONE_MonologueTotal );
	SDL_FillRect( game_screen , @ZONE_MonologueTotal , SDL_MapRGB( Game_Screen^.Format , PlayerBlue.R , PlayerBlue.G , PlayerBlue.B ) );
	ClearExtendedBorder( ZONE_MonologueInfo );
	ClearExtendedBorder( ZONE_MonologueText );
	ClearExtendedBorder( ZONE_MonologuePortrait );
end;

Procedure Idle_Display;
	{ Something is happening that's likely to take a long time. Load an idle }
	{ image from disk and show it to the user. }
var
	FList: SAttPtr;
	PFName: PChar;
	MyImage: PSDL_Surface;
	MyDest: TSDL_Rect;
begin
	{ Create a list of all the images in the idle_pics drawer. }
	FList := CreateFileList( Graphics_Directory + 'poster_*.*' );
	if FList <> Nil then begin
		{ Load one at random, and display it. }
		PFName := QuickPCopy( Graphics_Directory + SelectRandomSAtt( FList )^.Info );
		MyImage := IMG_Load( PFName );
		MyDest.X := (ScreenWidth div 2)-(MyImage^.W div 2);
		MyDest.Y := (ScreenHeight div 2)-(MyImage^.H div 2);
		SDL_FillRect( Game_Screen , Nil , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
		SDL_BlitSurface( MyImage , Nil , Game_Screen , @MyDest );
		DoFlip;
		SDL_FreeSurface( MyImage );
		Dispose( PFName );
		DisposeSAtt( FList );
	end;
end;

Procedure SetupArenaDisplay;
	{ Draw the borders for all the arena-mode menus. }
begin
	SDL_FillRect( game_screen , Nil , SDL_MapRGBA( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B , 255 ) );
	InfoBox( ZONE_ArenaInfo );
	InfoBox( ZONE_ArenaPilotMenu );
	InfoBox( ZONE_ArenaMechaMenu );
	InfoBox( ZONE_PCStatus );
	RedrawConsole;
end;

Procedure SetupArenaMissionMenu;
	{ Set up the menu from which the mission will be selected in arena mode. }
begin
	InfoBox( ZONE_MemoTotal );
	ClearExtendedBorder( ZONE_SAMText );
	ClearExtendedBorder( ZONE_SAMMenu );
end;

Procedure SetupConcertDisplay;
	{ Set up the concert display. }
begin
	InfoBox( ZONE_ConcertTotal );
	ClearExtendedBorder( ZONE_ConcertAudience );
	ClearExtendedBorder( ZONE_ConcertCaption );
	ClearExtendedBorder( ZONE_ConcertMenu );
	ClearExtendedBorder( ZONE_ConcertDesc );
	ClearExtendedBorder( ZONE_ConcertPhoto );
end;

Procedure SetupTitleScreenDisplay;
	{ Draw the title screen. }
var
	MyDest: TSDL_Rect;
begin
	MyDest.X := (ScreenWidth div 2)-(Title_Screen^.Img^.W div 2);
	MyDest.Y := (ScreenHeight div 2)-(Title_Screen^.Img^.H div 2);
	SDL_FillRect( Game_Screen , Nil , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
	SDL_BlitSurface( Title_Screen^.Img , Nil , Game_Screen , @MyDest );

end;



initialization

	SDL_Init( SDL_INIT_VIDEO );

	if DoFullScreen then begin
		Game_Screen := SDL_SetVideoMode(0, 0, 32, SDL_RESIZABLE or SDL_DOUBLEBUF or SDL_FULLSCREEN );
	end else begin
		Game_Screen := SDL_SetVideoMode(800, 600, 32, SDL_RESIZABLE or SDL_DOUBLEBUF );
	end;
	SetZones(Game_Screen^.w,Game_Screen^.h);

	if Ersatz_Mouse then SDL_ShowCursor( SDL_Disable );

	ClrScreen;
	SDL_SetColorKey( Game_Screen , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 255 ) );

        SDL_EnableUNICODE( 1 );
	SDL_EnableKeyRepeat( KEY_REPEAT_DELAY , KEY_REPEAT_INTERVAL );

	TTF_Init;

	Game_Font := TTF_OpenFont( Graphics_Directory + 'VeraBd.ttf' , FontSize );
	Small_Font := TTF_OpenFont( Graphics_Directory + 'VeraBd.ttf' , SmallFontSize );

	Game_Sprites := Nil;

	Cursor_Sprite := LocateSprite( 'sys_cursor.png' , 8 , 16 );
	Title_Screen := LocateSprite( 'sys_arenatitle.png' , 800 , 600 );
	Ersatz_Mouse_Sprite := LocateSprite( 'sys_mouse.png' , 16 , 16 );
	Infobox_Border := LocateSprite( 'sys_knotwork.png' , 8 , 8 );
	Infobox_Backdrop := LocateSprite( 'sys_bgtexture.png' , 16 , 16 );
	Mapbox_Border := LocateSprite( 'sys_mapborder.png' , 16 , 16 );


	Console_History := Nil;

	Last_Clock_Update := 0;

	New_Sprite_Num := 0;

	SDL_WM_SetCaption( WindowName , IconName );


finalization

	DisposeSAtt( Console_History );
	DisposeSpriteList( Game_Sprites );
	TTF_CloseFont( Game_Font );
	TTF_CloseFont( Small_Font );
	TTF_Quit;

	SDL_FreeSurface( Game_Screen );
	SDL_Quit;
end.
