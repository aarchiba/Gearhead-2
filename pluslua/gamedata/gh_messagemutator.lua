-- See if a dictionary/replacement procedure can produce good results.

-- s_per_e	Extravert
-- s_per_i	Introvert
-- s_per_g	Grim
-- s_per_c	Cheerful
-- s_per_a	Aggressive
-- s_per_p	Placid

-- s_vir_f	Fellowship (Cardinal Virtue)
-- s_vir_p	Peace (Cardinal Virtue)
-- s_vir_g	Glory (Cardinal Virtue)
-- s_vir_j	Justice (Cardinal Virtue)
-- s_vir_d	Duty (Cardinal Virtue)

-- s_a_???	Attitude
-- s_m_???	Motivation

-- s_[job desig]
-- s_[faction desig]


MM_REQUIRED = 1;
MM_FORBIDDEN = 2;

gh_dict = {
	[ ". say ," ] = {
		{ msg = ". Hey,", condition = { s_per_i = MM_FORBIDDEN } },
		{ msg = ". Um,", condition = { s_a_jr_ = MM_REQUIRED } },
		{ msg = ". Listen up", condition = { s_per_a = MM_REQUIRED } },
		},
	[ "a mission for you" ] = {
		{ msg = "a job for you", condition = { s_per_a = MM_FORBIDDEN, s_per_g = MM_FORBIDDEN } },
		{ msg = "some work for you", condition = { s_corpo = MM_REQUIRED } },
		{ msg = "some work for you", condition = { s_labor = MM_REQUIRED } },
		{ msg = "a business opportunity", condition = { s_thief = MM_REQUIRED } },
		{ msg = "some new orders for you", condition = { s_milit = MM_REQUIRED } },
		{ msg = "an assignment for you", condition = { s_vir_d = MM_REQUIRED } },
		{ msg = "an exclusive contract for you", condition = { s_vir_f = MM_REQUIRED } },
		},
	[ 'a test of' ] = {
		{ msg = 'a trial of' },
		{ msg = 'an experiment of', condition = { s_acade = MM_REQUIRED } },
		{ msg = 'a look at', condition = { s_acade = MM_FORBIDDEN } },
		},
	[ "afraid of" ] = {
		{ msg = "scared of" },
		{ msg = "phobic of", condition = { s_acade = MM_REQUIRED } },
		{ msg = "phobic of", condition = { s_medic = MM_REQUIRED } },
		{ msg = "terrified of", condition = { s_per_g = MM_REQUIRED } },
		{ msg = "spooked by", condition = { s_per_c = MM_REQUIRED } },
		{ msg = "intimidated by", condition = { s_per_e = MM_REQUIRED } },
		{ msg = "nervous about", condition = { s_per_i = MM_REQUIRED } },
		{ msg = "worried about", condition = { s_per_p = MM_REQUIRED } },
		{ msg = "jumpy about", condition = { s_per_a = MM_REQUIRED } },
		},
	[ "ass ." ] = {
		{ msg = 'ass!' , condition = { s_per_i = MM_FORBIDDEN , s_per_g = MM_FORBIDDEN } },
		{ msg = 'ass!' , condition = { s_per_c = MM_REQUIRED } },
		{ msg = 'ass!' , condition = { s_per_e = MM_REQUIRED } },
		},
	[ "battle" ] = {
		{ msg = "fight" , condition = { s_per_p = MM_FORBIDDEN } },
		{ msg = "confrontation", condition = { s_per_p = MM_REQUIRED } },
		{ msg = "rumble", condition = { s_thief = MM_REQUIRED } },
		{ msg = "ruckus", condition = { s_labor = MM_REQUIRED } },
		{ msg = "contest", condition = { s_pdass = MM_REQUIRED } },
		{ msg = "deathmatch", condition = { s_per_a = MM_REQUIRED, s_per_g = MM_REQUIRED } },
		{ msg = "orgy of violence", condition = { s_per_a = MM_REQUIRED, s_per_e = MM_REQUIRED, s_per_c = MM_FORBIDDEN } },
		{ msg = "action", condition = { s_per_a = MM_REQUIRED, s_per_c = MM_REQUIRED } },
		{ msg = "melee", condition = { s_per_i = MM_REQUIRED } },
		{ msg = "scrimmage", condition = { s_thief = MM_REQUIRED, s_per_a = MM_FORBIDDEN } },
		{ msg = "senseless conflict", condition = { s_per_i = MM_REQUIRED, s_per_g = MM_REQUIRED, s_per_a = MM_FORBIDDEN } },
		{ msg = "fray", condition = { s_per_e = MM_REQUIRED, s_per_c = MM_REQUIRED } },
		},
	[ "cavalier" ] = {
		{ msg = "adventurer" , condition = { s_per_g = MM_FORBIDDEN , s_per_i = MM_FORBIDDEN } },
		{ msg = "pilot" , condition = { s_adven = MM_FORBIDDEN } },
		{ msg = "combat pilot" , condition = { s_milit = MM_REQUIRED } },
		{ msg = "fightin' pilot" , condition = { s_labor = MM_REQUIRED } },
		{ msg = "warrior" , condition = { s_per_a = MM_REQUIRED } },
		},
	[ "congratulations ." ] = {
		{ msg = 'congratulations!' , condition = { s_per_i = MM_FORBIDDEN } },
		{ msg = 'congratulations!' , condition = { s_per_c = MM_REQUIRED } },
		},
	[ 'crap' ] = {
		{ msg = 'ashes' },
		{ msg = 'blazes', condition = { s_per_i = MM_FORBIDDEN } },
		{ msg = 'bunnynuts', condition = { s_mugle = MM_REQUIRED } },
		},
	[ 'defeat' ] = {
		{ msg = "get rid of" },
		{ msg = 'neutralize', condition = { s_acade = MM_REQUIRED } },
		{ msg = 'keelhaul', condition = { s_thief = MM_REQUIRED } },
		{ msg = "punish", condition = { s_vir_j = MM_REQUIRED } },
		{ msg = "stop", condition = { s_vir_p = MM_REQUIRED } },
		{ msg = "beat", condition = { s_vir_g = MM_REQUIRED } },
		},
	[ 'destroy' ] = {
		{ msg = 'atomize', condition = { s_acade = MM_REQUIRED } },
		{ msg = 'demolish', condition = { s_labor = MM_REQUIRED } },
		{ msg = 'liquidate', condition = { s_corpo = MM_REQUIRED } },
		{ msg = 'scuttle', condition = { s_crihn = MM_REQUIRED } },
		},
	[ "enjoy your meal" ] = {
		{ msg = "I hope you enjoy the food" },
		},
	[ "fighter" ] = {
		{ msg = 'adventurer', condition = { s_per_g = MM_FORBIDDEN } },
		{ msg = "combatant", condition = { s_per_i = MM_REQUIRED } },
		{ msg = 'hunter', condition = { s_per_p = MM_FORBIDDEN } },
		{ msg = "soldier", condition = { s_milit = MM_REQUIRED } },
		},
	[ "for you ." ] = {
		{ msg = "you won't want to miss ." , condition = { s_per_e = MM_REQUIRED } },
		{ msg = "you may be interested in ." , condition = { s_per_i = MM_REQUIRED } },
		},
	[ "give me a call" ] = {
		{ msg = "call me" },
		{ msg = "get back to me" , condition = { s_per_e = MM_REQUIRED } },
		{ msg = "contact me" , condition = { s_per_i = MM_REQUIRED } },
		{ msg = "call back if you want" , condition = { s_per_g = MM_REQUIRED } },
		},
	[ 'good work' ] = {
		{ msg = 'well done', condition = { s_per_e = MM_FORBIDDEN } },
		{ msg = "congratulations", condition = { s_per_e = MM_REQUIRED } },
		{ msg = "you did it", condition = { s_per_i = MM_REQUIRED } },
		{ msg = "not a bad day's work", condition = { s_per_g = MM_REQUIRED } },
		{ msg = "you did okay", condition = { s_per_g = MM_REQUIRED , s_per_i = MM_REQUIRED } },
		{ msg = "you did great", condition = { s_per_c = MM_REQUIRED } },
		{ msg = "fantastic work", condition = { s_per_c = MM_REQUIRED , s_per_e = MM_REQUIRED } },
		{ msg = "you kicked ass", condition = { s_per_a = MM_REQUIRED , s_per_i = MM_FORBIDDEN } },
		{ msg = "nice going", condition = { s_per_p = MM_REQUIRED } },
		{ msg = "great going", condition = { s_per_p = MM_REQUIRED, s_per_c = MM_REQUIRED } },
		{ msg = "way to go", condition = { s_vir_f = MM_REQUIRED } },
		{ msg = "you did well", condition = { s_vir_p = MM_REQUIRED } },
		{ msg = "you did really well", condition = { s_vir_p = MM_REQUIRED , s_per_c = MM_REQUIRED } },
		{ msg = "victory is yours", condition = { s_vir_g = MM_REQUIRED } },
		{ msg = "you came through", condition = { s_vir_j = MM_REQUIRED } },
		{ msg = "great job", condition = { s_vir_d = MM_REQUIRED } },
		{ msg = "good job", condition = { s_vir_d = MM_REQUIRED , s_per_e = MM_FORBIDDEN } },
		},
	[ 'goodbye' ] = {
		{ msg = 'bye' },
		{ msg = "keep on truckin'", condition = { s_labor = MM_REQUIRED } },
		{ msg = 'good health', condition = { s_medic = MM_REQUIRED } },
		{ msg = "see you around", condition = { s_vir_f = MM_REQUIRED } },
		{ msg = "until next time", condition = { s_vir_d = MM_REQUIRED } },
		{ msg = "take care", condition = { s_vir_p = MM_REQUIRED } },
		},
	[ "great ." ] = {
		{ msg = 'great!' , condition = { s_per_g = MM_FORBIDDEN } },
		},
	[ 'hello' ] = {
		{ msg = "hi" },
		{ msg = 'hi there' },
		{ msg = "greetings", condition = { s_polit = MM_REQUIRED } },
		{ msg = "hey there", condition = { s_vir_f = MM_REQUIRED } },
		},
	[ 'how would you like' ] = {
		{ msg = "how'd you like" },
		},
	[ "i'd like to" ] = {
		{ msg = "I want to" },
		{ msg = "I think I should", condition = { s_vir_j = MM_REQUIRED } },
		{ msg = "it would be wise to", condition = { s_acade = MM_REQUIRED } },
		},
	[ "i'll be back" ] = {
		{ msg = "I'll come back" },
		},
	[ "i'll take a look ." ] = {
		{ msg = "I'll see what you have ." },
		{ msg = "show me what you have ." },
		{ msg = "show me what you've got ." },
		{ msg = "I'd like to take a look ." },
		},
	[ "i'm here to" ] = {
		{ msg = "I'd like to" },
		{ msg = "I'm going to", condition = { s_per_i = MM_FORBIDDEN } },
		},
	[ "i'm not interested ." ] = {
		{ msg = "I don't want to ." },
		},
	[ "i was wondering" ] = {
		{ msg = "I was just wondering" , condition = { s_per_i = MM_REQUIRED } },
		{ msg = "I want to ask" , condition = { s_per_e = MM_REQUIRED } },
		{ msg = "I just want to ask" , condition = { s_per_p = MM_REQUIRED } },
		{ msg = "I just have to ask" , condition = { s_per_p = MM_REQUIRED, s_per_e = MM_REQUIRED } },
		{ msg = "I want to know" , condition = { s_per_a = MM_REQUIRED } },
		{ msg = "I have to know" , condition = { s_per_a = MM_REQUIRED, s_per_e = MM_REQUIRED } },
		{ msg = "I'm going to ask" , condition = { s_per_a = MM_REQUIRED, s_per_i = MM_REQUIRED } },
		{ msg = "I demand to know" , condition = { s_per_a = MM_REQUIRED, s_per_e = MM_REQUIRED, s_per_g = MM_REQUIRED } },
		{ msg = "I'm curious" , condition = { s_per_c = MM_REQUIRED } },
		{ msg = "I need to know" , condition = { s_per_g = MM_REQUIRED } },
		},
	[ "i will" ] = {
		{ msg = "I'm going to" },
		{ msg = "I'm gonna" , condition = { s_per_i = MM_FORBIDDEN, s_acade = MM_FORBIDDEN, s_medic = MM_FORBIDDEN, s_corpo = MM_FORBIDDEN } },
		{ msg = "I vow to" , condition = { s_per_e = MM_REQUIRED , s_per_a = MM_REQUIRED } },
		{ msg = "I'll" , condition = { s_per_c = MM_REQUIRED } },
		{ msg = "I promise to" , condition = { s_polit = MM_REQUIRED } },
		{ msg = "I'm destined to" , condition = { s_faith = MM_REQUIRED } },
		},
	[ 'it looks like you' ] = {
		{ msg = 'I can tell you' },
		},
	[ "later" ] = {
		{ msg = "some other time" },
		{ msg = "in the future" , condition = { s_acade = MM_REQUIRED } }
		},
	[ "let me see what" ] = {
		{ msg = "show me what" },
		},
	[ "mission" ] = {
		{ msg = "job", condition = { s_per_a = MM_FORBIDDEN, s_per_g = MM_FORBIDDEN } },
		{ msg = "operation", condition = { s_milit = MM_REQUIRED } },
		{ msg = "contract", condition = { s_labor = MM_REQUIRED } },
		{ msg = "venture", condition = { s_corpo = MM_REQUIRED } },
		{ msg = "quest", condition = { s_faith = MM_REQUIRED } },
		{ msg = "errand", condition = { s_polit = MM_REQUIRED } },
		{ msg = "case", condition = { s_polic = MM_REQUIRED } },
		{ msg = "caper", condition = { s_thief = MM_REQUIRED } },
		{ msg = "assignment", condition = { s_vir_d = MM_REQUIRED } },
		{ msg = "task", condition = { s_per_i = MM_REQUIRED } },
		},
	[ "practicing" ] = {
		{ msg = "working out", condition = { s_media = MM_REQUIRED } },
		{ msg = "training", condition = { s_per_e = MM_REQUIRED } },
		{ msg = "improving", condition = { s_per_c = MM_REQUIRED } },
		{ msg = "grinding", condition = { s_per_g = MM_REQUIRED } },
		{ msg = "studying", condition = { s_acade = MM_REQUIRED } },
		{ msg = "upgrading", condition = { s_corpo = MM_REQUIRED } },
		},
	[ "show me" ] = {
		{ msg = "let me see" },
		},
	[ 'this is' ] = {
		{ msg = 'this here is', condition = { s_labor = MM_REQUIRED } },
		},
	[ 'that is' ] = {
		{ msg = 'that there is', condition = { s_labor = MM_REQUIRED } },
		},
	[ "training" ] = {
		{ msg = "working out", condition = { s_media = MM_REQUIRED } },
		{ msg = "improving", condition = { s_per_c = MM_REQUIRED } },
		{ msg = "practicing", condition = { s_per_i = MM_REQUIRED } },
		{ msg = "grinding", condition = { s_per_g = MM_REQUIRED } },
		{ msg = "studying", condition = { s_acade = MM_REQUIRED } },
		{ msg = "upgrading", condition = { s_corpo = MM_REQUIRED } },
		},
	[ "warrior" ] = {
		{ msg = 'cavalier' },
		{ msg = 'hunter', condition = { s_adven = MM_REQUIRED } },
		{ msg = "soldier", condition = { s_milit = MM_REQUIRED } },
		{ msg = "martial artist", condition = { s_faith = MM_REQUIRED } },
		{ msg = "duelist", condition = { s_pdass = MM_REQUIRED } },
		},
	[ "way to go ." ] = {
		{ msg = 'way to go!' , condition = { s_per_i = MM_FORBIDDEN } },
		},
	[ "when you're ready" ] = {
		{ msg = "as soon as possible", condition = { s_per_e = MM_REQUIRED } },
		{ msg = "sometime", condition = { s_per_i = MM_REQUIRED } },
		{ msg = "whenever", condition = { s_per_c = MM_REQUIRED } },
		{ msg = "whenever you decide you're ready", condition = { s_per_g = MM_REQUIRED } },
		},
	[ "you can meet me" ] = {
		{ msg = "you should meet me", condition = { s_per_i = MM_REQUIRED } },
		{ msg = "you better meet me", condition = { s_per_g = MM_REQUIRED } },
		{ msg = "you'll find me", condition = { s_per_c = MM_REQUIRED } },
		{ msg = "you get your arse", condition = { s_per_a = MM_REQUIRED } },
		{ msg = "you can find me", condition = { s_per_p = MM_REQUIRED } },
		{ msg = "proceed to", condition = { s_milit = MM_REQUIRED } },
		},
	[ "you did it ." ] = {
		{ msg = 'you did it!' , condition = { s_per_g = MM_FORBIDDEN } },
		},

}

function mm_conditions_match_context( msg_conditions , mm_context )
	-- Return TRUE if all the conditions listed in msg_conditions are met
	-- by the table mm_context.
	if msg_conditions == nil then
		return( true )
	end

	local ismatch = true
	for k,v in pairs( msg_conditions ) do
		if v == MM_REQUIRED then
			ismatch = mm_context[ k ]
		elseif v == MM_FORBIDDEN then
			ismatch = not mm_context[ k ]
		end
		if not ismatch then
			break
		end
	end
	return( ismatch )
end

function mutate_message( in_text , target_length , mm_context )
	-- Given the message in_text, attempt to mutate it.
	-- Go through a few words at a time, searching for matches in the
	-- dictionary, and replacing strings as appropriate.

	-- in_text is the string to mutate
	-- mm_context is a table of context data

	-- Start with a period in the table, since this represents the start of
	-- a new sentence.
	local out_text = { '.' }
	local all_words = {}
	local total_length = string.len( in_text )


	for w,p in string.gfind( in_text , "([%w'%%\\]+)(%p*)" ) do
		table.insert( all_words , w )
		if p ~= '' then table.insert( all_words , p ) end
	end

	for word_index,w in ipairs( all_words ) do
		table.insert( out_text , w )

		-- For the last X words in the table, see if we can find a match.
		for t = 1, 5 do
			if ( table.getn( out_text ) >= t ) then
				local MyKey = string.lower( table.concat( out_text , ' ' , table.getn( out_text ) - t + 1 ) )
				local MyDict = gh_dict[ MyKey ]
				if MyDict ~= nil then
					local list_of_options = {}

					for k,v in pairs( MyDict ) do
						if mm_conditions_match_context( v.condition , mm_context ) then
							table.insert( list_of_options , v )
						end
					end

					if table.getn( list_of_options ) > 0 then
						local MyChoice = math.random( table.getn( list_of_options ) + 1 )
						local MyVal = list_of_options[ MyChoice ]
						if ( MyVal ~= nil ) and ( ( total_length + string.len( MyVal.msg ) - string.len( MyKey ) ) <= target_length ) then
							total_length = total_length + string.len( MyVal.msg ) - string.len( MyKey ) + 1
							for tt = 1,t do
								table.remove( out_text )
							end
							for w2,p2 in string.gfind( MyVal.msg , "([%w'%%\\%.]+)(%p*)" ) do
								table.insert( out_text , w2 )
								if p2 ~= '' then table.insert( out_text , p2 ) end
							end
							break;
						end
					end
				end
			end
		end
	end
	return( table.concat( out_text , ' ' , 2 ) )
end


