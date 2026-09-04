on run argv
    set previousDefault to item 1 of argv
    set previousStartup to item 2 of argv
    set installedProfile to item 3 of argv

    tell application "Terminal"
        if exists settings set previousDefault then
            set default settings to settings set previousDefault
        else if exists settings set "Basic" then
            set default settings to settings set "Basic"
        end if
        if exists settings set previousStartup then
            set startup settings to settings set previousStartup
        else if exists settings set "Basic" then
            set startup settings to settings set "Basic"
        end if
        if exists settings set installedProfile then
            delete settings set installedProfile
        end if
    end tell
end run
