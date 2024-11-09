REG_DIR=$(dirname $0)
ROOT=$(realpath "$(dirname $0)/../..")
REGTOOL=$ROOT/hw/vendor/pulp-platform-register-interface/vendor/lowrisc_opentitan/util/regtool.py
HJSON_FILE=$REG_DIR/data/control_reg.hjson
RTL_DIR=$REG_DIR/rtl
SW_DIR=$ROOT/sw

mkdir -p $RTL_DIR $SW_DIR
printf -- "Generating control registers RTL...\n"
$REGTOOL -r -t $RTL_DIR $HJSON_FILE
printf -- "Generating software header...\n"
$REGTOOL --cdefines -o $SW_DIR/cnt_control_reg.h $HJSON_FILE
echo "" >> $SW_DIR/cnt_control_reg.h
