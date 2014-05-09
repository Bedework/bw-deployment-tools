#! /bin/bash -f


configHome=/opt/bedework/quickstart-3.10/bedework/config/bedework

function error()
{
    echo "$*" >&2
    exit 1
}

function getValue {
   defaultValue=""
   cd $configHome/bwengine
   out=`xmlstarlet sel -N bedework="http://bedework.org/ns/" -t -v  "//bedework:$1" system.xml`
   if [ "$defaultValue" = "" ] ; then
         defaultValue="$out"
   fi
}

function setValue {
   cd $configHome/bwengine
   echo Setting $1 to $2
   xmlstarlet ed -L -N bedework="http://bedework.org/ns/" -u "//bedework:$1" -v "$2" system.xml 
}

cacheURL=""
deploy="do"
while [ "$1" ]; do
    case "$1" in
       -cacheurl)
            shift
            if [[ ! "$1" ]]; then error "Missing value"; fi
            setValue cacheUrlPrefix $1 
            shift
            cacheURL="done"
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


if [ "$cacheURL" = "" ] ; then
  getValue cacheUrlPrefix 
  echo -n "cacheUrlPrefix: ($defaultValue) "
  read ans
  setValue cacheUrlPrefix $ans
  shift
fi

if [ "$deploy" = "do" ] ; then
  echo "Pushing changes."
  cd /opt/bedework/quickstart-3.10
  ./bw -quickstart deployConf
fi
