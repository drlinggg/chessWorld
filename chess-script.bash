#sudo pacman -S jq

key="KEYHERE"
loginParameter="Authorization: Bearer ${key}"
savedlog="game.log"
gameId=""
lastMove=""

title() {
    echo "Hello Chess World!"
    echo
}

# 8x8
chess=('r' 'n' 'b' 'q' 'k' 'b' 'n' 'r' 'p' 'p' 'p' 'p' 'p' 'p' 'p' 'p' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' '_' 'P' 'P' 'P' 'P' 'P' 'P' 'P' 'P' 'R' 'N' 'B' 'Q' 'K' 'B' 'N' 'R')

declare -A letter_map
letter_map=(
    [a]=0
    [b]=1
    [c]=2
    [d]=3
    [e]=4
    [f]=5
    [g]=6
    [h]=7
)

display_board() {
    clear
    title
    for ((i=7; i>=0; i--)); do
        for ((j=0; j<8; j++)); do
            printf "%s " "${chess[$((i * 8 + j))]}"
        done
        echo
    done
}

start_challenge() {
    curl -s -X POST https://lichess.org/api/challenge/ai -H "$loginParameter" -o "$savedlog" -d "level=4&color=white"
    json=$(cat "$savedlog");
    gameId=$(echo "$json" | jq -r '.id')
    echo "$gameId"

    display_board
}

end_challenge() {
    playing=0
    curl -s -X POST https://lichess.org/api/board/game/"${gameId}"/resign -H "$loginParameter" -o "$savedlog" 
}

make_move() {
    read -p "make a move " move

    #resign
    if cmp -s <(echo "$move") <(echo "resign"); then
        end_challenge
    fi

    curl -s -X POST https://lichess.org/api/board/game/"${gameId}"/move/"${move}" -H "$loginParameter" -o "$savedlog"
    
    #save&remove piece
    letIndex=${letter_map[${move:0:1}]}
    index=$(($letIndex+$((${move:1:1}-1))*8))
    figure=${chess[$index]}
    chess[$index]='_'

    letIndex=${letter_map[${move:2:1}]}
    index=$(($letIndex+$((${move:3:1}-1))*8))
    echo "$index"
    chess[$index]="$figure"
    lastMove="${move:2:2}"
    display_board
}

get_move() {
    curl -s -X GET https://lichess.org/game/export/"${gameId}" -o "$savedlog" -d "pgnInJson=true&moves=true"
    lastLine=$(grep ^1. "$savedlog")
    lastLine=$(echo "$lastLine" | grep -o ' ' | wc -l)
    firstCheckedMove=$(grep ^1. "$savedlog" | cut -d ' ' -f "$lastLine")
 
    for((;;)); do

        curl -s -X GET https://lichess.org/game/export/"${gameId}" -o "$savedlog" -d "pgnInJson=true&moves=true"
        lastLine=$(grep ^1. "$savedlog")
        lastLine=$(echo "$lastLine" | grep -o ' ' | wc -l)
        move=$(grep ^1. "$savedlog" | cut -d ' ' -f "$lastLine")

        if [[ "$firstCheckedMove" != "$move" ]]; then
            break
        fi

    done

    #hod peshki default
    if [[ ${move:0:1} =~ [a-z] ]]; then
        if [[ ${move:1:1} != 'x' ]]; then
            letIndex=${letter_map[${move:0:1}]}
            index=$(($letIndex+$((${move:1:1}-1))*8))
            chess[$index]='P'

            for ((i=7; i>=0; i--)); do
                tryIndex=$(($letIndex + i*8))
                if cmp -s <(echo "${chess[$tryIndex]}") <(echo 'P'); then
                    chess[$tryIndex]='_'
                    break
                fi
            done
        else
            letIndex=${letter_map[${move:0:1}]}
            for ((i=7; i >= 0; i--)); do
                tryIndex=$(($letIndex + i*8))
                if cmp -s <(echo "${chess[$tryIndex]}") <(echo 'P'); then
                    chess[$tryIndex]='_'
                    break
                fi
            done
            letIndex=${letter_map[${move:2:1}]}
            index=$(($letIndex+$((${move:3:1}-1))*8))
            chess[$index]='P'
        fi
    fi

    if [[ ${move:0:1} =~ [A-Z] ]]; then
        if [[ ${move:1:1} != 'x' ]]; then
            #set figure at new position
            figure=${move:0:1}
            letIndex=${letter_map[${move:1:1}]}
            index=$(($letIndex+$((${move:2:1}-1))*8))
            chess[$index]=$figure

            #delete figure past position
            
            #Bishop
            found=0
            #fix
            if cmp -s <(echo "$figure") <(echo 'B'); then
                for ((i=-8; i < 8; i++)); do
                    if [[ found -eq 1 ]]; then
                        break
                    fi

                    for ((j=-8; j < 8; j++)); do
                        tryIndex=$(($index + i*8 - j))
                        if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "$figure") <(echo 'B'); then
                            chess[$tryIndex]='_'
                            found=1
                            break
                        fi
                    done
                done
            fi

            #Rook
            if cmp -s <(echo "$figure") <(echo 'R'); then
                for ((i=-8; i < 8; i++)); do
                    tryIndex=$(($index + i*8))
                    if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "$figure") <(echo 'R'); then
                        chess[$tryIndex]='_'
                        found=1
                        break
                    fi
                done

                if [[ found==0 ]]; then
                    for ((i=-8; i < 8; i++)) do
                        tryIndex$(($index + i))
                        if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "$figure") <(echo 'R'); then
                            chess[$tryIndex]='_'
                            break;
                        fi
                    done
                fi
            fi

            #Queen
            if cmp -s <(echo "$figure") <(echo 'Q'); then
                for ((i=0; i < 8; i++)); do
                    for ((j=0; j < 8; j++)); do
                        tryIndex = $((i*8+j))
                        if cmp -s <(echo "${chess[tryIndex]}") <(echo 'Q'); then
                            chess[$tryIndex]='_'
                            break;
                        fi
                    done
                done
            fi

            #Knight
            if cmp -s <(echo "$figure") <(echo 'N'); then
                for ((i = -2; i <= 2; i+=4)); do

                    if [[ found == 1 ]]; then
                        break
                    fi

                    for ((j = -1; j <= 1; j+=2)); do
                        tryIndex=$((index+((8*i))+j))
                        if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "${chess[tryIndex]}") <(echo 'N'); then
                            chess[$tryIndex]='_'
                            found=1
                            break
                        fi

                        tryIndex=$((index+((8*j))+i))
                        if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "${chess[tryIndex]}") <(echo 'N'); then
                            chess[$tryIndex]='_'
                            found=1
                            break
                        fi
                    done
                done
            fi

            #King
            if cmp -s <(echo "$figure") <(echo 'K'); then
                for ((i=0; i < 8; i++)); do
                    for ((j=0; j < 8; j++)); do
                        tryIndex = $((i*8+j))
                        if cmp -s <(echo "${chess[tryIndex]}") <(echo 'K'); then
                            chess[$tryIndex]='_'
                            break;
                        fi
                    done
                done
            fi
        fi

        if [[ ${move:1:1} != 'x' ]]; then 
            #set figure at new position
            figure=${move:0:1}
            letIndex=${letter_map[${move:2:1}]}
            index=$(($letIndex+$((${move:3:1}-1))*8))
            chess[$index]=$figure
            
            #delete figure past position
            
            #Bishop
            found=0

            if cmp -s <(echo "$figure") <(echo 'B'); then
                for ((i=-8; i < 8; i++)); do
                    if [[ found==1 ]]; then
                        break
                    fi

                    for ((j=-8; j < 8; j++)); do
                        tryIndex=$(($index + i*8 - j))
                        if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "$figure") <(echo 'B'); then
                            chess[$tryIndex]='_'
                            found=1
                            break
                        fi
                    done
                done
            fi

            #Rook
            if cmp -s <(echo "$figure") <(echo 'R'); then
                for ((i=-8; i < 8; i++)); do
                    tryIndex=$(($index + i*8))
                    if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "$figure") <(echo 'R'); then
                        chess[$tryIndex]='_'
                        found=1
                        break
                    fi
                done

                if [[ found==0 ]]; then
                    for ((i=-8; i < 8; i++)) do
                        tryIndex$(($index + i))
                        if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "$figure") <(echo 'R'); then
                            chess[$tryIndex]='_'
                            break;
                        fi
                    done
                fi
            fi

            #Queen
            if cmp -s <(echo "$figure") <(echo 'Q'); then
                for ((i=0; i < 8; i++)); do
                    for ((j=0; j < 8; j++)); do
                        tryIndex = $((i*8+j))
                        if cmp -s <(echo "${chess[tryIndex]}") <(echo 'Q'); then
                            chess[$tryIndex]='_'
                            break;
                        fi
                    done
                done
            fi

            #Knight
            if cmp -s <(echo "$figure") <(echo 'N'); then
                for ((i = -2; i <= 2; i+=4)); do

                    if [[ found == 1 ]]; then
                        break
                    fi

                    for ((j = -1; j <= 1; j+=2)); do
                        tryIndex=$((index+((8*i))+j))
                        if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "${chess[tryIndex]}") <(echo 'N'); then
                            chess[$tryIndex]='_'
                            found=1
                            break
                        fi

                        tryIndex=$((index+((8*j))+i))
                        if [[ tryIndex -lt 64 && tryIndex -ge 0 ]] && cmp -s <(echo "${chess[tryIndex]}") <(echo 'N'); then
                            chess[$tryIndex]='_'
                            found=1
                            break
                        fi
                    done
                done
            fi

            #King
            if cmp -s <(echo "$figure") <(echo 'K'); then
                for ((i=0; i < 8; i++)); do
                    for ((j=0; j < 8; j++)); do
                        tryIndex = $((i*8+j))
                        if cmp -s <(echo "${chess[tryIndex]}") <(echo 'K'); then
                            chess[$tryIndex]='_'
                            break;
                        fi
                    done
                done
            fi
        fi
    fi
    
    display_board
    echo "$move"
}

game() {
    playing=1
    start_challenge
    while [ $playing -eq 1 ];
    do
        make_move
        if [[ $playing -eq 0 ]]; then
            break
        fi
        get_move
    done
}

game
