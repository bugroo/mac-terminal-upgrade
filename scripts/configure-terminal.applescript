on run argv
    set profileName to item 1 of argv

    tell application "Terminal"
        if not (exists settings set profileName) then error "Terminal profile not found: " & profileName
        set calmProfile to settings set profileName

        set background color of calmProfile to {4112, 4626, 5911}
        set normal text color of calmProfile to {55255, 56026, 58853}
        set bold text color of calmProfile to {63479, 63736, 64250}
        set cursor color of calmProfile to {36751, 41377, 65535}
        set font name of calmProfile to "JetBrainsMonoNFM-Regular"
        set font size of calmProfile to 16
        set number of rows of calmProfile to 32
        set number of columns of calmProfile to 104
        set title displays device name of calmProfile to false
        set title displays shell path of calmProfile to false
        set title displays window size of calmProfile to false
        set title displays settings name of calmProfile to false
        set title displays custom title of calmProfile to true
        set custom title of calmProfile to "Focus"

        set default settings to calmProfile
        set startup settings to calmProfile
    end tell
end run
