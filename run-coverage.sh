if ! command -v genhtml &> /dev/null
then
    echo "genhtml could not be found"
    echo "on mac OS you can install it with brew install lcov"
    exit
fi

echo "runing forge coverage..."

forge coverage --report lcov >> /dev/null

echo "runing genhtml..."

genhtml lcov.info -o coverage >> /dev/null

IFS='' read -r -d '' String <<"EOF"
                   ()
                 __/\__         
        |\   .-"`      `"-.   /|
        | \.'( ') (' ) (. )`./ |
         \_                  _/
           \  `~"'=::='"~`  /
    ,       `-.__      __.-'       ,
.---'\________( `""~~""` )________/'---.
 >   )       / `""~~~~""` \       (   <
'----`--..__/        -(-)- \__..--`----'
            |_____ __ _____|
            [_____[##]_____]  I HAVE BEEN CHOSEN...
            |              |    FAREWELL MY FRIENDS...
            \      ||      /     I GO ONTO A BETTER PLACE!
       jgs   \     ||     /
          .-"~`--._||_.--'~"-.
         (_____,.--""--.,_____)
EOF

echo "$String"

echo "html coverage report generated at coverage/index.html"

open coverage/index.html
