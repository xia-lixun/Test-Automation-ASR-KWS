# Build Tools for Windows 7/10


## Build Portaudio
    1. use Visual Studio Community 2017 or versions above
    2. Project file can be found at 20171127_Samsung_LUX\Trunk\Tools\Portaudio\build\msvc\portaudio.sln
    3. portaudio_X64.dll will be copied to 20171127_Samsung_LUX\Trunk\Tools\Test_Automation

## Build soundcard_api
    1. use Visual studio Community 2017 or versions above
    2. Project file can be found at 20171127_Samsung_LUX\Trunk\Tools\Soundcard_API\PaDynamic.sln
    3. soundcard_api.exe will be copied to 20171127_Samsung_LUX\Trunk\Tools\Test_Automation

## Setup the scoring server
    1. copy 20171127_Samsung_LUX\Trunk\Tools\WakeupScoring_Tool_2.2 to the home folder of an Ubuntu 14.04 X64 machine
    2. copy 20171127_Samsung_LUX\Trunk\Tools\WakeupScoring_Tool_2.2\lux-score.sh to /usr/local/bin/ of the Ubuntu machine
    3. On the Ubuntu machine, install ffmpeg, sox and openssh-server by:
        sudo apt install ffmpeg sox openssh-server
    4. On the windows machine, install Git for windows
    5. ssh setup for passwordless login on windows:

            $ ssh-keygen -t rsa -b 2048
            $ ssh-copy-id id@server

        Source: [https://serverfault.com/questions/241588/how-to-automate-ssh-login-with-password]


# Before Measurement

    1. Total reset the Fireface: RME TotalMix FX: Options -> Reset Mix -> Total Reset.