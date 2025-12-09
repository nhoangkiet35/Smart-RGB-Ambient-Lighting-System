# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "IDLE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SENT_REQ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "WAIT_DONE" -parent ${Page_0}


}

proc update_PARAM_VALUE.IDLE { PARAM_VALUE.IDLE } {
	# Procedure called to update IDLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IDLE { PARAM_VALUE.IDLE } {
	# Procedure called to validate IDLE
	return true
}

proc update_PARAM_VALUE.SENT_REQ { PARAM_VALUE.SENT_REQ } {
	# Procedure called to update SENT_REQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SENT_REQ { PARAM_VALUE.SENT_REQ } {
	# Procedure called to validate SENT_REQ
	return true
}

proc update_PARAM_VALUE.WAIT_DONE { PARAM_VALUE.WAIT_DONE } {
	# Procedure called to update WAIT_DONE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.WAIT_DONE { PARAM_VALUE.WAIT_DONE } {
	# Procedure called to validate WAIT_DONE
	return true
}


proc update_MODELPARAM_VALUE.IDLE { MODELPARAM_VALUE.IDLE PARAM_VALUE.IDLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IDLE}] ${MODELPARAM_VALUE.IDLE}
}

proc update_MODELPARAM_VALUE.SENT_REQ { MODELPARAM_VALUE.SENT_REQ PARAM_VALUE.SENT_REQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SENT_REQ}] ${MODELPARAM_VALUE.SENT_REQ}
}

proc update_MODELPARAM_VALUE.WAIT_DONE { MODELPARAM_VALUE.WAIT_DONE PARAM_VALUE.WAIT_DONE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.WAIT_DONE}] ${MODELPARAM_VALUE.WAIT_DONE}
}

