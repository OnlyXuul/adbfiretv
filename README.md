This is a wrapper for adb to execute "scripted" commands to FireTV.

For a while I was maintining scripts in both Powershell and Linux Bash to execute adb commands on my FireTVs and Fire Sticks. I got sick of maintaining the same script in two different languages, of which I'm not particularly fond of. Both are arguably powerful in their own rights, but the syntax is ugly and very different, especially Linux Bash. I decided to write the scripts into an Odin program so that there is only one language and place to maintain updates. This also serves as a place to store adb commands I've learned and found useful. Additionally, some of the less than trivial commands perform some useful parsing of the data, hence the "scripting" part.

Install Odin See:
https://odin-lang.org/docs/

Compile with Odin:
In the terminal, navigate to the folder where this code is located.
odin build .

For command help type:

Linux:
./adbfiretv -h

Windows:
adbfiretv.exe -h
