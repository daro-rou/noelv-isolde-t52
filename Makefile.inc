# FPGA and Dev Board used in Design
TECHNOLOGY=ZynqUltraScale
ifeq ($(XILINX_BOARD),zcu102)
    PART=xczu9eg
    PACKAGE=ffvb1156
    SPEED=2-e
    PROTOBOARD=xilinx.com:zcu102:part0:3.4
else ifeq ($(XILINX_BOARD),zcu106)
    PART=xczu7ev
    PACKAGE=ffvc1156
    SPEED=2-e
    PROTOBOARD=xilinx.com:zcu106:part0:2.6
else
    $(error $(XILINX_BOARD): unsupported/unspecified board.)
endif

#PROMGENPAR=-u 0 $(TOP).bit -p mcs -data_width 16 -w -o $(BOARD)

# Set Vivado Synthesis Flow Name
#VIVADO_SYNTH_FLOW="Vivado Synthesis 2021"
#VIVADO_SYNTH_FLOW="Vivado Synthesis 2018"

#  Set Vivado Synthesis Synthesis strategy
#VIVADO_SYNTH_STRATEGY="Vivado Synthesis Defaults"

# Set Vivado Implementation strategy
#VIVADO_IMPL_STRATEGY="Vivado Implementation Defaults"
