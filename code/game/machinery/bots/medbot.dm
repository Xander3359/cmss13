//MEDBOT
//MEDBOT PATHFINDING
//MEDBOT ASSEMBLY


/obj/structure/machinery/bot/medbot
	name = "Medibot"
	desc = "A little medical robot. He looks somewhat underwhelmed."
	icon = 'icons/obj/structures/machinery/aibots.dmi'
	icon_state = "medibot0"
	density = FALSE
	anchored = FALSE
	health = 20
	maxhealth = 20
	req_access = list(ACCESS_MARINE_MEDBAY)
	/// It can be stunned by tasers. Delicate circuits.
	var/stunned = 0
	var/list/botcard_access = list(ACCESS_MARINE_MEDBAY)
	/// Can be set to draw from this for reagents.
	var/obj/item/reagent_container/glass/reagent_glass = null
	/// Set to "tox", "ointment" or "o2" for the other two firstaid kits.
	var/skin = null
	var/frustration = 0
	var/path[] = new()
	var/mob/living/carbon/patient = null
	var/mob/living/carbon/oldpatient = null
	var/last_found = 0
	/// Don't spam the "HEY I'M COMING" messages
	var/last_newpatient_speak = 0
	var/currently_healing = 0
	/// Overdose protection toggle, on by default
	var/safety_checks = 1
	/// How much reagent do we inject at a time?
	var/injection_amount = 15
	/// Start healing when they have this much damage in a category
	var/heal_threshold = 10
	/// Use reagents in beaker instead of default treatment agents.
	var/use_beaker = 0
	/// When attempting to treat a patient, should it notify everyone wearing medhuds?
	var/declare_treatment = 0
	/// self explanatory :)
	var/shut_up = 0

	//--Setting which reagents to use to treat what by default. By id.
	var/treatment_brute = "bicaridine"
	var/treatment_oxy = "dexalin"
	var/treatment_fire = "kelotane"
	var/treatment_tox = "anti_toxin"
	var/treatment_virus = "spaceacillin"

/obj/structure/machinery/bot/medbot/mysterious
	name = "Mysterious Medibot"
	desc = "International Medibot of mystery."
	skin = "bezerk"
	treatment_oxy = "dexalinp"
	treatment_brute = "bicaridine"
	treatment_fire = "kelotane"
	treatment_tox = "anti_toxin"

/obj/structure/machinery/bot/medbot/Initialize(mapload, ...)
	. = ..()
	icon_state = "medibot[on]"

	addtimer(CALLBACK(src, PROC_REF(setup_bot)), 0.4 SECONDS)
	start_processing()

/obj/structure/machinery/bot/medbot/proc/setup_bot()
	if(skin)
		overlays += image('icons/obj/structures/machinery/aibots.dmi', "medskin_[skin]")

	botcard = new /obj/item/card/id(src)
	if(!LAZYLEN(botcard_access))
		var/datum/job/J = GLOB.RoleAuthority ? GLOB.RoleAuthority.roles_by_path[/datum/job/civilian/doctor] : new /datum/job/civilian/doctor
		botcard.access = J.get_access()
	else
		botcard.access = botcard_access

/obj/structure/machinery/bot/medbot/Destroy()
	botcard_access = null
	patient = null
	oldpatient = null
	path = null
	return ..()

/obj/structure/machinery/bot/medbot/turn_on()
	. = ..()
	icon_state = "medibot[on]"
	updateUsrDialog()

/obj/structure/machinery/bot/medbot/turn_off()
	..()
	patient = null
	oldpatient = null
	path = new()
	currently_healing = 0
	last_found = world.time
	icon_state = "medibot[on]"
	updateUsrDialog()

/obj/structure/machinery/bot/medbot/attack_hand(mob/user as mob)
	. = ..()
	if(.)
		return
	var/dat
	dat += "<TT><B>Automatic Medical Unit v1.0</B></TT><BR><BR>"
	dat += "Status: <A href='byond://?src=\ref[src];power=1'>[on ? "On" : "Off"]</A><BR>"
	dat += "Maintenance panel is [open ? "opened" : "closed"]<BR>"
	dat += "Beaker: "
	if(reagent_glass)
		dat += "<A href='byond://?src=\ref[src];eject=1'>Loaded \[[reagent_glass.reagents.total_volume]/[reagent_glass.reagents.maximum_volume]\]</a>"
	else
		dat += "None Loaded"
	dat += "<br>Behaviour controls are [locked ? "locked" : "unlocked"]<hr>"
	if(!locked || isRemoteControlling(user))
		dat += "<TT>Healing Threshold: "
		dat += "<a href='byond://?src=\ref[src];adj_threshold=-10'>--</a> "
		dat += "<a href='byond://?src=\ref[src];adj_threshold=-5'>-</a> "
		dat += "[heal_threshold] "
		dat += "<a href='byond://?src=\ref[src];adj_threshold=5'>+</a> "
		dat += "<a href='byond://?src=\ref[src];adj_threshold=10'>++</a>"
		dat += "</TT><br>"

		dat += "<TT>Injection Level: "
		dat += "<a href='byond://?src=\ref[src];adj_inject=-5'>-</a> "
		dat += "[injection_amount] "
		dat += "<a href='byond://?src=\ref[src];adj_inject=5'>+</a> "
		dat += "</TT><br>"

		dat += "<TT>OD Protection: "
		dat += "<b>[safety_checks ? "On" : "Off"]</b> : "
		dat += "<a href='byond://?src=\ref[src];togglesafety=1'>Toggle?</a>"
		dat += "</TT><br>"

		dat += "Reagent Source: "
		dat += "<a href='byond://?src=\ref[src];use_beaker=1'>[use_beaker ? "Loaded Beaker (When available)" : "Internal Synthesizer"]</a><br>"

		dat += "Treatment report is [declare_treatment ? "on" : "off"]. <a href='byond://?src=\ref[src];declaretreatment=[1]'>Toggle</a><br>"

		dat += "The speaker switch is [shut_up ? "off" : "on"]. <a href='byond://?src=\ref[src];togglevoice=[1]'>Toggle</a><br>"

	show_browser(user, dat, "Medibot v1.0 controls", "automed")
	return

/obj/structure/machinery/bot/medbot/Topic(href, href_list)
	if(..())
		return
	usr.set_interaction(src)
	add_fingerprint(usr)
	if((href_list["power"]) && (allowed(usr)))
		if(on)
			turn_off()
		else
			turn_on()

	else if((href_list["adj_threshold"]) && (!locked || isRemoteControlling(usr)))
		var/adjust_num = text2num(href_list["adj_threshold"])
		heal_threshold += adjust_num
		if(heal_threshold < 5)
			heal_threshold = 5
		if(heal_threshold > 75)
			heal_threshold = 75

	else if((href_list["adj_inject"]) && (!locked || isRemoteControlling(usr)))
		var/adjust_num = text2num(href_list["adj_inject"])
		injection_amount += adjust_num
		if(injection_amount < 5)
			injection_amount = 5
		if(injection_amount > 15)
			injection_amount = 15

	else if((href_list["togglesafety"]) && (!locked || isRemoteControlling(usr)))
		safety_checks = !safety_checks

	else if((href_list["use_beaker"]) && (!locked || isRemoteControlling(usr)))
		use_beaker = !use_beaker

	else if(href_list["eject"] && (!QDELETED(reagent_glass)))
		if(!locked)
			reagent_glass.forceMove(get_turf(src))
			reagent_glass = null
		else
			to_chat(usr, SPAN_NOTICE("You cannot eject the beaker because the panel is locked."))

	else if((href_list["togglevoice"]) && (!locked || isRemoteControlling(usr)))
		shut_up = !shut_up

	else if((href_list["declaretreatment"]) && (!locked || isRemoteControlling(usr)))
		declare_treatment = !declare_treatment

	updateUsrDialog()
	return

/obj/structure/machinery/bot/medbot/attackby(obj/item/attacking_object as obj, mob/user as mob)
	if(istype(attacking_object, /obj/item/card/id))
		if(allowed(user))
			locked = !locked
			to_chat(user, SPAN_NOTICE("Controls are now [locked ? "locked." : "unlocked."]"))
			updateUsrDialog()
			return

		if(open)
			to_chat(user, SPAN_WARNING("Please close the access panel before locking it."))
		else
			to_chat(user, SPAN_WARNING("Access denied."))
		return

	if(istype(attacking_object, /obj/item/reagent_container/glass))
		if(locked)
			to_chat(user, SPAN_NOTICE("You cannot insert a beaker because the panel is locked."))
			return
		if(!isnull(reagent_glass))
			to_chat(user, SPAN_NOTICE("There is already a beaker loaded."))
			return

		if(user.drop_inv_item_to_loc(attacking_object, src))
			reagent_glass = attacking_object
			to_chat(user, SPAN_NOTICE("You insert [attacking_object]."))
			updateUsrDialog()
		return

	. = ..()
	if(health < maxhealth && !HAS_TRAIT(attacking_object, TRAIT_TOOL_SCREWDRIVER) && attacking_object.force)
		step_to(src, (get_step_away(src,user)))

/obj/structure/machinery/bot/medbot/process()
	set background = 1

	if(!on)
		stunned = 0
		return

	if(stunned)
		icon_state = "medibota"
		stunned--

		oldpatient = patient
		patient = null
		currently_healing = 0

		if(stunned <= 0)
			icon_state = "medibot[on]"
			stunned = 0
		return

	if(frustration > 8)
		oldpatient = patient
		patient = null
		currently_healing = 0
		last_found = world.time
		path = new()

	if(!patient)
		if(!shut_up && prob(1))
			var/message = pick("Radar, put a mask on!","There's always a catch, and it's the best there is.","I knew it, I should've been a plastic surgeon.","What kind of medbay is this? Everyone's dropping like dead flies.","Delicious!")
			speak(message)

		for (var/mob/living/carbon/target_patient in view(7,src)) //Time to find a patient!
			if((target_patient.stat == DEAD) || !ishuman_strict(target_patient))
				continue

			if((target_patient == oldpatient) && (world.time < last_found + 100))
				continue

			if(assess_patient(target_patient))
				patient = target_patient
				oldpatient = target_patient
				last_found = world.time
				if((last_newpatient_speak + 300) < world.time) //Don't spam these messages!
					var/message = pick("Hey, [target_patient.name]! Hold on, I'm coming.","Wait [target_patient.name]! I want to help!","[target_patient.name], you appear to be injured!")
					speak(message)
					visible_message("<b>[src]</b> points at [target_patient.name]!")
					last_newpatient_speak = world.time
// if(declare_treatment)
// var/area/location = get_area(src)
// broadcast_medical_hud_message("[name] is treating <b>[target_patient]</b> in <b>[location]</b>", src)
				break
			else
				continue


	if(patient && Adjacent(patient))
		if(!currently_healing)
			currently_healing = 1
			frustration = 0
			medicate_patient(patient)
		return

	else if(patient && (length(path)) && (get_dist(patient,path[length(path)]) > 2))
		path = new()
		currently_healing = 0
		last_found = world.time

	if(patient && length(path) == 0 && (get_dist(src,patient) > 1))
		spawn(0)
			path = AStar(loc, get_turf(patient), /turf/proc/CardinalTurfsWithAccess, /turf/proc/Distance, 0, 30,id=botcard)
			if(!path) path = list()
			if(length(path) == 0)
				oldpatient = patient
				patient = null
				currently_healing = 0
				last_found = world.time
		return

	if(length(path) > 0 && patient)
		step_to(src, path[1])
		path -= path[1]
		spawn(3)
			if(length(path))
				step_to(src, path[1])
				path -= path[1]

	if(length(path) > 8 && patient)
		frustration++

	return

/obj/structure/machinery/bot/medbot/proc/assess_patient(mob/living/carbon/target_patient as mob)
	//Time to see ifthey need medical help!
	if(target_patient.stat == DEAD)
		return FALSE //welp too late for them!

	if(safety_checks)
		if(target_patient.reagents.total_volume > 0)
			for(var/datum/reagent/R in target_patient.reagents.reagent_list)
				if((injection_amount + R.volume) >= R.overdose)
					return FALSE //Don't medicate ifit will kill them --MadSnailDisease

	//If they're injured, we're using a beaker, and don't have one of our WONDERCHEMS.
	if((reagent_glass) && (use_beaker) && ((target_patient.getBruteLoss() >= heal_threshold) || (target_patient.getToxLoss() >= heal_threshold) || (target_patient.getToxLoss() >= heal_threshold) || (target_patient.getOxyLoss() >= (heal_threshold + 15))))
		for(var/datum/reagent/R in reagent_glass.reagents.reagent_list)
			if(!target_patient.reagents.has_reagent(R))
				return TRUE
			continue

	//They're injured enough for it!
	if((target_patient.getBruteLoss() >= heal_threshold) && (!target_patient.reagents.has_reagent(treatment_brute)))
		return TRUE //If they're already medicated don't bother!

	if((target_patient.getOxyLoss() >= (15 + heal_threshold)) && (!target_patient.reagents.has_reagent(treatment_oxy)))
		return TRUE

	if((target_patient.getFireLoss() >= heal_threshold) && (!target_patient.reagents.has_reagent(treatment_fire)))
		return TRUE

	if((target_patient.getToxLoss() >= heal_threshold) && (!target_patient.reagents.has_reagent(treatment_tox)))
		return TRUE


	for(var/datum/disease/D in target_patient.viruses)
		if((D.stage > 1) || (D.spread_type == AIRBORNE))

			if(!target_patient.reagents.has_reagent(treatment_virus))
				return TRUE //STOP DISEASE FOREVER

	return FALSE

/obj/structure/machinery/bot/medbot/proc/medicate_patient(mob/living/carbon/target_patient as mob)
	if(!on)
		return

	if(!istype(target_patient))
		oldpatient = patient
		patient = null
		currently_healing = 0
		last_found = world.time
		return

	if(target_patient.stat == DEAD)
		var/death_message = pick("No! NO!","Live, damnit! LIVE!","I...I've never lost a patient before. Not today, I mean.")
		speak(death_message)
		oldpatient = patient
		patient = null
		currently_healing = 0
		last_found = world.time
		return

	var/reagent_id = null

	//Use whatever is inside the loaded beaker. If there is one.
	if(use_beaker && reagent_glass && reagent_glass.reagents.total_volume)
		var/safety_fail = 0
		for(var/datum/reagent/R in reagent_glass.reagents.reagent_list)
			if(!target_patient.reagents.has_reagent(R))
				safety_fail = 1
				break
		if(!safety_fail)
			reagent_id = "internal_beaker"

	var/virus = 0
	for(var/datum/disease/D in target_patient.viruses)
		virus = 1

	if(!reagent_id && (virus))
		if(!target_patient.reagents.has_reagent(treatment_virus))
			reagent_id = treatment_virus

	if(!reagent_id && (target_patient.getBruteLoss() >= heal_threshold))
		if(!target_patient.reagents.has_reagent(treatment_brute))
			reagent_id = treatment_brute

	if(!reagent_id && (target_patient.getOxyLoss() >= (15 + heal_threshold)))
		if(!target_patient.reagents.has_reagent(treatment_oxy))
			reagent_id = treatment_oxy

	if(!reagent_id && (target_patient.getFireLoss() >= heal_threshold))
		if(!target_patient.reagents.has_reagent(treatment_fire))
			reagent_id = treatment_fire

	if(!reagent_id && (target_patient.getToxLoss() >= heal_threshold))
		if(!target_patient.reagents.has_reagent(treatment_tox))
			reagent_id = treatment_tox

	if(!reagent_id) //If they don't need any of that they're probably cured!
		oldpatient = patient
		patient = null
		currently_healing = 0
		last_found = world.time
		var/message = pick("All patched up!","An apple a day keeps me away.","Feel better soon!")
		speak(message)
		return
	else
		icon_state = "medibots"
		visible_message(SPAN_DANGER("<B>[src] is trying to inject [patient]!</B>"))
		spawn(30)
			if((get_dist(src, patient) <= 1) && (on))
				if(!assess_patient(target_patient))
					visible_message(SPAN_DANGER("<B>[src] pulls the syringe away. Safety protocol engaged!</B>"))
				else if(reagent_id == "internal_beaker" && reagent_glass && reagent_glass.reagents.total_volume)
					reagent_glass.reagents.trans_to(patient,injection_amount) //Inject from beaker instead.
					reagent_glass.reagents.reaction(patient, 2)
				else
					patient.reagents.add_reagent(reagent_id,injection_amount)
				visible_message(SPAN_DANGER("<B>[src] injects [patient] with the syringe!</B>"))

			icon_state = "medibot[on]"
			currently_healing = 0
			return

// speak(reagent_id)
	reagent_id = null
	return


/obj/structure/machinery/bot/medbot/proc/speak(message)
	if((!on) || (!message))
		return
	visible_message("[src] beeps, \"[message]\"")
	return

/obj/structure/machinery/bot/medbot/explode()
	on = 0
	visible_message(SPAN_DANGER("<B>[src] blows apart!</B>"), null, null, 1)
	var/turf/Tsec = get_turf(src)

	new /obj/item/storage/firstaid(Tsec)

	new /obj/item/device/assembly/prox_sensor(Tsec)

	new /obj/item/device/healthanalyzer(Tsec)

	if(reagent_glass)
		reagent_glass.forceMove(Tsec)
		reagent_glass = null

	if(prob(50))
		new /obj/item/robot_parts/arm/l_arm(Tsec)

	var/datum/effect_system/spark_spread/s = new /datum/effect_system/spark_spread
	s.set_up(3, 1, src)
	s.start()
	qdel(src)
	return

/obj/structure/machinery/bot/medbot/Collide(atom/A) //Leave no door unopened!
	if((istype(A, /obj/structure/machinery/door)) && (!isnull(botcard)))
		var/obj/structure/machinery/door/D = A
		if(!istype(D, /obj/structure/machinery/door/firedoor) && D.check_access(botcard) && !istype(D,/obj/structure/machinery/door/poddoor))
			D.open()
			frustration = 0
	else if((istype(A, /mob/living/)) && (!anchored))
		forceMove(A.loc)
		frustration = 0
	return


/*
 * Medbot Assembly -- Can be made out of all three medkits.
 */

/obj/item/storage/firstaid/attackby(obj/item/robot_parts/S, mob/user as mob)

	if((!istype(S, /obj/item/robot_parts/arm/l_arm)) && (!istype(S, /obj/item/robot_parts/arm/r_arm)))
		..()
		return

	//Making a medibot!
	if(length(contents) >= 1)
		to_chat(user, SPAN_NOTICE("You need to empty [src] out first."))
		return

	var/obj/item/frame/firstaid_arm_assembly/A = new /obj/item/frame/firstaid_arm_assembly
	if(istype(src,/obj/item/storage/firstaid/fire))
		A.skin = "ointment"
	else if(istype(src,/obj/item/storage/firstaid/toxin))
		A.skin = "tox"
	else if(istype(src,/obj/item/storage/firstaid/o2))
		A.skin = "o2"

	qdel(S)
	user.put_in_hands(A)
	to_chat(user, SPAN_NOTICE("You add the robot arm to the first aid kit."))
	user.temp_drop_inv_item(src)
	qdel(src)
