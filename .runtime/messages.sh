####################################################################################################
# FUNCTION: debug_msg()
# DESCRIPTION: This function is used to print debug messages
# PARAMETERS:
#    $1 - $msg = message to print
#    $2 - $ln  = line number
#    $3 - $filename = file where the print is called from
####################################################################################################
debug_msg()
{
    if [[ -z "${BASH_DEBUG:-}" ]] || [[ ${BASH_DEBUG:-0} -eq 0 ]]; then
        return 0
    fi
    local msg=$1
    local ln=$2
    local filename=$3
    [ -n "$ln" ] && ln=":$ln"
    [ -n "$filename" ] && filename=":$filename"
    echo -e "${BLUE}[DEBUG$filename$ln]${NC} $msg${NC}"
}

####################################################################################################
# FUNCTION: info_msg()
# DESCRIPTION: This function is used to print info messages
# PARAMETERS:
#    $1 - $msg = message to print
#    $2 - $ln  = line number
#    $3 - $filename = file where the print is called from
####################################################################################################
info_msg()
{
    local msg=$1
    local ln=$2
    local filename=$3
    [ -n "$ln" ] && ln=":$ln"
    [ -n "$filename" ] && filename=":$filename"
    [ -n "${BASH_DEBUG:-}" ] \
        && echo -e "${GREEN}[INFO$filename$ln]${NC} $msg${NC}" \
        || echo -e "${GREEN}INFO:${NC} $msg${NC}"
}

####################################################################################################
# FUNCTION: warn_msg()
# DESCRIPTION: This function is used to print warning messages
# PARAMETERS:
#    $1 - $msg = message to print
#    $2 - $ln  = line number
#    $3 - $filename = file where the print is called from
####################################################################################################
warn_msg()
{
    local msg=$1
    local ln=$2
    local filename=$3
    [ -n "$ln" ] && ln=":$ln"
    [ -n "$filename" ] && filename=":$filename"
    [ -n "${BASH_DEBUG:-}" ] \
        && echo -e "${YELLOW}[WARN$filename$ln]${NC} $msg${NC}" \
        || echo -e "${YELLOW}WARNING:${NC} $msg${NC}"
}

####################################################################################################
# FUNCTION: err_msg()
# DESCRIPTION: This function is used to print error messages
# PARAMETERS:
#    $1 - $msg = message to print
#    $2 - $ln  = line number
#    $3 - $filename = file where the print is called from
####################################################################################################
err_msg()
{
    local msg=$1
    local ln=$2
    local filename=$3
    [ -n "$ln" ] && ln=":$ln"
    [ -n "$filename" ] && filename=":$filename"
    [ -n "${BASH_DEBUG:-}" ] \
        && echo -e "${RED}[ERROR$filename$ln]${NC} $msg${NC}" \
        || echo -e "${RED}ERROR:${NC} $msg${NC}"
}

####################################################################################################
# FUNCTION: title_msg()
# DESCRIPTION: This function is used to print title messages in $IPurple color
# PARAMETERS:
#    $1 - $msg = message to print
#    $2 - $ln  = line number
#    $3 - $filename = file where the print is called from
####################################################################################################
title_msg()
{
    local msg=$1
    local ln=${2:-}
    local filename=${3:-}
    [ -n "$ln" ] && ln=":$ln";
    [ -n "$filename" ] && filename=":$filename";
    [ -n "${BASH_DEBUG:-}" ] \
        && echo -e "${IPurple}[TITLE$filename$ln]${NC} $msg${NC}" \
        || echo -e "${IPurple}--- $msg${NC}"
}

####################################################################################################
# FUNCTION: ok_msg()
# DESCRIPTION: This function is used to print "[  OK ]" messages
# PARAMETERS:
#    $1 - $msg = message to print
#    $2 - $ln  = line number
#    $3 - $filename = file where the print is called from
####################################################################################################
ok_msg()
{
    local msg=$1
    local ln=$2
    local filename=$3
    [ -n "$ln" ] && ln=":$ln"
    [ -n "$filename" ] && filename=":$filename"
    [ -n "${BASH_DEBUG:-}" ] && echo -en "${BIBlack}$filename$ln:${NC} "
    echo -e "${BWhite}$msg${NC} [  ${GREEN}OK${NC} ]"
}

####################################################################################################
# FUNCTION: nok_msg()
# DESCRIPTION: This function is used to print "[ NOK ]" messages
# PARAMETERS:
#    $1 - $msg = message to print
#    $2 - $ln  = line number
#    $3 - $filename = file where the print is called from
####################################################################################################
nok_msg()
{
    local msg=$1
    local ln=$2
    local filename=$3
    [ -n "$ln" ] && ln=":$ln"
    [ -n "$filename" ] && filename=":$filename"
    [ -n "${BASH_DEBUG:-}" ] && echo -en "${BIBlack}$filename$ln:${NC} "
    echo -e "${BWhite}$msg${NC} [ ${RED}NOK${NC} ]"
}


[ -n "$BASH_VERSION" ] && export -f debug_msg info_msg warn_msg err_msg title_msg ok_msg nok_msg
