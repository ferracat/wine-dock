# Bash ANSI color helpers (source from bash scripts only).
# shellcheck shell=bash

_color() { printf '\033[%sm' "$1"; }

# --- Reset ---
NC=$(_color "0")

# --- Regular ---
BLACK=$(_color "0;30")
RED=$(_color "0;31")
GREEN=$(_color "0;32")
YELLOW=$(_color "0;33")
BLUE=$(_color "0;34")
PURPLE=$(_color "0;35")
ORANGE=$(_color "38;5;202")
CYAN=$(_color "0;36")
WHITE=$(_color "0;37")

# --- Bold ---
BBlack=$(_color "1;30")
BRed=$(_color "1;31")
BGreen=$(_color "1;32")
BYellow=$(_color "1;33")
BBlue=$(_color "1;34")
BPurple=$(_color "1;35")
BCyan=$(_color "1;36")
BWhite=$(_color "1;37")

# --- Underline ---
UBlack=$(_color "4;30")
URed=$(_color "4;31")
UGreen=$(_color "4;32")
UYellow=$(_color "4;33")
UBlue=$(_color "4;34")
UPurple=$(_color "4;35")
UCyan=$(_color "4;36")
UWhite=$(_color "4;37")

# --- Background ---
On_Black=$(_color "40")
On_Red=$(_color "41")
On_Green=$(_color "42")
On_Yellow=$(_color "43")
On_Blue=$(_color "44")
On_Purple=$(_color "45")
On_Cyan=$(_color "46")
On_White=$(_color "47")
On_Pink=$(_color "95")

# --- High intensity ---
IBlack=$(_color "0;90")
IRed=$(_color "0;91")
IGreen=$(_color "0;92")
IYellow=$(_color "0;93")
IBlue=$(_color "0;94")
IPurple=$(_color "0;95")
ICyan=$(_color "0;96")
IWhite=$(_color "0;97")

# --- Bold high intensity ---
BIBlack=$(_color "1;90")
BIRed=$(_color "1;91")
BIGreen=$(_color "1;92")
BIYellow=$(_color "1;93")
BIBlue=$(_color "1;94")
BIPurple=$(_color "1;95")
BICyan=$(_color "1;96")
BIWhite=$(_color "1;97")

# --- High intensity background ---
On_IBlack=$(_color "0;100")
On_IRed=$(_color "0;101")
On_IGreen=$(_color "0;102")
On_IYellow=$(_color "0;103")
On_IBlue=$(_color "0;104")
On_IPurple=$(_color "0;105")
On_ICyan=$(_color "0;106")
On_IWhite=$(_color "0;107")

showColors() {
    echo -e " --- Regular colors ---"
    echo -e "${BLACK}BLACK${NC}"
    echo -e "${RED}RED${NC}"
    echo -e "${GREEN}GREEN${NC}"
    echo -e "${YELLOW}YELLOW${NC}"
    echo -e "${BLUE}BLUE${NC}"
    echo -e "${PURPLE}PURPLE${NC}"
    echo -e "${ORANGE}ORANGE${NC}"
    echo -e "${CYAN}CYAN${NC}"
    echo -e "${WHITE}WHITE${NC}"
}
