/datum/mood_event/drunk
	mood_change = 3
	description = "<span class='nicegreen'>Everything just feels better after a drink or two.</span>\n"

/datum/mood_event/quality_nice
	description = "<span class='nicegreen'>That drink wasn't bad at all.</span>\n"
	mood_change = 1
	timeout = 1200

/datum/mood_event/quality_good
	description = "<span class='nicegreen'>That drink was pretty good.</span>\n"
	mood_change = 2
	timeout = 1200

/datum/mood_event/quality_verygood
	description = "<span class='nicegreen'>That drink was great!</span>\n"
	mood_change = 3
	timeout = 1200

/datum/mood_event/quality_fantastic
	description = "<span class='nicegreen'>That drink was amazing!</span>\n"
	mood_change = 4
<<<<<<< HEAD
	timeout = 1200
=======
	timeout = 2 MINUTES

/datum/mood_event/amazingtaste
	description = "<span class='nicegreen'>Amazing taste!</span>\n"
	mood_change = 50
	timeout = 10 MINUTES
>>>>>>> d8078e1452... Adds system for randomized semi-persistent chem reactions. (#44094)
