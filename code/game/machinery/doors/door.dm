/obj/machinery/door
	name = "door"
	desc = "It opens and closes."
	icon = 'icons/obj/doors/Doorint.dmi'
	icon_state = "door1"
	opacity = 1
	density = TRUE
	move_resist = MOVE_FORCE_VERY_STRONG
	layer = OPEN_DOOR_LAYER
	power_channel = AREA_USAGE_ENVIRON
	max_integrity = 350
	armor = list(MELEE = 30, BULLET = 30, LASER = 20, ENERGY = 20, BOMB = 10, BIO = 100, RAD = 100, FIRE = 80, ACID = 70)
	CanAtmosPass = ATMOS_PASS_DENSITY
	flags_1 = PREVENT_CLICK_UNDER_1
	damage_deflection = 10

	interaction_flags_atom = INTERACT_ATOM_UI_INTERACT

	/// TRUE means density will be set as soon as the door begins to close
	var/air_tight = FALSE
	/// How long is this door electrified for
	var/secondsElectrified = MACHINE_NOT_ELECTRIFIED
	/// Logs for EMPs, Electrifications or Hostile Lockdowns
	var/shockedby
	/// Can you see through it without glass
	var/visible = TRUE
	/// Is it currently opening/closing
	var/operating = FALSE
	/// Can you see through it
	var/glass = FALSE
	/// Is it welded shut
	var/welded = FALSE
	/// Does it close at a normal speed
	var/normalspeed = TRUE
	/// Does it block superconduction
	var/heat_proof = FALSE
	/// Is it on emergency access mode
	var/emergency = FALSE
	/// Is it's meant to go under another door.
	var/sub_door = FALSE
	/// Layer the door closes on
	var/closingLayer = CLOSED_DOOR_LAYER
	/// Does it automatically close after some time
	var/autoclose = FALSE
	/// Whether the door detects things and mobs in its way and reopen or crushes them.
	var/safe = TRUE
	/// Is the door bolted?
	var/locked = FALSE
	/// The type of door frame to drop during deconstruction
	var/assemblytype
	var/datum/effect_system/spark_spread/spark_system
	var/real_explosion_block	//ignore this, just use explosion_block
	/// Will the door unlock on red alert
	var/red_alert_access = FALSE //if TRUE, this door will always open on red alert
	var/poddoor = FALSE
	/// Unrestricted sides. A bitflag for which direction (if any) can open the door with no access
	var/unres_sides = 0

/obj/machinery/door/examine(mob/user)
	. = ..()
	if(red_alert_access)
		if(GLOB.security_level >= SEC_LEVEL_RED)
			. += span_notice("Due to a security threat, its access requirements have been lifted!")
		else
			. += span_notice("In the event of a red alert, its access requirements will automatically lift.")
	if(!poddoor)
		. += span_notice("Its maintenance panel is <b>screwed</b> in place.")
	if(!isdead(user))
		var/userDir = turn(get_dir(src, user), 180)
		var/turf/T = get_step(src, userDir)
		var/areaName = T.loc.name
		. += span_notice("It leads into [areaName].")

/obj/machinery/door/check_access_list(list/access_list)
	if(red_alert_access && GLOB.security_level >= SEC_LEVEL_RED)
		return TRUE
	return ..()

/obj/machinery/door/Initialize()
	. = ..()
	set_init_door_layer()
	update_freelook_sight()
	air_update_turf()
	GLOB.airlocks += src
	spark_system = new /datum/effect_system/spark_spread
	spark_system.set_up(2, 1, src)

	//doors only block while dense though so we have to use the proc
	real_explosion_block = explosion_block
	explosion_block = EXPLOSION_BLOCK_PROC

/obj/machinery/door/proc/set_init_door_layer()
	if(density)
		layer = closingLayer
	else
		layer = initial(layer)

/obj/machinery/door/Destroy()
	update_freelook_sight()
	GLOB.airlocks -= src
	if(spark_system)
		qdel(spark_system)
		spark_system = null
	return ..()

/obj/machinery/door/Bumped(atom/movable/AM)
	if(operating || (obj_flags & EMAGGED))
		return
	if(ismob(AM))
		var/mob/B = AM
		if((isdrone(B) || iscyborg(B)) && B.stat)
			return
		if(isliving(AM))
			var/mob/living/M = AM
			if(world.time - M.last_bumped <= 10)
				return	//Can bump-open one airlock per second. This is to prevent shock spam.
			M.last_bumped = world.time
			if(M.restrained() && !check_access(null))
				return
			bumpopen(M)
			return

	if(ismecha(AM))
		var/obj/mecha/mecha = AM
		if(density)
			if(mecha.occupant)
				if(world.time - mecha.occupant.last_bumped <= 10)
					return
				mecha.occupant.last_bumped = world.time
			if(mecha.occupant && (src.allowed(mecha.occupant) || src.check_access_list(mecha.operation_req_access)))
				open()
			else
				do_animate("deny")
		return

	if(isitem(AM))
		var/obj/item/I = AM
		if(!density || (I.w_class < WEIGHT_CLASS_NORMAL && !LAZYLEN(I.GetAccess())))
			return
		if(check_access(I))
			open()
		else
			do_animate("deny")
		return

/obj/machinery/door/Move()
	var/turf/T = loc
	. = ..()
	move_update_air(T)

/obj/machinery/door/CanAllowThrough(atom/movable/mover, turf/target)
	. = ..()
	if(istype(mover)) //yogs start
		if(mover.pass_flags & PASSGLASS)
			return !opacity
		if(mover.pass_flags & PASSDOOR)
			return TRUE //yogs end

/obj/machinery/door/proc/bumpopen(mob/user)
	if(operating)
		return
	src.add_fingerprint(user)
	if(!src.requiresID())
		user = null

	if(density && !(obj_flags & EMAGGED))
		if(allowed(user))
			open()
		else
			do_animate("deny")
	return

/obj/machinery/door/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	return try_to_activate_door(user)

/obj/machinery/door/attack_tk(mob/user)
	if(requiresID() && !allowed(null))
		return
	..()

/obj/machinery/door/proc/try_to_activate_door(mob/user)
	add_fingerprint(user)
	if(operating || (obj_flags & EMAGGED))
		return
	if(!requiresID())
		user = null //so allowed(user) always succeeds
	if(allowed(user))
		if(density)
			open()
		else
			close()
		return TRUE
	if(density)
		do_animate("deny")

/obj/machinery/door/allowed(mob/M)
	if(emergency)
		return TRUE
	if(unrestricted_side(M))
		return TRUE
	return ..()

/obj/machinery/door/proc/unrestricted_side(mob/M) //Allows for specific side of airlocks to be unrestrected (IE, can exit maint freely, but need access to enter)
	return get_dir(src, M) & unres_sides

/obj/machinery/door/proc/try_to_weld(obj/item/weldingtool/W, mob/user)
	return

/obj/machinery/door/proc/try_to_crowbar(obj/item/I, mob/user)
	return

/obj/machinery/door/proc/is_holding_pressure()
	var/turf/open/T = loc
	if(!T)
		return FALSE
	if(!density)
		return FALSE
	// alrighty now we check for how much pressure we're holding back
	var/min_moles = T.air.total_moles()
	var/max_moles = min_moles
	// okay this is a bit hacky. First, we set density to 0 and recalculate our adjacent turfs
	density = FALSE
	T.ImmediateCalculateAdjacentTurfs()
	// then we use those adjacent turfs to figure out what the difference between the lowest and highest pressures we'd be holding is
	for(var/turf/open/T2 in T.atmos_adjacent_turfs)
		if((flags_1 & ON_BORDER_1) && get_dir(src, T2) != dir)
			continue
		var/moles = T2.air.total_moles()
		if(moles < min_moles)
			min_moles = moles
		if(moles > max_moles)
			max_moles = moles
	density = TRUE
	T.ImmediateCalculateAdjacentTurfs() // alright lets put it back
	return max_moles - min_moles > 20

/obj/machinery/door/attackby(obj/item/I, mob/user, params)
	add_fingerprint(user)

	if(user.a_intent != INTENT_HARM && (I.tool_behaviour == TOOL_CROWBAR || istype(I, /obj/item/twohanded/fireaxe)))
		try_to_crowbar(I, user)
		return 1
	else if(istype(I, /obj/item/zombie_hand/gamemode))
		try_to_crowbar(I, user)
		return TRUE
	else if(I.tool_behaviour == TOOL_WELDER)
		try_to_weld(I, user)
		return 1
	else if(!(I.item_flags & NOBLUDGEON) && user.a_intent != INTENT_HARM)
		try_to_activate_door(user)
		return 1
	return ..()

/obj/machinery/door/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = 1, attack_dir)
	. = ..()
	if(. && obj_integrity > 0)
		if(damage_amount >= 10 && prob(30))
			spark_system.start()

/obj/machinery/door/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			if(glass)
				playsound(loc, 'sound/effects/glasshit.ogg', 90, 1)
			else if(damage_amount)
				playsound(loc, 'sound/weapons/smash.ogg', 50, 1)
			else
				playsound(src, 'sound/weapons/tap.ogg', 50, 1)
		if(BURN)
			playsound(src.loc, 'sound/items/welder.ogg', 100, 1)

/obj/machinery/door/emp_act(severity)
	. = ..()
	if (. & EMP_PROTECT_SELF)
		return
	if(prob(20/severity) && (istype(src, /obj/machinery/door/airlock) || istype(src, /obj/machinery/door/window)) )
		INVOKE_ASYNC(src, .proc/open)
	if(prob(severity*10 - 20))
		if(secondsElectrified == MACHINE_NOT_ELECTRIFIED)
			secondsElectrified = MACHINE_ELECTRIFIED_PERMANENT
			LAZYADD(shockedby, "\[[time_stamp()]\]EM Pulse")
			addtimer(CALLBACK(src, .proc/unelectrify), 300)

/obj/machinery/door/proc/unelectrify()
	secondsElectrified = MACHINE_NOT_ELECTRIFIED

/obj/machinery/door/update_icon()
	if(density)
		icon_state = "door1"
	else
		icon_state = "door0"

/obj/machinery/door/proc/do_animate(animation)
	switch(animation)
		if("opening")
			if(panel_open)
				flick("o_doorc0", src)
			else
				flick("doorc0", src)
		if("closing")
			if(panel_open)
				flick("o_doorc1", src)
			else
				flick("doorc1", src)
		if("deny")
			if(!stat)
				flick("door_deny", src)


/obj/machinery/door/proc/open()
	if(!density)
		return TRUE
	if(operating)
		return
	operating = TRUE
	do_animate("opening")
	set_opacity(0)
	sleep(0.5 SECONDS)
	density = FALSE
	sleep(0.5 SECONDS)
	layer = initial(layer)
	update_icon()
	set_opacity(0)
	operating = FALSE
	air_update_turf()
	update_freelook_sight()
	if(autoclose)
		spawn(autoclose)
			close()
	return TRUE

/obj/machinery/door/proc/close()
	if(density)
		return TRUE
	if(operating || welded)
		return
	if(safe)
		for(var/atom/movable/M in get_turf(src))
			if(M.density && M != src) //something is blocking the door
				if(autoclose)
					autoclose_in(60)
				return

	operating = TRUE

	do_animate("closing")
	layer = closingLayer
	if(air_tight)
		density = TRUE
	sleep(0.5 SECONDS)
	density = TRUE
	sleep(0.5 SECONDS)
	update_icon()
	if(visible && !glass)
		set_opacity(1)
	operating = FALSE
	air_update_turf()
	update_freelook_sight()
	if(safe)
		CheckForMobs()
	else if(!(flags_1 & ON_BORDER_1))
		crush()
	return TRUE

/obj/machinery/door/proc/CheckForMobs()
	if(locate(/mob/living) in get_turf(src))
		sleep(0.1 SECONDS)
		open()

/obj/machinery/door/proc/crush()
	for(var/mob/living/L in get_turf(src))
		L.visible_message(span_warning("[src] closes on [L], crushing [L.p_them()]!"), span_userdanger("[src] closes on you and crushes you!"))
		if(iscarbon(L))
			var/mob/living/carbon/C = L
			for(var/i in C.all_wounds) // should probably replace with signal
				var/datum/wound/W = i
				W.crush(DOOR_CRUSH_DAMAGE)
		if(isalien(L))  //For xenos
			L.adjustBruteLoss(DOOR_CRUSH_DAMAGE * 1.5) //Xenos go into crit after aproximately the same amount of crushes as humans.
			L.emote("roar")
		else if(ishuman(L)) //For humans
			L.adjustBruteLoss(DOOR_CRUSH_DAMAGE)
			L.emote("scream")
			L.Paralyze(100)
		else if(ismonkey(L)) //For monkeys
			L.adjustBruteLoss(DOOR_CRUSH_DAMAGE)
			L.Paralyze(100)
		else //for simple_animals & borgs
			L.adjustBruteLoss(DOOR_CRUSH_DAMAGE)
		var/turf/location = get_turf(src)
		//add_blood doesn't work for borgs/xenos, but add_blood_floor does.
		L.add_splatter_floor(location)
	for(var/obj/mecha/M in get_turf(src))
		M.take_damage(DOOR_CRUSH_DAMAGE)

/obj/machinery/door/proc/autoclose()
	if(!QDELETED(src) && !density && !operating && !locked && !welded && autoclose)
		close()

/obj/machinery/door/proc/autoclose_in(wait)
	addtimer(CALLBACK(src, .proc/autoclose), wait, TIMER_UNIQUE | TIMER_NO_HASH_WAIT | TIMER_OVERRIDE)

/obj/machinery/door/proc/requiresID()
	return TRUE

/obj/machinery/door/proc/hasPower()
	return !(stat & NOPOWER)

/obj/machinery/door/proc/update_freelook_sight()
	if(!glass && GLOB.cameranet)
		GLOB.cameranet.updateVisibility(src, 0)

/obj/machinery/door/BlockThermalConductivity() // All non-glass airlocks block heat, this is intended.
	if(heat_proof && density)
		return TRUE
	return FALSE

/obj/machinery/door/morgue
	icon = 'icons/obj/doors/doormorgue.dmi'

/obj/machinery/door/get_dumping_location(obj/item/storage/source,mob/user)
	return null

/obj/machinery/door/proc/lock()
	return

/obj/machinery/door/proc/unlock()
	return

/obj/machinery/door/proc/hostile_lockdown(mob/origin)
	if(!stat) //So that only powered doors are closed.
		close() //Close ALL the doors!

/obj/machinery/door/proc/disable_lockdown()
	if(!stat) //Opens only powered doors.
		open() //Open everything!

/obj/machinery/door/ex_act(severity, target)
	//if it blows up a wall it should blow up a door
	..(severity ? max(1, severity - 1) : 0, target)

/obj/machinery/door/GetExplosionBlock()
	return density ? real_explosion_block : 0
