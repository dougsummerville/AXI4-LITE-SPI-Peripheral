# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ACTIVE_LOW_SS" -parent ${Page_0}
  set GPIO_WIDTH [ipgui::add_param $IPINST -name "GPIO_WIDTH" -parent ${Page_0}]
  set_property tooltip {Numner of bits of GP Output Desired} ${GPIO_WIDTH}
  ipgui::add_param $IPINST -name "USE_GPIO" -parent ${Page_0}


}

proc update_PARAM_VALUE.ACTIVE_LOW_SS { PARAM_VALUE.ACTIVE_LOW_SS } {
	# Procedure called to update ACTIVE_LOW_SS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ACTIVE_LOW_SS { PARAM_VALUE.ACTIVE_LOW_SS } {
	# Procedure called to validate ACTIVE_LOW_SS
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S00_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S00_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to update C_S00_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S00_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.GPIO_WIDTH { PARAM_VALUE.GPIO_WIDTH } {
	# Procedure called to update GPIO_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GPIO_WIDTH { PARAM_VALUE.GPIO_WIDTH } {
	# Procedure called to validate GPIO_WIDTH
	return true
}

proc update_PARAM_VALUE.USE_GPIO { PARAM_VALUE.USE_GPIO } {
	# Procedure called to update USE_GPIO when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.USE_GPIO { PARAM_VALUE.USE_GPIO } {
	# Procedure called to validate USE_GPIO
	return true
}


proc update_MODELPARAM_VALUE.ACTIVE_LOW_SS { MODELPARAM_VALUE.ACTIVE_LOW_SS PARAM_VALUE.ACTIVE_LOW_SS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ACTIVE_LOW_SS}] ${MODELPARAM_VALUE.ACTIVE_LOW_SS}
}

proc update_MODELPARAM_VALUE.GPIO_WIDTH { MODELPARAM_VALUE.GPIO_WIDTH PARAM_VALUE.GPIO_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GPIO_WIDTH}] ${MODELPARAM_VALUE.GPIO_WIDTH}
}

proc update_MODELPARAM_VALUE.USE_GPIO { MODELPARAM_VALUE.USE_GPIO PARAM_VALUE.USE_GPIO } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.USE_GPIO}] ${MODELPARAM_VALUE.USE_GPIO}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH}
}

