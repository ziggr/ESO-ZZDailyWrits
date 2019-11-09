.PHONY: get put getpts log

put:
	rsync -vrt --delete --exclude=.git . /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZDailyWrits

get:
	cp -f /Volumes/Elder\ Scrolls\ Online/live/SavedVariables/ZZDailyWrits.lua data/
	-cp -f /Volumes/Elder\ Scrolls\ Online/live/SavedVariables/LibDebugLogger.lua data/

getpts:
	cp -f /Volumes/Elder\ Scrolls\ Online/pts/SavedVariables/ZZDailyWrits.lua data/
	-cp -f /Volumes/Elder\ Scrolls\ Online/pts/SavedVariables/LibDebugLogger.lua data/

log:
	lua tool/log_to_text.lua > data/log.txt
