#! /bin/bash -f


configHome=/opt/bedework/quickstart-3.10/bedework/config/bedework

function error()
{
    echo "$*" >&2
    exit 1
}

function askYN {
        echo -n "$1"
        read ans
        case "$ans" in
           y|yes|Y|Yes)
              return 1 
              ;;
           n|no|N|No)
              return 0 
              ;;
           *)
              error "Please supply one of: y, yes, n, no"
              ;; 
        esac
}

function setValues {
   cd $configHome/client-configs 
   for x in CalAdmin.xml EventSubmit.xml Events.xml Feeder.xml SoEDept.xml UserCal.xml ; do
      echo In $x, setting $1 to $2
      xmlstarlet ed -L -N bedework="http://bedework.org/ns/" -u "//bedework:$1" -v "$2" $x 
   done
}
function getValues {
   defaultValues=""
   cd $configHome/client-configs
   for x in CalAdmin.xml EventSubmit.xml Events.xml Feeder.xml SoEDept.xml UserCal.xml ; do
       out=`xmlstarlet sel -N bedework="http://bedework.org/ns/" -t -v  "//bedework:$1" $x`
       out="/`basename $out`"
       if [ "$defaultValues" = "" ] ; then
         defaultValues="$out"  
       else
         defaultValues="$defaultValues $out"
       fi
   done
}
function addPrefixesToValue {
   cd $configHome/client-configs 
   for x in CalAdmin.xml EventSubmit.xml Events.xml Feeder.xml SoEDept.xml UserCal.xml ; do
     oldValue=`xmlstarlet sel -N bedework="http://bedework.org/ns/" -t -v  "//bedework:$1" $x`
     oldValue="/`basename $oldValue`"
     newValue="${2}$oldValue"
     echo In $x, setting $1 to $newValue
     xmlstarlet ed -L -N bedework="http://bedework.org/ns/" -u "//bedework:$1" -v "$newValue" $x
   done
}

argProvided="false"
deploy="do"
while [[ "$1" ]]
    do
        case "$1" in

        -ampm)
            shift
            if [[ ! "$1" ]]; then error "Missing value"; fi
            t=$(tr '[:upper:]' '[:lower:]' <<<$1)

            case "$t" in
              y|yes|Y|Yes)
                setValues hour24 false
                ;;
              n|no|N|No)
		setValues hour24 true 
                ;;
              *)
                error "Please supply one of: y, yes, n, no"
                ;;
            esac
            shift 
            argProvided="true"
            ;;

       -brootprefix)
            shift
            if [[ ! "$1" ]]; then error "Missing value"; fi
            addPrefixesToValue browserResourceRoot $1 
            shift
            argProvided="true"
            ;;
       -arootprefix)
            shift
            if [[ ! "$1" ]]; then error "Missing value"; fi
            addPrefixesToValue appRoot $1    
            shift
            argProvided="true"
            ;;
        -dontdeploy)
           shift
           deploy="dont"
           ;;
        -*)
            error "Unrecognized option: $1"
            ;;

        *)
            break
            ;;
        esac
done


if [ "$argProvided" = "false" ] ; then
  askYN "AM/PM time (instead of 24-hour time)? "
  if [ $? = 1 ] ; then
    setValues hour24 false 
  else
    setValues hour24 true
  fi 

  getValues browserResourceRoot 
  echo -n "BrowserResourceRoot URL prefix: ($defaultValues) "
  read ans
  addPrefixesToValue browserResourceRoot $ans 
  shift

  getValues browserResourceRoot
  echo -n "AppRoot URL prefix: ($defaultValues) "
  read ans
  addPrefixesToValue appRoot $ans
  shift
fi

if [ $deploy = "do" ] ; then
  echo "Pushing changes."
  cd /opt/bedework/quickstart-3.10
  ./bw -quickstart deployConf
fi
