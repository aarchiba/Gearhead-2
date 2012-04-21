-- magazine vending machine --
--[[
This file is included directly by the VENDING-AMMO-1 gear (STC_AmmoVend)

 currently I'm a bit stuck at defining special clips as seperate entities
 although I haven't looked extensively into it.
 
Once that's resolved I'll tidy and elegantify the code here ]]--
 
function P.USE( self )
	gh_InitMenu();
	-- gh_AddMenuItem( "5mm-stub Extended Magazine ($200)" , 1 );
	gh_AddMenuItem( "Don't buy anything." , -1 )
	gh_AddMenuItem( "std. 5mm auto clip ($70)", 1)
	gh_AddMenuItem( "(push dim flickering button)", -2)
	local cost = 0;
	local n = gh_QueryMenu( "This partially-working vending machine sells various ammo clips." );
--[[	if n == 1 then
		cost = 200;
		if gh_CanPayBill( cost ) then
			gh_CreateAndGivePart( "SMG5-extmag" );
		else
			gh_Print( "You can't afford it." );
		end;
	end;  ]]--
	gh_SpendTime(1)
	if n == 1 then
		cost = 70
		if gh_CanPayBill( cost ) then
			--gh_CreateAndGivePartMatching( {NAME="5mm Auto Clip"} )
			--gh_Print( "The machine rattles slightly, then dispenses an ammo clip." )
			gh_Print("The machine rattles slightly. Nothing happens.")
			gh_Print("It took your money!")
			gh_SpendTime(1)  -- where's muh initiative roll, nau?
		else
			gh_Print( "You can't afford it." )
		end
	elseif n == -2 then
		gh_SpendTime(3)
		gh_Print( "Nothing happens. This button must be broken." )
	end
end

function P.CLUE_CODEBREAKING( self )
	gh_Print("It seems that this machine is endowed with arcane intrinsics similar to the Mystery Machine's. You can't hack it from within this universe.")
end

-- this isn't working?
function P.CLUE_REPAIR( self )
	gh_Print("It seems there's nothing you can do. This machine needs repair from outside of this universe.")
end
