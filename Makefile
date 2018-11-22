.PHONY: put putall

put:
	rsync -vrt --delete --exclude=.git . /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZDailyWrits

get:
	cp -f /Volumes/Elder\ Scrolls\ Online/live/SavedVariables/ZZDailyWrits.lua data/

