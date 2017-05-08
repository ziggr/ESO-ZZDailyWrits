.PHONY: put putall

put:
	cp -f ./ZZDailyWrits.lua  /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZDailyWrits/
	cp -f ./ZZDailyWrits.xml  /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZDailyWrits/

putall:
	cp -f ./ZZDailyWrits.lua  /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZDailyWrits/
	cp -f ./ZZDailyWrits.xml  /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZDailyWrits/
	cp -f ./ZZDailyWrits.txt  /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZDailyWrits/
	cp -f ./Bindings.xml      /Volumes/Elder\ Scrolls\ Online/live/AddOns/ZZDailyWrits/

get:
	cp -f /Volumes/Elder\ Scrolls\ Online/live/SavedVariables/ZZDailyWrits.lua data/

