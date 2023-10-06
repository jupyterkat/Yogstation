/mob/living/carbon/human/onTransitZ(old_z,new_z)
	.=..()
	if(is_mining_level(new_z) || is_mining_level(old_z))
		update_move_intent_slowdown()
		update_movespeed()

/mob/living/carbon/human/update_move_intent_slowdown()
	var/turf/player_turf = get_turf(src)

	if(!player_turf || ! is_mining_level(player_turf.z)) // If we can't get the turf, assume it's not on mining.
		return ..()

	var/area/player_area = get_area(src)
	if(!player_area.mining_speed)
		return ..()

	var/mod = 0
	if(m_intent == MOVE_INTENT_WALK)
		mod = CONFIG_GET(number/movedelay/walk_delay) / 1.5 // 4
	else
		mod = CONFIG_GET(number/movedelay/run_delay) * 0.75 // 1.5
	add_movespeed_modifier(MOVESPEED_ID_MOB_WALK_RUN_CONFIG_SPEED, TRUE, 100, override = TRUE, multiplicative_slowdown = mod)
